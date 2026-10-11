param(
    [ValidateSet('Debug','Release')][string]$Configuration='Release',
    [ValidateSet('win-x64','win-arm64')][string]$Runtime='win-x64',
    [string]$IsccPath
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Publish-Common.ps1')
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$version = Get-HeiBanVersion
$dist = Join-Path $root 'dist'
$staging = Join-Path $root ".staging\installer-$Runtime-$([guid]::NewGuid().ToString('N'))"
if(-not $IsccPath) {
    $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if($command){$IsccPath=$command.Source}
    else {
        foreach($candidate in @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 7\ISCC.exe")) {
            if(Test-Path $candidate){$IsccPath=$candidate;break}
        }
    }
}
if(-not $IsccPath -or -not (Test-Path $IsccPath)){throw '找不到 Inno Setup 的 ISCC.exe；請安裝官方編譯器或指定 -IsccPath。'}
New-Item -ItemType Directory -Force $dist | Out-Null
try {
    Publish-HeiBan $Configuration $Runtime $staging
    if(Test-Path (Join-Path $staging 'portable.dat')){throw '安裝版不可含 portable.dat。'}
    $arch = if($Runtime -eq 'win-arm64'){'arm64'}else{'x64'}
    & $IsccPath "/DSourceDir=$staging" "/DOutputDir=$dist" "/DAppVersion=$version" "/DArch=$arch" (Join-Path $PSScriptRoot 'inno_setup.iss')
    if($LASTEXITCODE -ne 0){throw "ISCC 失敗，代碼 $LASTEXITCODE"}
    $exe = Join-Path $dist "HeiBan-Setup-$version-$arch.exe"
    if(-not (Test-Path $exe)){throw '安裝檔未產生。'}
    (Get-FileHash $exe -Algorithm SHA256).Hash + '  ' + [IO.Path]::GetFileName($exe) | Set-Content "$exe.sha256" -Encoding ascii
    Write-Host "安裝版：$exe"
} finally {
    $staging = [IO.Path]::GetFullPath($staging)
    $stagingRoot = [IO.Path]::GetFullPath((Join-Path $root '.staging')).TrimEnd('\') + '\'
    if (-not $staging.StartsWith($stagingRoot,[StringComparison]::OrdinalIgnoreCase)) { throw '拒絕清理範圍外的封裝暫存。' }
    if(Test-Path $staging){Remove-Item $staging -Recurse -Force}
}
