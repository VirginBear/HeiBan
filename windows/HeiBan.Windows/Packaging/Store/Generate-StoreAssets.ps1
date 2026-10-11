$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$source=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Assets\AppIcon.png'))
$destination=Join-Path $PSScriptRoot 'Assets'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
$image=[Drawing.Image]::FromFile($source)
try {
    $assets=[ordered]@{'StoreLogo'=50;'Square150x150Logo'=150;'Square44x44Logo'=44}
    foreach($name in $assets.Keys) {
        foreach($scale in @(100,200,400)) {
            $size=[int]($assets[$name]*$scale/100)
            $bitmap=[Drawing.Bitmap]::new($size,$size,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $graphics=[Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.Clear([Drawing.Color]::Transparent)
                $graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.CompositingQuality=[Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.PixelOffsetMode=[Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.DrawImage($image,[Drawing.Rectangle]::new(0,0,$size,$size))
                $filename=if($scale -eq 100){"$name.png"}else{"$name.scale-$scale.png"}
                $bitmap.Save((Join-Path $destination $filename),[Drawing.Imaging.ImageFormat]::Png)
            } finally {$graphics.Dispose();$bitmap.Dispose()}
        }
    }
} finally {$image.Dispose()}
Write-Host 'Store icon assets generated from the existing HeiBan icon.'
