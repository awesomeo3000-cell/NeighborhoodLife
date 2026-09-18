# Generates the original Neighborhood Life thought-bubble textures used by
# NL/ThoughtBubble.lua. The art is drawn from primitives here so the production
# mod ships self-made neutral assets (no Sims or EA art).
param(
    [string]$Destination = (Join-Path (Split-Path -Parent $PSScriptRoot) 'NeighborhoodLife\42\media\textures')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$size = 64
$penColor = [System.Drawing.Color]::FromArgb(255, 45, 55, 65)
$pen = New-Object System.Drawing.Pen($penColor, 2)
$pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

$clouds = @(
    @(20, 31, 15), @(33, 24, 17), @(47, 31, 14), @(27, 42, 11), @(41, 43, 10)
)
$trail = @( @(10, 50, 5), @(4, 55, 3) )

$faceColors = @{
    happy        = @(255, 233, 168)
    romantic     = @(255, 205, 222)
    angry        = @(255, 176, 166)
    irritated    = @(255, 211, 161)
    disinterested = @(221, 227, 232)
    sad          = @(191, 214, 242)
    neutral      = @(230, 238, 245)
}

# $color is (r, g, b, a).
function Fill-Union($graphics, $circles, $offsetX, $offsetY, $inset, $color) {
    $brush = New-Object System.Drawing.SolidBrush(
        [System.Drawing.Color]::FromArgb($color[3], $color[0], $color[1], $color[2]))
    foreach ($circle in $circles) {
        $radius = $circle[2] - $inset
        if ($radius -le 0) { continue }
        $x = $circle[0] - $radius + $offsetX
        $y = $circle[1] - $radius + $offsetY
        $graphics.FillEllipse($brush, $x, $y, $radius * 2, $radius * 2)
    }
    $brush.Dispose()
}

function Draw-Heart($graphics, $cx, $cy, $scale, $color) {
    $brush = New-Object System.Drawing.SolidBrush($color)
    $left = $cx - $scale
    $top = $cy - $scale
    $graphics.FillEllipse($brush, $left, $top, $scale, $scale)
    $graphics.FillEllipse($brush, $cx, $top, $scale, $scale)
    $points = @(
        (New-Object System.Drawing.PointF(($cx - $scale), $cy)),
        (New-Object System.Drawing.PointF(($cx + $scale), $cy)),
        (New-Object System.Drawing.PointF($cx, ($cy + $scale * 1.6)))
    )
    $graphics.FillPolygon($brush, $points)
    $brush.Dispose()
}

function Draw-Eyes($graphics, $left, $right, $y, $radius) {
    $brush = New-Object System.Drawing.SolidBrush($penColor)
    foreach ($x in @($left, $right)) {
        $graphics.FillEllipse($brush, ($x - $radius), ($y - $radius), ($radius * 2), ($radius * 2))
    }
    $brush.Dispose()
}

New-Item -ItemType Directory -Force -Path $Destination | Out-Null

foreach ($mood in $faceColors.Keys) {
    $bitmap = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::Transparent)

    # Soft offset shadow, then the cloud border and fill.
    Fill-Union $graphics $clouds 1 2 0 @(12, 32, 52, 70)
    Fill-Union $graphics $trail 1 2 0 @(12, 32, 52, 70)
    Fill-Union $graphics $clouds 0 0 0 @(150, 170, 190, 255)
    Fill-Union $graphics $trail 0 0 0 @(150, 170, 190, 255)
    Fill-Union $graphics $clouds 0 0 2 @(255, 255, 255, 255)
    Fill-Union $graphics $trail 0 0 2 @(255, 255, 255, 255)

    $face = $faceColors[$mood]
    $faceBrush = New-Object System.Drawing.SolidBrush(
        [System.Drawing.Color]::FromArgb(255, $face[0], $face[1], $face[2]))
    $graphics.FillEllipse($faceBrush, 32 - 12, 30 - 12, 24, 24)
    $faceBrush.Dispose()
    $graphics.DrawEllipse($pen, 32 - 12, 30 - 12, 24, 24)

    switch ($mood) {
        'happy' {
            $graphics.DrawArc($pen, 24, 23, 6, 6, 200, 140)
            $graphics.DrawArc($pen, 34, 23, 6, 6, 200, 140)
            $graphics.DrawArc($pen, 25, 28, 14, 12, 20, 140)
        }
        'romantic' {
            Draw-Heart $graphics 27 27 2.6 ([System.Drawing.Color]::FromArgb(255, 230, 60, 110))
            Draw-Heart $graphics 37 27 2.6 ([System.Drawing.Color]::FromArgb(255, 230, 60, 110))
            $graphics.DrawArc($pen, 26, 29, 12, 10, 20, 140)
        }
        'angry' {
            $graphics.DrawLine($pen, 23, 23, 28, 26)
            $graphics.DrawLine($pen, 41, 23, 36, 26)
            Draw-Eyes $graphics 27 37 31 1.8
            $graphics.DrawArc($pen, 26, 32, 12, 10, 200, 140)
        }
        'irritated' {
            $graphics.DrawLine($pen, 23, 23, 28, 26)
            Draw-Eyes $graphics 27 37 31 1.8
            $graphics.DrawLine($pen, 26, 37, 38, 37)
        }
        'disinterested' {
            Draw-Eyes $graphics 27 37 30 1.8
            $graphics.DrawLine($pen, 23, 28, 29, 28)
            $graphics.DrawLine($pen, 35, 28, 41, 28)
            $graphics.DrawLine($pen, 26, 37, 38, 37)
        }
        'sad' {
            $graphics.DrawLine($pen, 23, 26, 28, 23)
            $graphics.DrawLine($pen, 41, 26, 36, 23)
            Draw-Eyes $graphics 27 37 31 1.8
            $graphics.DrawArc($pen, 26, 32, 12, 10, 200, 140)
        }
        default {
            Draw-Eyes $graphics 27 37 31 1.8
            $graphics.DrawLine($pen, 26, 37, 38, 37)
        }
    }

    $path = Join-Path $Destination ("NL_Thought_{0}.png" -f $mood)
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
    Write-Output ("wrote {0}" -f $path)
}

$pen.Dispose()
Write-Output "PASS: original thought-bubble textures generated in $Destination"
