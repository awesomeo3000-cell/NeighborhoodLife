$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$javac = 'C:\Program Files\Eclipse Adoptium\jdk-25.0.3.9-hotspot\bin\javac.exe'
$jar = 'C:\Program Files\Eclipse Adoptium\jdk-25.0.3.9-hotspot\bin\jar.exe'
$class = Join-Path $root 'tests\HandsFreeQA.class'
$manifest = Join-Path $root 'tests\hands-free-qa-manifest.mf'
$output = Join-Path $root 'tests\hands-free-qa.jar'

& $javac -d (Join-Path $root 'tests') (Join-Path $root 'tests\HandsFreeQA.java')
if ($LASTEXITCODE -ne 0) { throw "javac failed with exit $LASTEXITCODE" }
@'
Manifest-Version: 1.0
Premain-Class: HandsFreeQA
Created-By: 25.0.3 (Eclipse Adoptium)

'@ | Set-Content $manifest -NoNewline
& $jar cfm $output $manifest -C (Join-Path $root 'tests') HandsFreeQA.class
if ($LASTEXITCODE -ne 0) { throw "jar failed with exit $LASTEXITCODE" }
[System.IO.File]::Delete($class)
[System.IO.File]::Delete($manifest)
Write-Output "PASS: hands-free QA agent built at $output"
