param(
    [ValidateSet('Debug','Release')][string]$Configuration='Release',
    [ValidateSet('win-x64','win-arm64')][string]$Runtime='win-x64'
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Publish-Common.ps1')
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$version = Get-HeiBanVersion
$dist = Join-Path $root 'dist'
$staging = Join-Path $root ".staging\portable-$Runtime-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force $dist | Out-Null
try {
    Publish-HeiBan $Configuration $Runtime $staging
    New-Item -ItemType File -Path (Join-Path $staging 'portable.dat') | Out-Null
    foreach($name in @('Boards','Metadata','Thumbnails','Trash','Settings')) {
        New-Item -ItemType Directory -Force (Join-Path $staging "Data\$name") | Out-Null
    }
    Copy-Item (Join-Path $root 'README.md') (Join-Path $staging 'README-Windows.md')
    Write-HeiBanUpdateInventory $staging
    $zip = Join-Path $dist "HeiBan-Windows-Portable-$version-$Runtime.zip"
    Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $zip -Force -CompressionLevel Optimal
    (Get-FileHash $zip -Algorithm SHA256).Hash + '  ' + [IO.Path]::GetFileName($zip) | Set-Content "$zip.sha256" -Encoding ascii
    Write-Host "免安裝版：$zip"
} finally {
    $staging = [IO.Path]::GetFullPath($staging)
    $stagingRoot = [IO.Path]::GetFullPath((Join-Path $root '.staging')).TrimEnd('\') + '\'
    if (-not $staging.StartsWith($stagingRoot,[StringComparison]::OrdinalIgnoreCase)) { throw '拒絕清理範圍外的封裝暫存。' }
    if(Test-Path $staging){Remove-Item $staging -Recurse -Force}
}
