param(
    [string]$ProfileRoot = 'E:\pzmod\test-profile-v99f-promotion',
    [string]$EvidenceRoot = 'E:\pzmod\evidence\v99\actual\promotion'
)

$ErrorActionPreference = 'Stop'
$root = 'E:\pzmod'
$base = [System.IO.Path]::GetFullPath($ProfileRoot)
$evidence = [System.IO.Path]::GetFullPath($EvidenceRoot)
$serverProfile = Join-Path $base 'mp-server'
$hostProfile = Join-Path $base 'mp-host'
$guestProfile = Join-Path $base 'mp-guest'
New-Item -ItemType Directory -Force $evidence | Out-Null

function Get-IsolatedProcesses {
    @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -in @('java.exe', 'javaw.exe') -and
            $_.CommandLine -and $_.CommandLine -like "*$base*"
    })
}

function Stop-IsolatedProcesses {
    foreach ($process in (Get-IsolatedProcesses)) {
        Stop-Process -Id ([int]$process.ProcessId) -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 3
    if (Get-IsolatedProcesses) { throw "Isolated QA processes remained under $base" }
}

function Wait-LogPattern($path, $pattern, $seconds) {
    $deadline = (Get-Date).AddSeconds($seconds)
    do {
        if ((Test-Path $path) -and
            (Select-String -Path $path -Pattern $pattern -Quiet -ErrorAction SilentlyContinue)) {
            return $true
        }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    return $false
}

Stop-IsolatedProcesses
$launcherLog = Join-Path $evidence 'launcher.stdout.log'
& pwsh -NoProfile -ExecutionPolicy Bypass -File `
    (Join-Path $root 'tools\launch-multiplayer-qa.ps1') `
    -PromotionProbe -ProfileRoot $base -EvidenceRoot $evidence
$launcherExit = $LASTEXITCODE
"QA launcher exit=$launcherExit" | Set-Content $launcherLog
if ($launcherExit -ne 0) { throw "QA launcher failed with exit $launcherExit" }

$hostLog = $null
$hostLogDeadline = (Get-Date).AddSeconds(120)
do {
    $hostLog = Get-ChildItem (Join-Path $hostProfile 'Logs') -Filter '*_DebugLog.txt' -File `
        -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($hostLog) { break }
    Start-Sleep -Seconds 2
} while ((Get-Date) -lt $hostLogDeadline)
if (-not $hostLog) { throw "Host debug log was not found under $hostProfile" }

$resultPattern = 'CAREER PROMOTION RESULT: career=medic rank=2 skill=1 xp=[0-9]+ variety=3'
if (-not (Wait-LogPattern $hostLog.FullName $resultPattern 600)) {
    throw "Actual medic promotion result did not arrive; inspect $($hostLog.FullName)"
}

$serverLog = Join-Path $serverProfile 'server.stdout.log'
$seedPattern = 'NLQA CAREER PROMOTION SEED: item=Base.Bandage amount=8 debugLevelOk=true skill=1'
if (-not (Wait-LogPattern $serverLog $seedPattern 30)) {
    throw "Promotion seed proof did not arrive in $serverLog"
}

$hostMarker = Select-String -Path $hostLog.FullName -Pattern $resultPattern | Select-Object -Last 1
$serverMarker = Select-String -Path $serverLog -Pattern $seedPattern | Select-Object -Last 1
$hostMarker.Line | Set-Content (Join-Path $evidence 'promotion-result.txt')
$serverMarker.Line | Set-Content (Join-Path $evidence 'promotion-seed.txt')
Copy-Item $serverLog (Join-Path $evidence 'server.stdout.log') -Force
Copy-Item $hostLog.FullName (Join-Path $evidence 'host.DebugLog.txt') -Force
$guestLog = Get-ChildItem (Join-Path $guestProfile 'Logs') -Filter '*_DebugLog.txt' -File `
    -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($guestLog) { Copy-Item $guestLog.FullName (Join-Path $evidence 'guest.DebugLog.txt') -Force }
Copy-Item (Join-Path $evidence 'mp-processes.txt') (Join-Path $evidence 'mp-processes.started.txt') `
    -Force -ErrorAction SilentlyContinue

"PASS: actual host-plus-guest medic promotion reached rank 2 through three production deliveries" | `
    Set-Content (Join-Path $evidence 'RESULT.txt')
Write-Output 'PASS: actual host-plus-guest medic promotion reached rank 2 through three production deliveries'

Stop-IsolatedProcesses
