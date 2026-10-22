$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$assets=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\Assets'))
$image=[Drawing.Image]::FromFile((Join-Path $assets 'AppIcon.png'))
$frames=[Collections.Generic.List[object]]::new()
try {
    foreach($size in @(16,20,24,30,32,36,40,48,60,64,72,80,96,256)) {
        $bitmap=[Drawing.Bitmap]::new($size,$size,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics=[Drawing.Graphics]::FromImage($bitmap)
        $stream=[IO.MemoryStream]::new()
        try {
            $graphics.Clear([Drawing.Color]::Transparent)
            $graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.CompositingQuality=[Drawing.Drawing2D.CompositingQuality]::HighQuality
            $graphics.PixelOffsetMode=[Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.DrawImage($image,[Drawing.Rectangle]::new(0,0,$size,$size))
            if($size -eq 256) {
                $bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png)
            } else {
                # Small Win32 icons carry both straight BGRA alpha and a 1-bit
                # fallback AND mask. No color-key matte is painted behind the logo.
                $writer=[IO.BinaryWriter]::new($stream,[Text.Encoding]::UTF8,$true)
                try {
                    $maskStride=[int]([Math]::Ceiling($size/32.0)*4)
                    $writer.Write([uint32]40);$writer.Write([int]$size);$writer.Write([int]($size*2))
                    $writer.Write([uint16]1);$writer.Write([uint16]32);$writer.Write([uint32]0)
                    $writer.Write([uint32]($size*$size*4+$maskStride*$size))
                    foreach($unused in 1..4){$writer.Write([uint32]0)}
                    for($y=$size-1;$y -ge 0;$y--) {
                        for($x=0;$x -lt $size;$x++) {
                            $pixel=$bitmap.GetPixel($x,$y)
                            if($pixel.A -eq 0){$writer.Write([uint32]0)}
                            else {$writer.Write([byte]$pixel.B);$writer.Write([byte]$pixel.G);$writer.Write([byte]$pixel.R);$writer.Write([byte]$pixel.A)}
                        }
                    }
                    for($y=$size-1;$y -ge 0;$y--) {
                        $mask=[byte[]]::new($maskStride)
                        for($x=0;$x -lt $size;$x++) {
                            if($bitmap.GetPixel($x,$y).A -eq 0){$index=[int][Math]::Floor($x/8);$mask[$index]=$mask[$index] -bor (128 -shr ($x%8))}
                        }
                        $writer.Write($mask)
                    }
                } finally {$writer.Dispose()}
            }
            $frames.Add(@{Size=$size;Bytes=$stream.ToArray()})
        } finally {$stream.Dispose();$graphics.Dispose();$bitmap.Dispose()}
    }
    $output=[IO.File]::Create((Join-Path $assets 'AppIcon.ico'))
    $writer=[IO.BinaryWriter]::new($output)
    try {
        $writer.Write([uint16]0);$writer.Write([uint16]1);$writer.Write([uint16]$frames.Count)
        $offset=6+16*$frames.Count
        foreach($frame in $frames) {
            $dimension=if($frame.Size -eq 256){0}else{$frame.Size}
            $writer.Write([byte]$dimension);$writer.Write([byte]$dimension)
            $writer.Write([byte]0);$writer.Write([byte]0);$writer.Write([uint16]1);$writer.Write([uint16]32)
            $writer.Write([uint32]$frame.Bytes.Length);$writer.Write([uint32]$offset)
            $offset+=$frame.Bytes.Length
        }
        foreach($frame in $frames){$writer.Write([byte[]]$frame.Bytes)}
    } finally {$writer.Dispose()}
} finally {$image.Dispose()}
Write-Output 'Desktop ICO generated in 14 native sizes from the unchanged AppIcon.png.'
