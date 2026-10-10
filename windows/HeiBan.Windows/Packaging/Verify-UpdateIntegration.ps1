param([Parameter(Mandatory=$true)][string]$DotnetPath,[Parameter(Mandatory=$true)][string]$IsccPath)
$ErrorActionPreference='Stop'
$windowsRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$qaRoot=Join-Path $windowsRoot ('.build\update-integration-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $qaRoot | Out-Null
$DotnetPath=[IO.Path]::GetFullPath($DotnetPath)
$IsccPath=[IO.Path]::GetFullPath($IsccPath)
$helperProject=Join-Path $windowsRoot 'HeiBan.Updater\HeiBan.Updater.csproj'
$helperFolder=Join-Path $qaRoot 'helper'
& $DotnetPath publish $helperProject -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o $helperFolder
if($LASTEXITCODE -ne 0){throw 'Helper fixture publish failed'}
$source=Join-Path $qaRoot 'source'
New-Item -ItemType Directory -Path $source | Out-Null
@'
<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>WinExe</OutputType><TargetFramework>net10.0</TargetFramework><AssemblyName>HeiBan</AssemblyName><ImplicitUsings>enable</ImplicitUsings></PropertyGroup></Project>
'@ | Set-Content -LiteralPath (Join-Path $source 'Fixture.csproj') -Encoding utf8
'await Task.Delay(Timeout.Infinite);' | Set-Content -LiteralPath (Join-Path $source 'Program.cs') -Encoding utf8
function Write-Inventory([string]$path,[string]$version) {
    $files=[ordered]@{}
    Get-ChildItem -LiteralPath $path -Recurse -File | ForEach-Object {
        $relative=$_.FullName.Substring($path.Length+1).Replace('\','/')
        if($relative -ne 'update-files.json' -and $relative -ne 'portable.dat' -and -not $relative.StartsWith('Data/')){$files[$relative]=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
    }
    @{Version=$version;Files=$files} | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $path 'update-files.json') -Encoding utf8
}
foreach($preview in @(6,7)) {
    $destination=Join-Path $qaRoot "v$preview"
    & $DotnetPath publish (Join-Path $source 'Fixture.csproj') -c Release -r win-x64 --self-contained false "-p:Version=1.0.12-preview.$preview" "-p:FileVersion=1.0.12.$preview" -o $destination
    if($LASTEXITCODE -ne 0){throw 'App fixture publish failed'}
    foreach($file in @('HeiBan.pri','coreclr.dll')){'synthetic fixture' | Set-Content -LiteralPath (Join-Path $destination $file)}
    New-Item -ItemType Directory -Path (Join-Path $destination 'Updater') | Out-Null
    Copy-Item -LiteralPath (Join-Path $helperFolder 'HeiBan.Updater.exe') -Destination (Join-Path $destination 'Updater\HeiBan.Updater.exe')
    Write-Inventory $destination "1.0.12-preview.$preview"
}
function Get-Cache([string]$installation) {
    $sha=[Security.Cryptography.SHA256]::Create()
    try{$bytes=$sha.ComputeHash([Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($installation).TrimEnd('\','/').ToUpperInvariant()))}finally{$sha.Dispose()}
    $key=([BitConverter]::ToString($bytes).Replace('-','')).Substring(0,24)
    return Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) "HeiBan\Updates\$key"
}
function Job([string]$installation,[bool]$portable,[string]$asset,[int]$parentId=2147483647,[long]$ticks=0,[bool]$corrupt=$false,[string]$version='1.0.12-preview.7') {
    $cache=Get-Cache $installation
    New-Item -ItemType Directory -Force -Path $cache | Out-Null
    $name=if($portable){"HeiBan-Windows-Portable-$version-win-x64.zip"}else{"HeiBan-Setup-$version-x64.exe"}
    $localPackage=Join-Path $cache $name
    Copy-Item -LiteralPath $asset -Destination $localPackage
    $hash=(Get-FileHash -LiteralPath $localPackage -Algorithm SHA256).Hash
    $size=(Get-Item -LiteralPath $localPackage).Length
    if($corrupt){[IO.File]::WriteAllBytes($localPackage,[byte[]]@(1,2,3))}
    $package=@{Version=$version;Architecture='x64';Portable=$portable;Name=$name;Url="https://github.com/VirginBear/HeiBan/releases/download/windows-v$version/$name";Size=$size;Sha256=$hash}
    @{Package=$package;InstallDirectory=$installation;CurrentVersion='1.0.12-preview.6';ParentId=$parentId;ParentStartTicks=$ticks} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $cache 'job.json') -Encoding utf8
    $package | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $cache 'pending.json') -Encoding utf8
    $worker=Join-Path $cache 'worker.exe'; Copy-Item -LiteralPath (Join-Path $helperFolder 'HeiBan.Updater.exe') -Destination $worker
    $process=Start-Process -FilePath $worker -ArgumentList ('"'+(Join-Path $cache 'job.json')+'"') -WindowStyle Hidden -PassThru
    return @{Process=$process;Cache=$cache}
}
function Assert([bool]$value,[string]$label){if(-not $value){throw $label}}
function Await-Worker($job,[bool]$success) {
    Assert ($job.Process.WaitForExit(60000)) 'Helper timed out'
    $result=Get-Content -LiteralPath (Join-Path $job.Cache 'result.json') -Raw -Encoding utf8 | ConvertFrom-Json
    Assert ($result.Success -eq $success) ('Unexpected result: '+$result.Message)
    Assert (($job.Process.ExitCode -eq 0) -eq $success) 'Helper exit code differs from result'
}
$v6=Join-Path $qaRoot 'v6';$v7=Join-Path $qaRoot 'v7'
New-Item -ItemType File -Path (Join-Path $v7 'portable.dat') | Out-Null
$zip=Join-Path $qaRoot 'portable.zip';Compress-Archive -Path (Join-Path $v7 '*') -DestinationPath $zip
$portable=Join-Path $qaRoot 'portable';New-Item -ItemType Directory -Path $portable | Out-Null
Copy-Item -Path (Join-Path $v6 '*') -Destination $portable -Recurse
New-Item -ItemType File -Path (Join-Path $portable 'portable.dat') | Out-Null
New-Item -ItemType Directory -Path (Join-Path $portable 'Data') | Out-Null
'synthetic work' | Set-Content -LiteralPath (Join-Path $portable 'Data\work.txt')
'unknown fixture' | Set-Content -LiteralPath (Join-Path $portable 'custom.txt')
$workHash=(Get-FileHash -LiteralPath (Join-Path $portable 'Data\work.txt')).Hash
$start=New-Object Diagnostics.ProcessStartInfo
$start.FileName=Join-Path $portable 'HeiBan.exe';$start.UseShellExecute=$false;$start.CreateNoWindow=$true
$start.Environment['DOTNET_ROOT_X64']=[IO.Path]::GetDirectoryName($DotnetPath)
$parent=[Diagnostics.Process]::Start($start)
try {
    $handoffCache=Get-Cache $portable;New-Item -ItemType Directory -Force -Path $handoffCache | Out-Null
    $handoffLock=[IO.FileStream]::new((Join-Path $handoffCache 'update.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try {
    $waitJob=Job $portable $true $zip $parent.Id $parent.StartTime.ToUniversalTime().Ticks
        Start-Sleep -Milliseconds 500
        Assert (-not $waitJob.Process.HasExited) 'Helper failed instead of waiting for handoff lock'
    } finally{$handoffLock.Dispose()}
    Start-Sleep -Milliseconds 800
    Assert (-not $waitJob.Process.HasExited) 'Helper did not wait for parent'
    Assert (([Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $portable 'HeiBan.exe'))).FileVersion -eq '1.0.12.6') 'Updated before parent exited'
} finally {
    # Terminate only the synthetic process started here, after confirming its exact fixture executable.
    if(-not $parent.HasExited){Assert ($parent.MainModule.FileName -eq (Join-Path $portable 'HeiBan.exe')) 'Unexpected parent process';$parent.Kill();$parent.WaitForExit()}
}
Await-Worker $waitJob $true
Assert (([Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $portable 'HeiBan.exe'))).FileVersion -eq '1.0.12.7') 'Portable version was not updated'
Assert ((Get-FileHash -LiteralPath (Join-Path $portable 'Data\work.txt')).Hash -eq $workHash) 'Portable Data changed'
Assert ((Get-Content -LiteralPath (Join-Path $portable 'custom.txt') -Raw).Trim() -eq 'unknown fixture') 'Unknown file changed'
Assert (-not (Test-Path -LiteralPath (Join-Path $waitJob.Cache 'pending.json'))) 'Successful job remained pending'
$corruptRoot=Join-Path $qaRoot 'corrupt';New-Item -ItemType Directory -Path $corruptRoot | Out-Null
Copy-Item -Path (Join-Path $v6 '*') -Destination $corruptRoot -Recurse
New-Item -ItemType File -Path (Join-Path $corruptRoot 'portable.dat') | Out-Null
$corruptJob=Job $corruptRoot $true $zip -corrupt $true
Await-Worker $corruptJob $false
Assert (([Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $corruptRoot 'HeiBan.exe'))).FileVersion -eq '1.0.12.6') 'Corrupt package modified installation'

$stableSource=Join-Path $qaRoot 'stable-source'
& $DotnetPath publish (Join-Path $source 'Fixture.csproj') -c Release -r win-x64 --self-contained false '-p:Version=1.0.12' '-p:FileVersion=1.0.12.0' -o $stableSource
if($LASTEXITCODE -ne 0){throw 'Stable fixture publish failed'}
foreach($file in @('HeiBan.pri','coreclr.dll')){'synthetic fixture' | Set-Content -LiteralPath (Join-Path $stableSource $file)}
New-Item -ItemType Directory -Path (Join-Path $stableSource 'Updater') | Out-Null
Copy-Item -LiteralPath (Join-Path $helperFolder 'HeiBan.Updater.exe') -Destination (Join-Path $stableSource 'Updater\HeiBan.Updater.exe')
Write-Inventory $stableSource '1.0.12'
New-Item -ItemType File -Path (Join-Path $stableSource 'portable.dat') | Out-Null
$stableZip=Join-Path $qaRoot 'stable.zip';Compress-Archive -Path (Join-Path $stableSource '*') -DestinationPath $stableZip
$stableRoot=Join-Path $qaRoot 'stable-install';New-Item -ItemType Directory -Path $stableRoot | Out-Null
Copy-Item -Path (Join-Path $v6 '*') -Destination $stableRoot -Recurse
New-Item -ItemType File -Path (Join-Path $stableRoot 'portable.dat') | Out-Null
$stableJob=Job $stableRoot $true $stableZip -version '1.0.12'
Await-Worker $stableJob $true
Assert (([Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $stableRoot 'HeiBan.exe'))).ProductVersion.Split('+')[0] -eq '1.0.12') 'Preview to stable was skipped'

$otherRoot=Join-Path $qaRoot 'other-instance';New-Item -ItemType Directory -Path $otherRoot | Out-Null
Copy-Item -Path (Join-Path $v6 '*') -Destination $otherRoot -Recurse
New-Item -ItemType File -Path (Join-Path $otherRoot 'portable.dat') | Out-Null
$start.FileName=Join-Path $otherRoot 'HeiBan.exe';$other=[Diagnostics.Process]::Start($start)
try {
    $otherJob=Job $otherRoot $true $zip
    Await-Worker $otherJob $false
    Assert (([Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $otherRoot 'HeiBan.exe'))).FileVersion -eq '1.0.12.6') 'Another live instance did not defer update'
    Assert (Test-Path -LiteralPath (Join-Path $otherJob.Cache 'pending.json')) 'Deferred update was lost'
} finally {
    if(-not $other.HasExited){Assert ($other.MainModule.FileName -eq (Join-Path $otherRoot 'HeiBan.exe')) 'Unexpected other process';$other.Kill();$other.WaitForExit()}
}

# Separate test AppId prevents fixture installs from touching a real HeiBan uninstall registration.
$testId=[guid]::NewGuid().ToString('N');$installerScript=Join-Path $qaRoot 'fixture.iss'
$template=@'
[Setup]
AppId=HeiBan-UpdateFixture-TESTID
AppName=HeiBan Update Fixture
AppVersion=1.0.12.VERSION
DefaultDirName=INSTALLROOT
PrivilegesRequired=lowest
OutputDir=OUTPUTROOT
OutputBaseFilename=fixture-VERSION
Uninstallable=yes
[Files]
Source: "SOURCEROOT\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "portable.dat"
'@
$installed=Join-Path $qaRoot 'installed'
foreach($preview in @(6,7)) {
    $template.Replace('TESTID',$testId).Replace('VERSION',"$preview").Replace('INSTALLROOT',$installed).Replace('OUTPUTROOT',$qaRoot).Replace('SOURCEROOT',(Join-Path $qaRoot "v$preview")) | Set-Content -LiteralPath $installerScript -Encoding utf8
    & $IsccPath $installerScript
    if($LASTEXITCODE -ne 0){throw 'Installer fixture compile failed'}
}
$initial=Start-Process -FilePath (Join-Path $qaRoot 'fixture-6.exe') -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-') -WindowStyle Hidden -Wait -PassThru
Assert ($initial.ExitCode -eq 0) 'Fixture install failed'
try {
    $installerJob=Job $installed $false (Join-Path $qaRoot 'fixture-7.exe')
    Await-Worker $installerJob $true
    Assert (([Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $installed 'HeiBan.exe'))).FileVersion -eq '1.0.12.7') 'Installer did not upgrade'
} finally {
    $uninstaller=Join-Path $installed 'unins000.exe'
    if(Test-Path -LiteralPath $uninstaller){$uninstall=Start-Process -FilePath $uninstaller -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART') -WindowStyle Hidden -Wait -PassThru;Assert ($uninstall.ExitCode -eq 0) 'Fixture uninstall failed'}
}
@{Success=$true;HandoffLockRetry=$true;ParentWait=$true;OtherInstanceDeferred=$true;PreviewToStable=$true;PortableApply=$true;DataHashPreserved=$true;UnknownFilePreserved=$true;CorruptPackageRejected=$true;InstallerUpgrade=$true;TestRegistrationRemoved=$true;Fixtures=$qaRoot} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $qaRoot 'result.json') -Encoding utf8
Write-Host "Update integration passed: $qaRoot"
