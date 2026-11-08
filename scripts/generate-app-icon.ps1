# Gera icone Windows ICO (PNG 256x256 embutido), sem ferramentas externas.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$OutputPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
function Rounded([int]$x,[int]$y,[int]$w,[int]$h,[int]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x,$y,$d,$d,180,90)
    $p.AddArc(($x+$w-$d),$y,$d,$d,270,90)
    $p.AddArc(($x+$w-$d),($y+$h-$d),$d,$d,0,90)
    $p.AddArc($x,($y+$h-$d),$d,$d,90,90)
    $p.CloseFigure()
    return $p
}
$bitmap = New-Object System.Drawing.Bitmap(256,256,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bitmap)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$bg = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
    [System.Drawing.Point]::new(0,0),[System.Drawing.Point]::new(256,256),
    [System.Drawing.Color]::FromArgb(20,105,179),[System.Drawing.Color]::FromArgb(5,15,55))
$teal = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
    [System.Drawing.Point]::new(0,0),[System.Drawing.Point]::new(256,256),
    [System.Drawing.Color]::FromArgb(22,205,240),[System.Drawing.Color]::FromArgb(0,242,182))
$white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245,251,255))
$phone = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(10,40,90))
$dark = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(6,20,48))
$border = New-Object System.Drawing.Pen([System.Drawing.Color]::White,9)
$signal = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(0,239,202),10)
$orbit = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(0,232,217),13)
try {
    $outer = Rounded 1 1 254 254 51
    $g.FillPath($bg,$outer)
    $g.DrawArc($orbit,19,110,226,95,13,160)
    $body = Rounded 73 44 112 163 22
    $g.FillPath($phone,$body)
    $g.DrawPath($border,$body)
    $screen = Rounded 88 75 82 93 15
    $g.FillPath($teal,$screen)
    $lens = Rounded 103 100 44 45 13
    $g.FillPath($white,$lens)
    $triangle = New-Object System.Drawing.Drawing2D.GraphicsPath
    $triangle.AddPolygon([System.Drawing.Point[]]@(
        [System.Drawing.Point]::new(146,111),
        [System.Drawing.Point]::new(165,100),
        [System.Drawing.Point]::new(165,146),
        [System.Drawing.Point]::new(146,134)))
    $g.FillPath($white,$triangle)
    $g.FillEllipse($white,122,180,14,14)
    $g.DrawArc($signal,169,50,48,44,275,75)
    $g.DrawArc($signal,171,27,76,65,275,75)
    $g.Flush()
    $pngStream = New-Object System.IO.MemoryStream
    $bitmap.Save($pngStream,[System.Drawing.Imaging.ImageFormat]::Png)
    $png = $pngStream.ToArray()
    $pngStream.Dispose()
    $dir = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($OutputPath))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $file = [System.IO.File]::Create($OutputPath)
    $writer = New-Object System.IO.BinaryWriter($file)
    try {
        $writer.Write([UInt16]0); $writer.Write([UInt16]1); $writer.Write([UInt16]1)
        $writer.Write([byte]0); $writer.Write([byte]0)
        $writer.Write([byte]0); $writer.Write([byte]0)
        $writer.Write([UInt16]1); $writer.Write([UInt16]32)
        $writer.Write([UInt32]$png.Length); $writer.Write([UInt32]22)
        $writer.Write($png)
    } finally { $writer.Dispose() }
    Write-Host "Icone gerado: $OutputPath"
} finally {
    $g.Dispose(); $bitmap.Dispose()
    $bg.Dispose(); $teal.Dispose(); $white.Dispose(); $phone.Dispose(); $dark.Dispose()
    $border.Dispose(); $signal.Dispose(); $orbit.Dispose()
}
