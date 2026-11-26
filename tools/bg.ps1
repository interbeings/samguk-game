param([string]$src, [string]$out, [int]$height = 540, [long]$quality = 84)
# Resize a background to the game height and save as a compact JPEG
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile($src)
$w = [int][Math]::Round($img.Width * $height / $img.Height)
$bmp = New-Object System.Drawing.Bitmap $w, $height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'
$g.DrawImage($img, 0, 0, $w, $height)
$enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), $quality
$bmp.Save($out, $enc, $ep)
$g.Dispose(); $bmp.Dispose(); $img.Dispose()
"$out ${w}x$height $((Get-Item $out).Length) bytes"
