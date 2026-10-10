param([ValidateSet('Debug','Release')][string]$Configuration='Release',[string]$DotnetPath='dotnet')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$project=Join-Path $PSScriptRoot '..\HeiBan.Windows.csproj'
$identity=Get-Content (Join-Path $PSScriptRoot 'Store\StoreIdentity.json') -Raw -Encoding UTF8 | ConvertFrom-Json
[xml]$manifest=Get-Content (Join-Path $PSScriptRoot 'Store\Package.appxmanifest') -Raw -Encoding UTF8
foreach($pair in @(@('Name','name'),@('Publisher','publisher'),@('Version','packageVersion'))) {
    if($manifest.Package.Identity.GetAttribute($pair[0]) -cne $identity.($pair[1])) {throw "Store identity mismatch: $($pair[0])"}
}
if($manifest.Package.Properties.PublisherDisplayName -cne $identity.publisherDisplayName -or $manifest.Package.Properties.DisplayName -cne $identity.displayName){throw 'Store display identity mismatch.'}
$packageVersion=[Version]::Parse($identity.packageVersion)
$invalidNumbers=@($packageVersion.Major,$packageVersion.Minor,$packageVersion.Build) | Where-Object {$_ -lt 0 -or $_ -gt 65535}
if($packageVersion.Major -lt 1 -or $packageVersion.Revision -ne 0 -or $invalidNumbers){throw 'Store version must use four integers with a final 0.'}
$dotnet=(Get-Command $DotnetPath -ErrorAction Stop).Source
# Use a separate SDK artifacts tree so MSIX-generated XAML/PRI cannot enter an EXE/Portable build.
$batch=Join-Path $root ('.build\store-'+[guid]::NewGuid().ToString('N'))
$bundleInput=Join-Path $batch 'bundle-input'
$dist=Join-Path $root 'dist\store'
New-Item -ItemType Directory -Force $batch,$bundleInput,$dist | Out-Null
$artifacts=@()
$payloadChecks=@()
function Read-StorePackage([string]$path,[string]$architecture) {
    $zip=[IO.Compression.ZipFile]::OpenRead($path)
    try {
        $entry=$zip.GetEntry('AppxManifest.xml')
        if(-not $entry){throw 'Package manifest is missing.'}
        $reader=[IO.StreamReader]::new($entry.Open())
        try {[xml]$actual=$reader.ReadToEnd()}finally{$reader.Dispose()}
        foreach($pair in @(@('Name','name'),@('Publisher','publisher'),@('Version','packageVersion'))){
            if($actual.Package.Identity.GetAttribute($pair[0]) -cne $identity.($pair[1])){throw "Built package identity mismatch: $($pair[0])"}
        }
        if($actual.Package.Identity.ProcessorArchitecture -cne $architecture){throw 'Built package architecture mismatch.'}
        if($actual.Package.Properties.PublisherDisplayName -cne $identity.publisherDisplayName){throw 'Built publisher display name mismatch.'}
        if(@($zip.Entries | Where-Object {$_.FullName -match '(^|/)(Data|Updater)(/|$)|portable\.dat$|update-files\.json$|\.pdb$'}).Count){throw 'Store package contains standalone updater/data/debug payload.'}
        foreach($required in @('HeiBan.exe','HeiBan.dll','HeiBan.Windows.Core.dll','resources.pri','coreclr.dll','Microsoft.ui.xaml.dll','Microsoft.Graphics.Canvas.dll','Assets/Store/StoreLogo.png','Assets/Store/Square44x44Logo.png','Assets/Store/Square150x150Logo.png')){
            $file=$zip.GetEntry($required)
            if(-not $file -or $file.Length -eq 0){throw "Store package is missing $required"}
        }
        # Match every shipped legal notice and the current guides byte for byte. This is a
        # packaging guard, and does not substitute for installing/running the Store app.
        $sourceFiles=@(Get-ChildItem -LiteralPath (Join-Path $root 'Licenses') -File | ForEach-Object {@{source=$_.FullName;entry='Licenses/'+$_.Name}})
        $sourceFiles+=@{source=(Join-Path $PSScriptRoot '..\Assets\HeiBanUserGuide.html');entry='Assets/HeiBanUserGuide.html'}
        $sourceFiles+=@{source=(Join-Path $PSScriptRoot 'Store\README-Store.zh-TW.md');entry='README-Store.md'}
        foreach($file in $sourceFiles){
            $entry=$zip.GetEntry($file.entry)
            if(-not $entry){throw "Missing original document: $($file.entry)"}
            $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
            try {$hash=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}finally{$stream.Dispose();$sha.Dispose()}
            if($hash -ne (Get-FileHash -LiteralPath $file.source -Algorithm SHA256).Hash){throw "Changed original document: $($file.entry)"}
        }
        return @{architecture=$architecture;entries=$zip.Entries.Count;legalDocuments=$sourceFiles.Count-2;identityMatched=$true;requiredPayloadPresent=$true;originalDocumentsMatched=$true;noUserDataOrStandaloneUpdater=$true;appExecutionChecked=$false}
    }finally{$zip.Dispose()}
}
foreach($arch in @('x64','arm64')) {
    $platform=if($arch -eq 'arm64'){'ARM64'}else{'x64'}
    $sdkOutput=Join-Path $batch "packages-$arch"
    $buildLog=Join-Path $batch "build-$arch.log"
    & $dotnet build $project -c $Configuration -r "win-$arch" --artifacts-path (Join-Path $batch "artifacts-$arch") `
        "-p:Platform=$platform" -p:HeiBanStoreBuild=true -p:AppxPackageSigningEnabled=false `
        -p:DebugType=none -p:DebugSymbols=false -p:AppxPackageValidationEnabled=true -p:AppxStrictManifestValidationEnabled=true `
        "-p:AppxPackageDir=$sdkOutput/" *> $buildLog
    if($LASTEXITCODE -ne 0){Get-Content $buildLog -Tail 25;throw "Store $arch build failed: $LASTEXITCODE"}
    $packages=@(Get-ChildItem -LiteralPath $sdkOutput -Filter '*.msix' -File -Recurse)
    if($packages.Count -ne 1){throw "Expected exactly one $arch MSIX, got $($packages.Count)."}
    $payloadChecks+=Read-StorePackage $packages[0].FullName $arch
    $destination=Join-Path $dist "HeiBan-Store-$($identity.packageVersion)-$arch.msix"
    Copy-Item -LiteralPath $packages[0].FullName -Destination $destination -Force
    Copy-Item -LiteralPath $destination -Destination $bundleInput
    $artifacts+=Get-Item -LiteralPath $destination
    Write-Host "Store ${arch}: $destination"
}
# The SDK tool version is pinned by the app project. Find the tool in that restored package,
# rather than use an arbitrary installed SDK or require a machine-specific path in source.
[xml]$projectXml=Get-Content $project -Raw -Encoding UTF8
$sdkVersion=($projectXml.Project.ItemGroup.PackageReference | Where-Object {$_.Include -eq 'Microsoft.Windows.SDK.BuildTools'}).Version
$nugetRoot=if($env:NUGET_PACKAGES){$env:NUGET_PACKAGES}else{Join-Path $env:USERPROFILE '.nuget\packages'}
$tools=@(Get-ChildItem (Join-Path $nugetRoot "microsoft.windows.sdk.buildtools\$sdkVersion\bin") -Directory | ForEach-Object {Join-Path $_.FullName 'x64\makeappx.exe'} | Where-Object {Test-Path -LiteralPath $_ -PathType Leaf})
if($tools.Count -ne 1){throw 'Unable to resolve the pinned Windows SDK MakeAppx tool.'}
$bundle=Join-Path $dist "HeiBan-Store-$($identity.packageVersion)-x64-arm64.msixbundle"
& $tools[0] bundle /d $bundleInput /p $bundle /bv $identity.packageVersion /o *> (Join-Path $batch 'bundle.log')
if($LASTEXITCODE -ne 0){Get-Content (Join-Path $batch 'bundle.log') -Tail 20;throw "Store bundle failed: $LASTEXITCODE"}
$artifacts+=Get-Item -LiteralPath $bundle
$sourceHashes=[ordered]@{}
$sourcePaths=& git -c core.quotepath=false -C (Split-Path $root -Parent) ls-files --cached --others --exclude-standard -- windows
if($LASTEXITCODE -ne 0){throw 'Unable to record Store source files.'}
foreach($path in ($sourcePaths | Sort-Object -Unique)){
    if($path -notlike 'windows/docs/*'){
        $file=Join-Path (Split-Path $root -Parent) $path
        if(Test-Path -LiteralPath $file -PathType Leaf){$sourceHashes[$path]=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()}
    }
}
$sourceHead=& git -C (Split-Path $root -Parent) rev-parse HEAD
$report=[ordered]@{schema=1;identity=$identity;configuration=$Configuration;signed=$false;storeSubmitted=$false;sourceGitHead=$sourceHead;sourceSnapshot=$sourceHashes;payloadChecks=$payloadChecks;artifacts=@()}
foreach($artifact in $artifacts){
    $hash=(Get-FileHash -LiteralPath $artifact.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $($artifact.Name)" | Set-Content -LiteralPath ($artifact.FullName+'.sha256') -Encoding ASCII
    $report.artifacts+=@{file=$artifact.Name;bytes=$artifact.Length;sha256=$hash}
}
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $dist 'STORE_ARTIFACTS.json') -Encoding UTF8
Write-Host "Store bundle: $bundle"
Write-Host "Build logs: $batch"
# Keep build evidence; no recursive cleanup or changes to existing release artifacts/user data.
