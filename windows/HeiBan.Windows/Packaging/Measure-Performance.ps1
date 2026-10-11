[CmdletBinding()]
param(
    [string]$OutputDirectory,
    [string]$Dotnet,
    [string]$Label = 'working-tree',
    [switch]$IncludeCoreChecks
)
$ErrorActionPreference = 'Stop'
$windowsRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$buildRoot = [IO.Path]::GetFullPath((Join-Path $windowsRoot '.build'))
if (!$OutputDirectory) { $OutputDirectory = Join-Path $buildRoot ('performance-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
if (!$outputRoot.StartsWith($buildRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'OutputDirectory must be a new directory inside windows/.build.' }
if (Test-Path -LiteralPath $outputRoot) { throw 'Choose a new output directory; previous evidence is preserved.' }
if (!$Dotnet) {
    $bundled = Join-Path $buildRoot 'tools\dotnet\dotnet.exe'
    $Dotnet = if (Test-Path -LiteralPath $bundled) { $bundled } else { (Get-Command dotnet -ErrorAction Stop).Source }
}
New-Item -ItemType Directory -Path $outputRoot | Out-Null
function Invoke-Dotnet([string[]]$Arguments, [string]$Log) {
    & $Dotnet @Arguments *> (Join-Path $outputRoot $Log)
    if ($LASTEXITCODE -ne 0) { throw "dotnet failed ($LASTEXITCODE); see $Log" }
}
$sourceBefore = $env:HEIBAN_PERFORMANCE_SOURCE
$dataBefore = $env:HEIBAN_WINDOWS_DATA_DIRECTORY
$storeBundle = Join-Path $windowsRoot 'dist\store\HeiBan-Store-1.0.12.0-x64-arm64.msixbundle'
$storeBefore = if (Test-Path -LiteralPath $storeBundle) { (Get-FileHash -LiteralPath $storeBundle -Algorithm SHA256).Hash } else { $null }
try {
    $source = (& git -C $windowsRoot rev-parse HEAD).Trim()
    $status = @(& git -C $windowsRoot status --porcelain -- .)
    $env:HEIBAN_PERFORMANCE_SOURCE = "$source + $Label; dirtyWindows=$($status.Count -gt 0)"
    $env:HEIBAN_WINDOWS_DATA_DIRECTORY = Join-Path $outputRoot 'synthetic-data'
    Add-Type -AssemblyName System.Windows.Forms
    $system = Get-CimInstance Win32_ComputerSystem
    $hardware = [ordered]@{
        sourceCommit = $source; label = $Label; dirtyWindows = ($status.Count -gt 0)
        capturedUtc = [DateTime]::UtcNow.ToString('o'); configuration = 'Release'; runtime = 'win-x64'
        model = $system.Model; ramBytes = $system.TotalPhysicalMemory; hypervisorPresent = $system.HypervisorPresent
        cpu = @(Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors)
        gpu = @(Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, CurrentHorizontalResolution, CurrentVerticalResolution, CurrentRefreshRate)
        os = (Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber)
        screens = @([System.Windows.Forms.Screen]::AllScreens | ForEach-Object { @{ primary=$_.Primary; x=$_.Bounds.X; y=$_.Bounds.Y; width=$_.Bounds.Width; height=$_.Bounds.Height } })
        screenCoordinateScope = 'PowerShell WinForms bounds may be DPI-virtualized; native result records physical overlay dimensions and canvas DPI'
        powerScheme = (& powercfg /getactivescheme | Out-String).Trim(); powerSupply = 'Desktop / battery state not measured'
        isolation = 'new synthetic-data directory under output root; no user documents'
        scope = 'Synthetic CPU/native synchronization; no physical input-to-display measurement'
        storeBundleSha256Before = $storeBefore
    }
    $hardware | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $outputRoot 'environment.json') -Encoding UTF8
    $sourceFiles = @(& git -C $windowsRoot ls-files --cached --others --exclude-standard -- '*.cs' '*.csproj' '*.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inventory source files.' }
    $hashes = @($sourceFiles | Sort-Object -Unique | ForEach-Object { @{ path=$_; sha256=(Get-FileHash -LiteralPath (Join-Path $windowsRoot $_) -Algorithm SHA256).Hash.ToLowerInvariant() } })
    $hashes | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $outputRoot 'source-files.json') -Encoding UTF8
    if ($IncludeCoreChecks) {
        Invoke-Dotnet @('run','--project',(Join-Path $windowsRoot 'HeiBan.Windows.Core.Tests\HeiBan.Windows.Core.Tests.csproj'),'-c','Release','--artifacts-path',(Join-Path $outputRoot 'core')) 'core-checks.log'
    }
    Invoke-Dotnet @('run','--project',(Join-Path $windowsRoot 'HeiBan.Windows.Performance\HeiBan.Windows.Performance.csproj'),'-c','Release','--artifacts-path',(Join-Path $outputRoot 'cpu'),'--',(Join-Path $outputRoot 'cpu.json'),$Label) 'cpu.log'
    $publish = Join-Path $outputRoot 'native\publish'
    Invoke-Dotnet @('publish',(Join-Path $windowsRoot 'HeiBan.Windows\HeiBan.Windows.csproj'),'-c','Release','-r','win-x64','--self-contained','true','--artifacts-path',(Join-Path $outputRoot 'native'),'-p:Platform=x64','-p:WindowsPackageType=None','-p:WindowsAppSdkBootstrapInitialize=false','-p:WindowsAppSdkDeploymentManagerInitialize=false','-o',$publish) 'native-build.log'
    $nativeResults = Join-Path $outputRoot 'native-results'
    $process = Start-Process -FilePath (Join-Path $publish 'HeiBan.exe') -ArgumentList ('--performance-output="' + $nativeResults + '"') -WindowStyle Hidden -PassThru
    # Preserve a timed-out process for diagnosis; never terminate other app instances.
    $finished = $false
    for ($attempt=0; $attempt -lt 3 -and !$finished; $attempt++) { $finished=$process.WaitForExit(60000) }
    if (!$finished) { throw "Benchmark timeout; owned process PID=$($process.Id). Results are preserved." }
    $resultPath = Join-Path $nativeResults 'performance.json'
    if (!(Test-Path -LiteralPath $resultPath)) { throw 'Native process produced no result; inspect the isolated startup logs.' }
    $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    if ($process.ExitCode -ne 0 -or !$result.success) { throw "Native checks failed; see $resultPath" }
    Write-Output "Completed synthetic measurements: $outputRoot"
}
finally {
    $env:HEIBAN_PERFORMANCE_SOURCE = $sourceBefore; $env:HEIBAN_WINDOWS_DATA_DIRECTORY = $dataBefore
    $storeAfter = if (Test-Path -LiteralPath $storeBundle) { (Get-FileHash -LiteralPath $storeBundle -Algorithm SHA256).Hash } else { $null }
    @{ before=$storeBefore; after=$storeAfter; unchanged=($storeBefore -eq $storeAfter) } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputRoot 'store-preservation.json') -Encoding UTF8
    if ($storeBefore -ne $storeAfter) { throw 'Store evidence changed during measurement; investigate before delivery.' }
}
