[CmdletBinding()]
param([Parameter(Mandatory)][ValidatePattern('^HeiBan-Windows-Portable-[A-Za-z0-9._-]+$')][string]$KeepTrial)
$ErrorActionPreference='Stop'
$windowsRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$trialRoot=(Resolve-Path -LiteralPath (Join-Path $windowsRoot 'dist\trials')).Path
$keepPath=Join-Path $trialRoot $KeepTrial
foreach($base in @($windowsRoot,(Join-Path $windowsRoot 'dist'),$trialRoot,(Join-Path $windowsRoot 'dist\trial-data-backups'))) {
    if((Test-Path -LiteralPath $base) -and ((Get-Item -LiteralPath $base -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw '清理／備份根目錄是reparse point；停止。'}
}
if(-not (Test-Path -LiteralPath (Join-Path $keepPath 'HeiBan.exe')) -or -not (Test-Path -LiteralPath ($keepPath+'.zip'))) {throw '保留的新試用包不完整；停止清理。'}
function Assert-Within([string]$Path,[string]$Root) {
    $full=[IO.Path]::GetFullPath($Path)
    if(-not $full.StartsWith($Root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw '清理／備份路徑超出指定目錄。'}
    return $full
}
function Hash([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
Assert-Within $keepPath $trialRoot | Out-Null
# A failed release lookup must stop deletion. Published assets are an explicit retention boundary.
$published=@(& gh api --paginate repos/VirginBear/HeiBan/releases --jq '.[].assets[].name')
if($LASTEXITCODE -ne 0){throw '無法核對已發布資產；停止清理。'}
$id=[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
$backupRoot=[IO.Path]::GetFullPath((Join-Path $windowsRoot ('dist\trial-data-backups\'+$id)))
$recordRoot=Join-Path $windowsRoot ('.build\trial-cleanup-'+$id)
Assert-Within $backupRoot (Join-Path $windowsRoot 'dist\trial-data-backups') | Out-Null
New-Item -ItemType Directory -Path $recordRoot | Out-Null
$storePath=Join-Path $windowsRoot 'dist\store\HeiBan-Store-1.0.12.0-x64-arm64.msixbundle'
$storeBefore=if(Test-Path -LiteralPath $storePath){Hash $storePath}else{$null}
$report=[ordered]@{status='in progress';keepTrial=$KeepTrial;backupRelativePath='dist/trial-data-backups/'+$id;publishedAssetNames=$published;entries=@();removedBytes=0L;preservedBytes=0L;scope='Only obsolete unpublished trials; never Git history, release assets, Store or unrelated dist'}
try {
    foreach($folder in @(Get-ChildItem -LiteralPath $trialRoot -Directory -Force)) {
        if($folder.Name -eq $KeepTrial -or $folder.Name -notmatch '^HeiBan-Windows-Portable-[A-Za-z0-9._-]+$'){continue}
        $source=(Resolve-Path -LiteralPath $folder.FullName).Path
        Assert-Within $source $trialRoot | Out-Null
        if($published -contains ($folder.Name+'.zip')){continue}
        $entries=@(Get-ChildItem -LiteralPath $source -Recurse -Force)
        if(($folder.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or @($entries|Where-Object {($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0}).Count -gt 0){throw '試用資料含reparse point；停止遞迴清理。'}
        $files=@($entries|Where-Object {-not $_.PSIsContainer})
        if(@($files|Where-Object {$_.Extension -in @('.msix','.msixbundle','.msixupload','.appx','.appxbundle','.appxupload')}).Count -gt 0){continue}
        if(@(Get-CimInstance Win32_Process -Filter "Name = 'HeiBan.exe'"|Where-Object {$_.ExecutablePath -and $_.ExecutablePath.StartsWith($source+'\',[StringComparison]::OrdinalIgnoreCase)}).Count -gt 0){throw '舊試用仍在使用，請正常保存關閉後再清理。'}
        $inventoryPath=Join-Path $source 'update-files.json'
        if(-not (Test-Path -LiteralPath $inventoryPath)){throw '試用缺少inventory，無法區分程式與自有檔；停止清理。'}
        $inventory=(Get-Content -LiteralPath $inventoryPath -Raw|ConvertFrom-Json).Files
        $known=@{};foreach($property in $inventory.PSObject.Properties){$known[$property.Name]=$property.Value}
        $protected=@();$payloadBytes=0L;$dataCount=0;$changedCount=0;$unknownCount=0
        foreach($file in $files) {
            $path=Assert-Within $file.FullName $source;$relative=$path.Substring($source.Length+1).Replace('\','/');$payloadBytes+=$file.Length
            $digest=Hash $path;$preserve=$false
            if($relative.StartsWith('Data/')){$preserve=$true;$dataCount++}
            elseif($relative -notin @('portable.dat','update-files.json')) {
                if(-not $known.ContainsKey($relative)){$preserve=$true;$unknownCount++}
                elseif($digest -ne $known[$relative]){$preserve=$true;$changedCount++}
            }
            if($preserve){$protected+=@{path=$path;relative=$relative;sha256=$digest;bytes=$file.Length}}
        }
        $backup=Assert-Within (Join-Path $backupRoot $folder.Name) $backupRoot
        $savedBytes=0L
        # Preserve Data and every unrecognized/modified file before deleting reproducible runtime.
        # Never log board filenames or content in the public report.
        foreach($file in $protected) {
            $destination=Assert-Within (Join-Path $backup $file.relative) $backup
            New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($destination)) -Force | Out-Null
            Move-Item -LiteralPath $file.path -Destination $destination
            if((Hash $destination) -ne $file.sha256){throw '保留資料雜湊不符；停止刪除程式。'}
            $savedBytes+=$file.bytes
        }
        $row=[ordered]@{trial=$folder.Name;payloadBytes=$payloadBytes;payloadFiles=$files.Count;preservedFiles=$protected.Count;preservedDataFiles=$dataCount;preservedModifiedFiles=$changedCount;preservedUnknownFiles=$unknownCount;preservedBytes=$savedBytes;backupVerified=$true;zipBytes=0L;zipSha256=$null;sidecarBytes=0L;deleted=$false}
        $report.entries+=,$row
        $zip=Assert-Within ($source+'.zip') $trialRoot
        if(Test-Path -LiteralPath $zip){$row.zipBytes=(Get-Item -LiteralPath $zip).Length;$row.zipSha256=Hash $zip}
        $sidecar=Assert-Within ($zip+'.sha256') $trialRoot
        if(Test-Path -LiteralPath $sidecar){$row.sidecarBytes=(Get-Item -LiteralPath $sidecar).Length}
        # Recheck live files after backup; a new board must not be caught by recursive runtime deletion.
        $remaining=@(Get-ChildItem -LiteralPath $source -Recurse -File -Force)
        if($remaining.Count -ne $files.Count-$protected.Count -or @($remaining|Where-Object {$_.FullName.StartsWith((Join-Path $source 'Data')+'\',[StringComparison]::OrdinalIgnoreCase)}).Count -gt 0){throw '備份後試用內容改變；停止刪除。'}
        if(@(Get-CimInstance Win32_Process -Filter "Name = 'HeiBan.exe'"|Where-Object {$_.ExecutablePath -and $_.ExecutablePath.StartsWith($source+'\',[StringComparison]::OrdinalIgnoreCase)}).Count -gt 0){throw '舊試用開始使用；停止刪除。'}
        Assert-Within (Resolve-Path -LiteralPath $source).Path $trialRoot | Out-Null
        Remove-Item -LiteralPath $source -Recurse -Force
        if(Test-Path -LiteralPath $zip){Remove-Item -LiteralPath $zip -Force}
        if(Test-Path -LiteralPath $sidecar){Remove-Item -LiteralPath $sidecar -Force}
        $row.deleted=$true;$report.removedBytes+=$payloadBytes-$savedBytes+$row.zipBytes+$row.sidecarBytes;$report.preservedBytes+=$savedBytes
    }
    $report.status='completed'
}
catch {$report.status='stopped; inspect preserved data and remaining trials before retry';throw}
finally {
    $storeAfter=if(Test-Path -LiteralPath $storePath){Hash $storePath}else{$null}
    $report.storeBefore=$storeBefore;$report.storeAfter=$storeAfter;$report.storeUnchanged=($storeBefore -eq $storeAfter)
    $report|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $recordRoot 'cleanup.json') -Encoding utf8
    Write-Output ('清理紀錄：'+(Join-Path $recordRoot 'cleanup.json'))
    if($storeBefore -ne $storeAfter){throw 'Store套件變動；停止交付。'}
}
Write-Output ('已釋放bytes：'+$report.removedBytes+'；保留資料bytes：'+$report.preservedBytes)
