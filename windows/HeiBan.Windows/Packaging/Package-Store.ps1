param([ValidateSet('Debug','Release')][string]$Configuration='Release',[string]$DotnetPath='dotnet',
      [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')][string]$DevelopmentLabel)
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
if($DevelopmentLabel){$dist=Join-Path $dist ('candidates\'+$DevelopmentLabel)}
New-Item -ItemType Directory -Force $batch,$bundleInput,$dist | Out-Null
# A submitted package's bytes must survive. Development labels isolate same-version
# candidates; formal version changes remain a user decision after validation.
$versionReport=Join-Path $dist "STORE_ARTIFACTS_$($identity.packageVersion).json"
foreach($name in @("HeiBan-Store-$($identity.packageVersion)-x64.msix","HeiBan-Store-$($identity.packageVersion)-arm64.msix","HeiBan-Store-$($identity.packageVersion)-x64-arm64.msixbundle","STORE_ARTIFACTS_$($identity.packageVersion).json")){
    $target=Join-Path $dist $name
    if((Test-Path -LiteralPath $target) -or (Test-Path -LiteralPath ($target+'.sha256'))){throw "Store artifacts already exist; preserve them and use a new DevelopmentLabel for an unapproved candidate: $target"}
}
$latestReport=Join-Path $dist 'STORE_ARTIFACTS.json'
if(Test-Path -LiteralPath $latestReport){
    $previous=Get-Content -LiteralPath $latestReport -Raw -Encoding UTF8 | ConvertFrom-Json
    $previousVersion=[Version]::Parse($previous.identity.packageVersion)
    $previousReport=Join-Path $dist "STORE_ARTIFACTS_$previousVersion.json"
    if(Test-Path -LiteralPath $previousReport){
        if((Get-FileHash -LiteralPath $previousReport).Hash -ne (Get-FileHash -LiteralPath $latestReport).Hash){throw 'Previous version report differs; preserve/reconcile before packaging.'}
    }else{Copy-Item -LiteralPath $latestReport -Destination $previousReport}
}
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
        if($actual.Package.Dependencies.TargetDeviceFamily.MinVersion -cne '10.0.19041.0'){throw 'Built Store minimum OS version mismatch.'}
        if($actual.Package.Properties.PublisherDisplayName -cne $identity.publisherDisplayName){throw 'Built publisher display name mismatch.'}
        if(@($zip.Entries | Where-Object {$_.FullName -match '(^|/)(Data|Updater)(/|$)|portable\.dat$|update-files\.json$|\.pdb$'}).Count){throw 'Store package contains standalone updater/data/debug payload.'}
        foreach($required in @('HeiBan.exe','HeiBan.dll','HeiBan.Windows.Core.dll','resources.pri','coreclr.dll','Microsoft.ui.xaml.dll','Microsoft.Graphics.Canvas.dll','Assets/Store/StoreLogo.png','Assets/Store/Square44x44Logo.png','Assets/Store/Square150x150Logo.png')){
            $file=$zip.GetEntry($required)
            if(-not $file -or $file.Length -eq 0){throw "Store package is missing $required"}
        }
        # Match every shipped legal notice and the current guides byte for byte. This is a
        # packaging guard, and does not substitute for installing/running the Store app.
        $licenseRoot=Join-Path $root 'Licenses'
        $sourceFiles=@(Get-ChildItem -LiteralPath $licenseRoot -File -Recurse | ForEach-Object {@{source=$_.FullName;entry='Licenses/'+$_.FullName.Substring($licenseRoot.Length+1).Replace('\','/')}})
        $sourceFiles+=@{source=(Join-Path $PSScriptRoot '..\Assets\HeiBanUserGuide.html');entry='Assets/HeiBanUserGuide.html'}
        $sourceFiles+=@{source=(Join-Path $PSScriptRoot 'Store\README-Store.zh-TW.md');entry='README-Store.md'}
        $guideRoot=Join-Path $PSScriptRoot '..\Assets\Guides'
        $guideFiles=@(Get-ChildItem -LiteralPath $guideRoot -File)
        foreach($guideFile in $guideFiles){$sourceFiles+=@{source=$guideFile.FullName;entry='Assets/Guides/'+$guideFile.Name}}
        foreach($file in $sourceFiles){
            $entry=$zip.GetEntry($file.entry)
            if(-not $entry){throw "Missing original document: $($file.entry)"}
            $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
            try {$hash=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}finally{$stream.Dispose();$sha.Dispose()}
            if($hash -ne (Get-FileHash -LiteralPath $file.source -Algorithm SHA256).Hash){throw "Changed original document: $($file.entry)"}
        }
        return @{architecture=$architecture;entries=$zip.Entries.Count;legalDocuments=$sourceFiles.Count-2-$guideFiles.Count;guideDocuments=$guideFiles.Count;identityMatched=$true;requiredPayloadPresent=$true;originalDocumentsMatched=$true;noUserDataOrStandaloneUpdater=$true;appExecutionChecked=$false}
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
    Copy-Item -LiteralPath $packages[0].FullName -Destination $destination
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
$bundleZip=[IO.Compression.ZipFile]::OpenRead($bundle)
try {
    $reader=[IO.StreamReader]::new($bundleZip.GetEntry('AppxMetadata/AppxBundleManifest.xml').Open())
    try {[xml]$bundleManifest=$reader.ReadToEnd()}finally{$reader.Dispose()}
    if($bundleManifest.Bundle.Identity.Name -cne $identity.name -or $bundleManifest.Bundle.Identity.Publisher -cne $identity.publisher -or $bundleManifest.Bundle.Identity.Version -cne $identity.packageVersion){throw 'Bundle identity mismatch.'}
    $bundlePackages=@($bundleManifest.Bundle.Packages.Package)
    if($bundlePackages.Count -ne 2 -or @($bundlePackages | Where-Object {$_.Architecture -eq 'x64'}).Count -ne 1 -or @($bundlePackages | Where-Object {$_.Architecture -eq 'arm64'}).Count -ne 1){throw 'Bundle must contain exactly x64 and ARM64 application packages.'}
    foreach($package in $bundlePackages){
        if($package.Version -cne $identity.packageVersion -or $package.Type -ne 'application'){throw 'Bundle application version/type mismatch.'}
        $entry=$bundleZip.GetEntry($package.FileName)
        if(-not $entry){throw 'Bundle application payload is missing.'}
        $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
        try {$hash=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}finally{$stream.Dispose();$sha.Dispose()}
        if($hash -ne (Get-FileHash -LiteralPath (Join-Path $bundleInput $package.FileName) -Algorithm SHA256).Hash){throw 'Bundle application bytes differ from the packaged MSIX.'}
    }
}finally{$bundleZip.Dispose()}
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
$report=[ordered]@{schema=1;identity=$identity;configuration=$Configuration;developmentLabel=$DevelopmentLabel;formalVersionApproved=$false;signed=$false;storeSubmitted=$false;sourceGitHead=$sourceHead;sourceSnapshot=$sourceHashes;payloadChecks=$payloadChecks;bundleIdentityAndArchitecturesMatched=$true;bundlePackageBytesMatched=$true;artifacts=@()}
foreach($artifact in $artifacts){
    $hash=(Get-FileHash -LiteralPath $artifact.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $($artifact.Name)" | Set-Content -LiteralPath ($artifact.FullName+'.sha256') -Encoding ASCII
    $report.artifacts+=@{file=$artifact.Name;bytes=$artifact.Length;sha256=$hash}
}
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $versionReport -Encoding UTF8
Copy-Item -LiteralPath $versionReport -Destination $latestReport -Force
Write-Host "Store bundle: $bundle"
Write-Host "Build logs: $batch"
# Keep build evidence; no recursive cleanup or changes to existing release artifacts/user data.
