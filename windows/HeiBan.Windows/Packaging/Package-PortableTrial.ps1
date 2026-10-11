[CmdletBinding()]
param(
    [ValidateSet('win-x64','win-arm64')][string]$Runtime='win-x64',
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')][string]$Label='perf2-2026-10-11'
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Publish-Common.ps1')
$windowsRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$version=Get-HeiBanVersion
$name="HeiBan-Windows-Portable-$version-$Label-$Runtime"
$trialRoot=Join-Path $windowsRoot 'dist\trials'
$payload=Join-Path $trialRoot $name
$zip=$payload+'.zip'
# A local trial must never replace a previously delivered package or any user's Data directory.
foreach($target in @($payload,$zip,($zip+'.sha256'))) {
    if(Test-Path -LiteralPath $target){throw "試用產物已存在，請選新Label；保留原檔：$target"}
}
$recordRoot=Join-Path $windowsRoot ('.build\portable-trial-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $recordRoot | Out-Null
$source=(& git -C $windowsRoot rev-parse HEAD).Trim()
if($LASTEXITCODE -ne 0){throw '無法記錄來源commit。'}
$sourcePaths=@(& git -C $windowsRoot ls-files --cached --others --exclude-standard -- '*.cs' '*.csproj' '*.ps1' '*.xaml' '*.html' '*.manifest' 'README.md')
if($LASTEXITCODE -ne 0){throw '無法記錄來源檔案。'}
$sourceFiles=@($sourcePaths | Sort-Object -Unique | ForEach-Object {
    @{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $windowsRoot $_) -Algorithm SHA256).Hash.ToLowerInvariant()}
})
$storeBundle=Join-Path $windowsRoot 'dist\store\HeiBan-Store-1.0.12.0-x64-arm64.msixbundle'
$storeBefore=if(Test-Path -LiteralPath $storeBundle){(Get-FileHash -LiteralPath $storeBundle -Algorithm SHA256).Hash}else{$null}
New-Item -ItemType Directory -Path $payload | Out-Null
try {
    Publish-HeiBan 'Release' $Runtime $payload (Join-Path $recordRoot 'artifacts') *> (Join-Path $recordRoot 'publish.log')
    New-Item -ItemType File -Path (Join-Path $payload 'portable.dat') | Out-Null
    foreach($folder in @('Boards','Metadata','Thumbnails','Trash','Settings')) {
        New-Item -ItemType Directory -Path (Join-Path $payload "Data\$folder") | Out-Null
    }
    Copy-Item -LiteralPath (Join-Path $windowsRoot 'README.md') -Destination (Join-Path $payload 'README-Windows.md')
    @"
# HeiBan 黑板：本機免安裝試用版

試用標記：$Label / $Runtime。程式版本：$version。
完整解壓到可寫入的資料夾，雙擊 HeiBan.exe 即可使用，不需安裝。
作品保存在本資料夾的 Data；目前是空白試用資料庫，請保留整個資料夾。
這份包包含封裝當時的Windows開發原始碼；批次標籤為 $Label，操作變更請參閱Windows開發紀錄。原有README的dist列表可能包含之前交付包。
本機試用包尚未發布至GitHub Release或Microsoft Store。
來源commit：$source，加封裝時的Windows工作樹；實際byte來源記在TRIAL-SOURCE.json。
關閉程式後才搬動資料夾；不要覆蓋舊版的Data或直接從ZIP內啟動。
"@ | Set-Content -LiteralPath (Join-Path $payload 'README-Trial.zh-TW.md') -Encoding UTF8
    [ordered]@{label=$Label;runtime=$Runtime;version=$version;sourceCommit=$source;sourceFiles=$sourceFiles;
        capturedUtc=[DateTime]::UtcNow.ToString('o');scope='Local Portable trial, source commit plus recorded Windows working tree; no release publication'} |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $payload 'TRIAL-SOURCE.json') -Encoding UTF8
    Write-HeiBanUpdateInventory $payload
    # The empty portable Data tree and runtime payload travel together; no user's files are copied.
    Compress-Archive -Path (Join-Path $payload '*') -DestinationPath $zip -CompressionLevel Optimal
    $sha=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    "$sha  $([IO.Path]::GetFileName($zip))" | Set-Content -LiteralPath ($zip+'.sha256') -Encoding ascii
    [ordered]@{success=$true;label=$Label;runtime=$Runtime;version=$version;sourceCommit=$source;
        zipRelativePath='dist/trials/'+[IO.Path]::GetFileName($zip);sha256=$sha;bytes=(Get-Item -LiteralPath $zip).Length;
        sourceFiles=$sourceFiles;scope='Packaging completed; no new runtime tests or public release'} |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $recordRoot 'artifact.json') -Encoding UTF8
    Write-Output "免安裝ZIP：$zip"
    Write-Output "直接啟動：$(Join-Path $payload 'HeiBan.exe')"
    Write-Output "封裝紀錄：$recordRoot"
}
finally {
    $storeAfter=if(Test-Path -LiteralPath $storeBundle){(Get-FileHash -LiteralPath $storeBundle -Algorithm SHA256).Hash}else{$null}
    @{before=$storeBefore;after=$storeAfter;unchanged=($storeBefore -eq $storeAfter)} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $recordRoot 'store-preservation.json') -Encoding UTF8
    if($storeBefore -ne $storeAfter){throw 'Store bundle變動，停止交付。'}
    # Keep the output and build evidence even after failure; a new label is needed for a retry.
}
