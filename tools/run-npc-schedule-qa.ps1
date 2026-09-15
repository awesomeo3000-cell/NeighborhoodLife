param(
    [string]$ProfileRoot = 'E:\pzmod\test-profile-v139-npc-schedule',
    [string]$EvidenceRoot = 'E:\pzmod\evidence\v139\actual\npc-schedule'
)

$ErrorActionPreference = 'Stop'
$root = 'E:\pzmod'
$base = [System.IO.Path]::GetFullPath($ProfileRoot)
$evidence = [System.IO.Path]::GetFullPath($EvidenceRoot)
$serverProfile = Join-Path $base 'mp-server'
$hostProfile = Join-Path $base 'mp-host'
$guestProfile = Join-Path $base 'mp-guest'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null

function Get-IsolatedProcesses {
    @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -in @('java.exe', 'javaw.exe') -and $_.CommandLine -and
            $_.CommandLine -like "*$base*"
    })
}

function Stop-IsolatedProcesses {
    foreach ($process in (Get-IsolatedProcesses)) {
        Stop-Process -Id ([int]$process.ProcessId) -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 3
    if (Get-IsolatedProcesses) { throw "Isolated QA processes remained under $base" }
}

function Find-Log($profile, $server) {
    $filter = if ($server) { '*_DebugLog-server.txt' } else { '*_DebugLog.txt' }
    Get-ChildItem (Join-Path $profile 'Logs') -Filter $filter -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Wait-Pattern($path, $pattern, $seconds) {
    $deadline = (Get-Date).AddSeconds($seconds)
    do {
        if ($path -and (Test-Path $path) -and
            (Select-String -Path $path -Pattern $pattern -Quiet -ErrorAction SilentlyContinue)) {
            return $true
        }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    return $false
}

$serverLog = $null
$hostLog = $null
$guestLog = $null
try {
    Stop-IsolatedProcesses
    $launcher = Join-Path $root 'tools\launch-multiplayer-qa.ps1'
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $launcher `
        -NpcScheduleProbe -ZombiesDisabledProbe -ProfileRoot $base -EvidenceRoot $evidence
    $launcherExit = $LASTEXITCODE
    "QA launcher exit=$launcherExit" | Set-Content (Join-Path $evidence 'launcher.stdout.log')
    if ($launcherExit -ne 0) { throw "QA launcher failed with exit $launcherExit" }

    $deadline = (Get-Date).AddSeconds(180)
    do {
        $serverLog = Find-Log $serverProfile $true
        $hostLog = Find-Log $hostProfile $false
        $guestLog = Find-Log $guestProfile $false
        $serverReady = $serverLog -and (Select-String -Path $serverLog.FullName -Pattern 'NLQA NPC SCHEDULE RESULT:' -Quiet -ErrorAction SilentlyContinue)
        $hostReady = $hostLog -and (Select-String -Path $hostLog.FullName -Pattern 'NLQA MP NPC SCHEDULE OBSERVED:' -Quiet -ErrorAction SilentlyContinue)
        $guestReady = $guestLog -and (Select-String -Path $guestLog.FullName -Pattern 'NLQA MP NPC SCHEDULE OBSERVED:' -Quiet -ErrorAction SilentlyContinue)
        if ($serverReady -and $hostReady -and $guestReady) { break }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)

    if (-not $serverLog -or -not $hostLog -or -not $guestLog) {
        throw 'One or more actual QA logs were not found'
    }
    $serverResult = Select-String -Path $serverLog.FullName -Pattern 'NLQA NPC SCHEDULE RESULT:' | Select-Object -Last 1
    $hostResult = Select-String -Path $hostLog.FullName -Pattern 'NLQA MP NPC SCHEDULE OBSERVED:' | Select-Object -Last 1
    $guestResult = Select-String -Path $guestLog.FullName -Pattern 'NLQA MP NPC SCHEDULE OBSERVED:' | Select-Object -Last 1
    $homeCount = @(Select-String -Path $serverLog.FullName -Pattern 'NLQA NPC SCHEDULE HOME:').Count
    if (-not $serverResult -or -not $hostResult -or -not $guestResult -or $homeCount -lt 1) {
        throw "NPC schedule evidence incomplete: server=$([bool]$serverResult) home=$homeCount host=$([bool]$hostResult) guest=$([bool]$guestResult)"
    }
    $serverResult.Line | Set-Content (Join-Path $evidence 'server-schedule-result.txt')
    $hostResult.Line | Set-Content (Join-Path $evidence 'host-schedule-result.txt')
    $guestResult.Line | Set-Content (Join-Path $evidence 'guest-schedule-result.txt')
    'PASS: actual host-plus-guest NPC career routine transitioned from home to work' |
        Set-Content (Join-Path $evidence 'RESULT.txt')
    Get-Content (Join-Path $evidence 'RESULT.txt')
}
finally {
    if ($serverLog) { Copy-Item $serverLog.FullName (Join-Path $evidence 'server.DebugLog.txt') -Force }
    if ($hostLog) { Copy-Item $hostLog.FullName (Join-Path $evidence 'host.DebugLog.txt') -Force }
    if ($guestLog) { Copy-Item $guestLog.FullName (Join-Path $evidence 'guest.DebugLog.txt') -Force }
    Stop-IsolatedProcesses
}
