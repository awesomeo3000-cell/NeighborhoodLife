param(
    [string]$SourceRoot,
    [string]$DestinationRoot
)

if (-not $SourceRoot) { $SourceRoot = Join-Path $PSScriptRoot '..\NeighborhoodLife' }
if (-not $DestinationRoot) { $DestinationRoot = Join-Path $env:USERPROFILE 'Zomboid\mods\NeighborhoodLife' }

$source = (Resolve-Path -LiteralPath $SourceRoot -ErrorAction Stop).Path
$destination = [System.IO.Path]::GetFullPath($DestinationRoot)
$modsRoot = [System.IO.Path]::GetFullPath((Join-Path $env:USERPROFILE 'Zomboid\mods'))
$destinationParent = [System.IO.Path]::GetFullPath((Split-Path -Parent $destination))

if ($destinationParent.TrimEnd('\') -ine $modsRoot.TrimEnd('\') -or
        ([System.IO.Path]::GetFileName($destination) -ine 'NeighborhoodLife')) {
    throw "Destination must be the explicit production mod folder under $modsRoot"
}
if ([System.IO.Path]::GetFullPath($source).TrimEnd('\') -ieq $destination.TrimEnd('\')) {
    throw 'Source and destination must be different paths'
}

New-Item -ItemType Directory -Force -Path $modsRoot | Out-Null
$staging = Join-Path $modsRoot ('.NeighborhoodLife-install-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Force -Path $staging | Out-Null
    Get-ChildItem -LiteralPath $source -Force | Copy-Item -Destination $staging -Recurse -Force

    $forbidden = Get-ChildItem -LiteralPath $staging -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\(NeighborhoodQA|tests|test-profile[^\\]*)\\' }
    if ($forbidden) {
        throw 'Production staging contains QA or test files'
    }

    if (Test-Path -LiteralPath $destination) {
        Remove-Item -LiteralPath $destination -Recurse -Force
    }
    Move-Item -LiteralPath $staging -Destination $destination
    $staging = $null
}
finally {
    if ($staging -and (Test-Path -LiteralPath $staging)) {
        Remove-Item -LiteralPath $staging -Recurse -Force
    }
}

$files = @(Get-ChildItem -LiteralPath $destination -Recurse -File)
$manifest = Join-Path $destination '42\mod.info'
if (-not (Test-Path -LiteralPath $manifest)) {
    throw "Installed production mod is missing $manifest"
}
Write-Output "PASS: installed production NeighborhoodLife mod"
Write-Output "SOURCE=$source"
Write-Output "DESTINATION=$destination"
Write-Output "FILES=$($files.Count)"
Write-Output "QA_FILES=0"
