$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$game = 'E:\SteamLibrary\steamapps\common\ProjectZomboid'
$javac = 'C:\Program Files\Eclipse Adoptium\jdk-25.0.3.9-hotspot\bin\javac.exe'
$jar = 'C:\Program Files\Eclipse Adoptium\jdk-25.0.3.9-hotspot\bin\jar.exe'
$class = Join-Path $root 'tests\HandsFreeQA.class'
$nativeClass = Join-Path $root 'tests\NativeBridgeQA.class'
$manifest = Join-Path $root 'tests\hands-free-qa-manifest.mf'
$nativeManifest = Join-Path $root 'tests\native-bridge-qa-manifest.mf'
$output = Join-Path $root 'tests\hands-free-qa.jar'
$nativeOutput = Join-Path $root 'tests\native-bridge-qa.jar'

& $javac -cp (Join-Path $game 'projectzomboid.jar') -d (Join-Path $root 'tests') `
    (Join-Path $root 'tests\HandsFreeQA.java') (Join-Path $root 'tests\NativeBridgeQA.java')
if ($LASTEXITCODE -ne 0) { throw "javac failed with exit $LASTEXITCODE" }
@'
Manifest-Version: 1.0
Premain-Class: HandsFreeQA
Created-By: 25.0.3 (Eclipse Adoptium)

'@ | Set-Content $manifest -NoNewline
& $jar cfm $output $manifest -C (Join-Path $root 'tests') HandsFreeQA.class
if ($LASTEXITCODE -ne 0) { throw "jar failed with exit $LASTEXITCODE" }
[System.IO.File]::WriteAllText($nativeManifest, @'
Manifest-Version: 1.0
Premain-Class: NativeBridgeQA
Created-By: 25.0.3 (Eclipse Adoptium)

'@)
& $jar cfm $nativeOutput $nativeManifest -C (Join-Path $root 'tests') NativeBridgeQA.class `
    -C (Join-Path $root 'tests') 'NativeBridgeQA$OnlineIdSetter.class' `
    -C (Join-Path $root 'tests') 'NativeBridgeQA$NpcBridge.class' `
    -C (Join-Path $root 'tests') 'NativeBridgeQA$PositionSync.class'
if ($LASTEXITCODE -ne 0) { throw "native bridge jar failed with exit $LASTEXITCODE" }
[System.IO.File]::Delete($class)
[System.IO.File]::Delete($nativeClass)
[System.IO.File]::Delete((Join-Path $root 'tests\NativeBridgeQA$OnlineIdSetter.class'))
[System.IO.File]::Delete((Join-Path $root 'tests\NativeBridgeQA$NpcBridge.class'))
[System.IO.File]::Delete((Join-Path $root 'tests\NativeBridgeQA$PositionSync.class'))
[System.IO.File]::Delete($manifest)
[System.IO.File]::Delete($nativeManifest)
Write-Output "PASS: hands-free QA agent built at $output"
Write-Output "PASS: typed native bridge QA agent built at $nativeOutput"
