param(
    [string]$ProfileRoot = 'E:\pzmod\test-profile-v117-zombie-modes',
    [string]$EvidenceRoot = 'E:\pzmod\evidence\v117\actual\zombie-modes'
)

$ErrorActionPreference = 'Stop'
$root = 'E:\pzmod'
$base = [System.IO.Path]::GetFullPath($ProfileRoot)
$evidence = [System.IO.Path]::GetFullPath($EvidenceRoot)

function Get-IsolatedProcesses($modeBase) {
    @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -in @('java.exe', 'javaw.exe') -and $_.CommandLine -and
            $_.CommandLine -like "*$modeBase*"
    })
}

function Stop-IsolatedProcesses($modeBase) {
    foreach ($process in (Get-IsolatedProcesses $modeBase)) {
        Stop-Process -Id ([int]$process.ProcessId) -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 3
    if (Get-IsolatedProcesses $modeBase) { throw "Isolated QA processes remained under $modeBase" }
}

function Find-Log($profile, $server) {
    $filter = if ($server) { '*_DebugLog-server.txt' } else { '*_DebugLog.txt' }
    Get-ChildItem (Join-Path $profile 'Logs') -Filter $filter -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Wait-Pattern($path, $pattern, $seconds) {
    $deadline = (Get-Date).AddSeconds($seconds)
    do {
        if ((Test-Path $path) -and
            (Select-String -Path $path -Pattern $pattern -Quiet -ErrorAction SilentlyContinue)) { return $true }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    return $false
}

function Run-Mode($name, [bool]$disabled) {
    $modeBase = Join-Path $base $name
    $modeEvidence = Join-Path $evidence $name
    $serverProfile = Join-Path $modeBase 'mp-server'
    $hostProfile = Join-Path $modeBase 'mp-host'
    $guestProfile = Join-Path $modeBase 'mp-guest'
    New-Item -ItemType Directory -Force $modeEvidence | Out-Null
    Stop-IsolatedProcesses $modeBase

    $launcher = Join-Path $root 'tools\launch-multiplayer-qa.ps1'
    $launcherArgs = @('-NpcMovementProbe', '-ProfileRoot', $modeBase, '-EvidenceRoot', $modeEvidence)
    if ($disabled) { $launcherArgs += '-ZombiesDisabledProbe' }
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $launcher @launcherArgs |
        Tee-Object -FilePath (Join-Path $modeEvidence 'launcher.stdout.log')
    $launcherExit = $LASTEXITCODE
    "LAUNCHER_EXIT=$launcherExit" | Add-Content (Join-Path $modeEvidence 'launcher.stdout.log')
    if ($launcherExit -ne 0) { throw "$name launcher failed with exit $launcherExit" }

    $serverLog = Join-Path $serverProfile 'server.stdout.log'
    $hostLog = $null
    $guestLog = $null
    try {
        $deadline = (Get-Date).AddSeconds(240)
        do {
            $hostLog = Find-Log $hostProfile $false
            $guestLog = Find-Log $guestProfile $false
            $ready = (Test-Path $serverLog) -and $hostLog -and $guestLog `
                -and (Select-String -Path $serverLog -Pattern 'NLQA NPC MOTION SAMPLE:' -Quiet -ErrorAction SilentlyContinue) `
                -and (Select-String -Path $hostLog.FullName -Pattern 'NLQA MP NPC MOTION OBSERVED:' -Quiet -ErrorAction SilentlyContinue) `
                -and (Select-String -Path $guestLog.FullName -Pattern 'NLQA MP NPC MOTION OBSERVED:' -Quiet -ErrorAction SilentlyContinue)
            if ($ready) { break }
            Start-Sleep -Seconds 2
        } while ((Get-Date) -lt $deadline)

        $expectedZombieValue = if ($disabled) { 6 } else { 4 }
        $modePattern = "NLQA ZOMBIE MODE ACTIVE: disabled=" + $disabled.ToString().ToLowerInvariant() `
            + " sandboxZombies=" + $expectedZombieValue
        if (-not (Wait-Pattern $serverLog $modePattern 30)) {
            throw "$name did not report its configured zombie mode"
        }
        if (-not $hostLog -or -not $guestLog) { throw "$name did not produce both client logs" }
        $serverText = Get-Content $serverLog -Raw
        $hostText = Get-Content $hostLog.FullName -Raw
        $guestText = Get-Content $guestLog.FullName -Raw
        if ($disabled) {
            if ($serverText -match 'NLQA NPC PRODUCTION DANGER|NLQA DANGER PROBE:') {
                throw 'zombies-disabled mode produced a danger stimulus or response'
            }
            if ($hostText -notmatch 'NLQA MP DANGER PROBE SKIPPED: mode=zombies-disabled') {
                throw 'zombies-disabled mode did not record the skipped stimulus'
            }
            $modeResult = 'PASS: host-plus-guest NPC movement loop completed with sandbox zombies disabled'
        } else {
            if ($serverText -notmatch 'NLQA DANGER PROBE: ok=true count=[1-9]') {
                throw 'zombies-enabled mode did not create a real server zombie'
            }
            if ($serverText -notmatch 'NLQA NPC PRODUCTION DANGER id=marisol') {
                throw 'zombies-enabled mode did not record authoritative NPC danger handling'
            }
            $modeResult = 'PASS: host-plus-guest NPC movement loop completed with a real enabled-zombie retreat'
        }
        $modeResult | Set-Content (Join-Path $modeEvidence 'RESULT.txt')
        $modeResult
    } finally {
        if (Test-Path $serverLog) { Copy-Item $serverLog (Join-Path $modeEvidence 'server.DebugLog.txt') -Force }
        if ($hostLog) { Copy-Item $hostLog.FullName (Join-Path $modeEvidence 'host.DebugLog.txt') -Force }
        if ($guestLog) { Copy-Item $guestLog.FullName (Join-Path $modeEvidence 'guest.DebugLog.txt') -Force }
        Stop-IsolatedProcesses $modeBase
    }
}

try {
    New-Item -ItemType Directory -Force $evidence | Out-Null
    $disabledResult = Run-Mode 'zombies-disabled' $true
    $enabledResult = Run-Mode 'zombies-enabled' $false
    $result = "PASS: optional-zombie matrix completed`n$disabledResult`n$enabledResult"
    $result | Set-Content (Join-Path $evidence 'RESULT.txt')
    Write-Output $result
} finally {
    Stop-IsolatedProcesses (Join-Path $base 'zombies-disabled')
    Stop-IsolatedProcesses (Join-Path $base 'zombies-enabled')
}
