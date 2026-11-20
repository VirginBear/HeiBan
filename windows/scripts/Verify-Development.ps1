[CmdletBinding()]
param(
    [string]$OutputDirectory,
    [switch]$IncludeNative
)
$ErrorActionPreference='Stop'
$windowsRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repositoryRoot=Split-Path $windowsRoot
if(!$OutputDirectory){$OutputDirectory=Join-Path $windowsRoot ('.build/verification-'+[guid]::NewGuid().ToString('N'))}
$output=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path -LiteralPath $output){throw 'Choose a new output directory to preserve earlier evidence.'}
$dotnet=(Get-Command dotnet -ErrorAction Stop).Source
$python=(Get-Command python -ErrorAction Stop).Source
New-Item -ItemType Directory -Path $output | Out-Null
$steps=[Collections.Generic.List[object]]::new()
$started=[DateTime]::UtcNow
$passed=$false
$failure=$null
$sourcesBefore=$null
$sourcesAfter=$null
$sourcesStable=$false
$source=$null

function Get-SourceInventory {
    $paths=@(& git -C $repositoryRoot ls-files --cached --others --exclude-standard -- windows .github/workflows/windows-build.yml)
    if($LASTEXITCODE -ne 0){throw 'Unable to enumerate source files.'}
    $inventory=[ordered]@{}
    $extensions=@('.cs','.csproj','.xaml','.ps1','.py','.json','.txt','.html','.svg','.png','.wav','.ico','.manifest','.appxmanifest','.yml')
    foreach($path in ($paths | Sort-Object -Unique)) {
        if([IO.Path]::GetExtension($path) -notin $extensions -or $path.StartsWith('windows/docs/')){continue}
        $inventory[$path]=(Get-FileHash -LiteralPath (Join-Path $repositoryRoot $path) -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    return $inventory
}

function Invoke-Check([string]$Name,[string]$Executable,[string[]]$Arguments) {
    $watch=[Diagnostics.Stopwatch]::StartNew()
    $log=Join-Path $output ($Name+'.log')
    & $Executable @Arguments *> $log
    $code=$LASTEXITCODE
    $steps.Add([ordered]@{name=$Name;exitCode=$code;seconds=$watch.Elapsed.TotalSeconds;log=$log})
    if($code -ne 0){Get-Content -LiteralPath $log -Tail 20;throw "Check failed: $Name"}
    Write-Output "Passed $Name"
}

function Invoke-NativeCheck([string]$Name,[bool]$Images) {
    $resultFolder=Join-Path $output $Name
    $data=Join-Path $output ($Name+'-data')
    $launch=[Diagnostics.ProcessStartInfo]::new((Join-Path $output 'build/bin/HeiBan.Windows/release_win-x64/HeiBan.exe'))
    $launch.WorkingDirectory=Split-Path $launch.FileName
    $launch.UseShellExecute=$false
    $launch.CreateNoWindow=$true
    $launch.Environment['HEIBAN_WINDOWS_DATA_DIRECTORY']=$data
    $launch.Environment.Remove('HEIBAN_QA_IMAGE_FILE') | Out-Null
    if($Images){$launch.Environment['HEIBAN_QA_IMAGE_FILE']='generated'}
    $launch.ArgumentList.Add('--release-validation-output='+$resultFolder)
    $launch.ArgumentList.Add('--release-validation-exit')
    $watch=[Diagnostics.Stopwatch]::StartNew()
    $process=[Diagnostics.Process]::Start($launch)
    try {
        if(!$process.WaitForExit(45000)){throw "Native validation timed out: $Name"}
        if($process.ExitCode -ne 0){throw "Native process failed: $Name, exit code $($process.ExitCode)"}
        $filename=if($Images){'image-resolution.json'}else{'release110-result.json'}
        $result=Get-Content -LiteralPath (Join-Path $resultFolder $filename) -Raw | ConvertFrom-Json
        if(!$result.success -or (Test-Path -LiteralPath (Join-Path $resultFolder 'release110-error.txt')) -or
            (Test-Path -LiteralPath (Join-Path $data 'last-ui-error.txt'))){throw "Native evidence failed: $Name"}
        $steps.Add([ordered]@{name=$Name;exitCode=0;seconds=$watch.Elapsed.TotalSeconds;evidence=(Join-Path $resultFolder $filename)})
        Write-Output "Passed $Name"
    }
    finally {
        if(!$process.HasExited){$process.Kill();$process.WaitForExit(5000) | Out-Null}
        $process.Dispose()
    }
}

Push-Location $repositoryRoot
try {
    $source=(& git rev-parse HEAD).Trim()
    if($LASTEXITCODE -ne 0){throw 'Unable to identify source commit.'}
    $sourcesBefore=Get-SourceInventory
    $sourcesBefore | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $output 'sources.json') -Encoding utf8
    $artifacts=Join-Path $output 'build'
    Invoke-Check 'architecture' $dotnet @('run','--project','windows/HeiBan.Windows.ArchitectureChecks','-c','Release','--artifacts-path',$artifacts,'--',$windowsRoot,(Join-Path $output 'architecture.json'))
    Invoke-Check 'localization' $python @('windows/scripts/Build-LocalizationCatalogs.py','--check')
    Invoke-Check 'guides' $python @('windows/scripts/Build-UserGuides.py','--check')
    Invoke-Check 'core' $dotnet @('run','--project','windows/HeiBan.Windows.Core.Tests','-c','Release','--artifacts-path',$artifacts)
    Invoke-Check 'optimization' $dotnet @('run','--project','windows/HeiBan.Windows.OptimizationChecks','-c','Release','--artifacts-path',$artifacts,'--',(Join-Path $output 'optimization'))
    if($IncludeNative) {
        Invoke-Check 'winui-build' $dotnet @('build','windows/HeiBan.Windows/HeiBan.Windows.csproj','-c','Release','-r','win-x64','--artifacts-path',$artifacts,'-p:Platform=x64','-p:WindowsPackageType=None','-p:HeiBanValidationBuild=true')
        Invoke-NativeCheck 'native-editor' $false
        Invoke-NativeCheck 'native-images' $true
    }
    $sourcesAfter=Get-SourceInventory
    $sourcesStable=($sourcesBefore | ConvertTo-Json -Compress) -eq ($sourcesAfter | ConvertTo-Json -Compress)
    if(!$sourcesStable){throw 'Sources changed during verification. Rerun against the current tree.'}
    $passed=$true
}
catch {
    $failure=$_.Exception.Message
    Write-Warning $failure
}
finally {
    [ordered]@{
        schema=1;passed=$passed;startedUtc=$started;finishedUtc=[DateTime]::UtcNow
        sourceCommit=$source;sourceInventory='sources.json';sourcesStable=$sourcesStable
        dotnetVersion=(& $dotnet --version);pythonVersion=(& $python --version)
        nativeRequested=[bool]$IncludeNative;steps=$steps;failure=$failure
        scope='Source policies, data contracts and optional native synthetic checks. Hardware input latency, manual UX and Store certification require separate evidence.'
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $output 'verification.json') -Encoding utf8
    Pop-Location
}
if(!$passed){exit 1}
Write-Output "Verification evidence: $output"
