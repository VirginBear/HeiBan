param([ValidateSet('win-x64','win-arm64')][string]$Runtime='win-x64',[switch]$Smoke)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Publish-Common.ps1')
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$version=Get-HeiBanVersion
$zip=Join-Path $root "dist\HeiBan-Windows-Portable-$version-$Runtime.zip"
$qa=Join-Path $root ('.build\artifact-check-'+$Runtime+'-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $qa | Out-Null
Expand-Archive -LiteralPath $zip -DestinationPath $qa
function Assert([bool]$condition,[string]$label){if(-not $condition){throw $label}}
function Get-Machine([string]$file) {
    $reader=[IO.BinaryReader]::new([IO.File]::OpenRead($file))
    try {
        Assert ($reader.ReadUInt16() -eq 0x5a4d) 'Missing MZ header'
        $reader.BaseStream.Position=0x3c;$offset=$reader.ReadInt32();$reader.BaseStream.Position=$offset
        Assert ($reader.ReadUInt32() -eq 0x4550) 'Missing PE header'
        return $reader.ReadUInt16()
    } finally{$reader.Dispose()}
}
$inventory=Get-Content -LiteralPath (Join-Path $qa 'update-files.json') -Raw -Encoding utf8 | ConvertFrom-Json
Assert ($inventory.Version -eq $version) 'Inventory version mismatch'
$count=0
foreach($file in $inventory.Files.PSObject.Properties) {
    Assert ($file.Name -notmatch '^Data/' -and $file.Name -ne 'portable.dat') 'Data included in inventory'
    Assert ((Get-FileHash -LiteralPath (Join-Path $qa $file.Name) -Algorithm SHA256).Hash -eq $file.Value) ('Payload hash mismatch: '+$file.Name)
    $count++
}
Assert (-not (Get-ChildItem -LiteralPath (Join-Path $qa 'Data') -Recurse -File)) 'Portable ZIP contains user data'
$machine=if($Runtime -eq 'win-arm64'){0xaa64}else{0x8664}
Assert ((Get-Machine (Join-Path $qa 'HeiBan.exe')) -eq $machine) 'App architecture mismatch'
Assert ((Get-Machine (Join-Path $qa 'Updater\HeiBan.Updater.exe')) -eq $machine) 'Helper architecture mismatch'
Assert (([Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $qa 'HeiBan.exe'))).ProductVersion.Split('+')[0] -eq $version) 'App version mismatch'
Assert ((Get-FileHash -LiteralPath (Join-Path $qa 'Assets\HeiBanUserGuide.html')).Hash -eq (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot '..\Assets\HeiBanUserGuide.html')).Hash) 'Guide out of date'
Assert ((Get-FileHash -LiteralPath (Join-Path $qa 'README-Windows.md')).Hash -eq (Get-FileHash -LiteralPath (Join-Path $root 'README.md')).Hash) 'README out of date'
$zipHash=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
Assert ((Get-Content -LiteralPath ($zip+'.sha256') -Raw).StartsWith($zipHash)) 'ZIP sidecar mismatch'
$started=$false;$closed=$false
if($Smoke) {
    Assert ($Runtime -eq 'win-x64') 'This host only performs x64 runtime smoke'
    $start=[Diagnostics.ProcessStartInfo]::new((Join-Path $qa 'HeiBan.exe'))
    $start.UseShellExecute=$false;$start.WindowStyle='Hidden'
    $start.Environment['HEIBAN_WINDOWS_DATA_DIRECTORY']=Join-Path $qa 'Isolated-Smoke-Data'
    $process=[Diagnostics.Process]::Start($start)
    try {
        for($i=0;$i -lt 100;$i++) {
            Start-Sleep -Milliseconds 100;$process.Refresh()
            Assert (-not $process.HasExited) 'App exited before main window appeared'
            if($process.MainWindowTitle -eq 'HeiBan 黑板 · Windows'){$started=$true;break}
            if($process.MainWindowTitle -match '無法啟動'){throw 'App displayed startup failure'}
        }
        Assert $started 'Main window did not appear'
        Start-Sleep -Milliseconds 1000
        Assert ($process.CloseMainWindow()) 'Could not request normal close'
        $closed=$process.WaitForExit(15000)
        Assert $closed 'App did not finish normal close'
        Assert ($process.ExitCode -eq 0) 'App failed on close'
    } finally {
        if(-not $process.HasExited){Assert ($process.MainModule.FileName -eq (Join-Path $qa 'HeiBan.exe')) 'Unexpected smoke process';$process.Kill();$process.WaitForExit()}
        $process.Dispose()
    }
}
$result=@{Success=$true;Runtime=$Runtime;Version=$version;FilesVerified=$count;Sha256=$zipHash;Bytes=(Get-Item -LiteralPath $zip).Length;SmokeRequested=[bool]$Smoke;MainWindowStarted=$started;NormalClose=$closed;Fixture=$qa}
$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $qa 'artifact-result.json') -Encoding utf8
$result | ConvertTo-Json
