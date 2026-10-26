param([string]$Out = (Join-Path (Split-Path $PSScriptRoot) "theme\hnh_logo_white.png"), [int]$Width = 600,
      [double]$Padding = 0.02)
# Make the report's header logo from the brand file branding\<Arabic name>-08.png (white mark and wordmark on
# transparent, 4500 x 4500 with wide transparent margins): crop to the non-transparent bounding box plus $Padding
# (2 % of the box's larger side) on every side, scale to $Width px wide (high-quality bicubic), save as PNG.
# Reads only branding\, writes only $Out. Windows PowerShell 5.1 with System.Drawing; the script stays ASCII, the
# source is found by its "-08.png" suffix, and every path goes through -LiteralPath / [IO.File] (Arabic file name).
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class HnhAlphaBox {
    // [left, top, right, bottom] (inclusive) of the pixels with alpha > 0, or null when there are none.
    public static int[] Find(Bitmap bmp) {
        var rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
        var data = bmp.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try {
            var row = new byte[data.Stride];
            int l = bmp.Width, t = bmp.Height, r = -1, b = -1;
            for (int y = 0; y < bmp.Height; y++) {
                Marshal.Copy(IntPtr.Add(data.Scan0, y * data.Stride), row, 0, data.Stride);
                for (int x = 0; x < bmp.Width; x++) {
                    if (row[x * 4 + 3] == 0) continue;
                    if (x < l) l = x;
                    if (x > r) r = x;
                    if (y < t) t = y;
                    b = y;
                }
            }
            return r < 0 ? null : new int[] { l, t, r, b };
        } finally {
            bmp.UnlockBits(data);
        }
    }
}
"@

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..\..")).Path
$found = @(Get-ChildItem -LiteralPath (Join-Path $repo "branding") -File | Where-Object { $_.Name -like "*-08.png" })
if ($found.Count -ne 1) { throw "expected one branding\*-08.png, found $($found.Count)" }
$bytes = [IO.File]::ReadAllBytes($found[0].FullName)
$stream = New-Object IO.MemoryStream(, $bytes)
$src = New-Object Drawing.Bitmap($stream)
try {
    $box = [HnhAlphaBox]::Find($src)
    if ($null -eq $box) { throw "$($found[0].Name) has no visible pixel" }
    $bw = $box[2] - $box[0] + 1
    $bh = $box[3] - $box[1] + 1
    $pad = [int][Math]::Ceiling($Padding * [Math]::Max($bw, $bh))
    $cw = $bw + 2 * $pad  # the padding is transparent canvas around the box, so it stays even at the image edge
    $ch = $bh + 2 * $pad
    $scale = $Width / $cw
    $height = [int][Math]::Round($ch * $scale)
    $dst = New-Object Drawing.Bitmap($Width, $height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $g = [Drawing.Graphics]::FromImage($dst)
        $g.Clear([Drawing.Color]::Transparent)
        $g.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
        $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
        $inner = New-Object Drawing.RectangleF([single]($pad * $scale), [single]($pad * $scale),
                                               [single]($bw * $scale), [single]($bh * $scale))
        $g.DrawImage($src, $inner, (New-Object Drawing.RectangleF($box[0], $box[1], $bw, $bh)),
                     [Drawing.GraphicsUnit]::Pixel)
        $g.Dispose()
        $ms = New-Object IO.MemoryStream
        $dst.Save($ms, [Drawing.Imaging.ImageFormat]::Png)
        [IO.File]::WriteAllBytes($Out, $ms.ToArray())
    } finally {
        $dst.Dispose()
    }
    "content box ($($box[0]), $($box[1])) - ($($box[2]), $($box[3])); padding $pad px; wrote $Out ($Width x $height)"
} finally {
    $src.Dispose()
    $stream.Dispose()
}
