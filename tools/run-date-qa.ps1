param(
    [string]$ProfileRoot = 'E:\pzmod\test-profile-v121-date',
    [string]$EvidenceRoot = 'E:\pzmod\evidence\v121\actual\date'
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
function Latest-Log($profile) {
    Get-ChildItem (Join-Path $profile 'Logs') -Filter '*_DebugLog.txt' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

$passed = $false
$failure = $null
$serverLog = Join-Path $serverProfile 'server.stdout.log'
$hostLog = $null
$guestLog = $null
try {
    Stop-IsolatedProcesses
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\launch-multiplayer-qa.ps1') `
        -DateProbe -ProfileRoot $base -EvidenceRoot $evidence
    $launcherExit = $LASTEXITCODE
    "QA launcher exit=$launcherExit" | Set-Content (Join-Path $evidence 'launcher.stdout.log')
    if ($launcherExit -ne 0) { throw "QA launcher failed with exit $launcherExit" }

    $deadline = (Get-Date).AddSeconds(180)
    do {
        $hostLog = Latest-Log $hostProfile
        $guestLog = Latest-Log $guestProfile
        if ($hostLog -and $guestLog) { break }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    if (-not $hostLog -or -not $guestLog) { throw 'Both client debug logs were not found' }

    $checks = @(
        @{ name='HOST_DATE_CALLBACK'; path=$hostLog.FullName; pattern='NLQA MP NPC CONTEXT CALLBACK: id=marisol action=date source=production-menu-callback' },
        @{ name='HOST_DATE_START'; path=$hostLog.FullName; pattern='NLQA MP DATE START SNAPSHOT: status=active dates=1' },
        @{ name='HOST_DATE_ACTIVITY_CALLBACK'; path=$hostLog.FullName; pattern='NLQA MP NPC CONTEXT CALLBACK: id=marisol action=date_activity source=production-menu-callback' },
        @{ name='HOST_DATE_ACTIVITY'; path=$hostLog.FullName; pattern='NLQA MP DATE ACTIVITY SNAPSHOT: status=completed completedDates=1 friendship=44 trust=41' },
        @{ name='HOST_DATE_RESULT'; path=$serverLog; pattern='NLQA SOCIAL RESULT: username=nl-host message=That was lovely\. I feel closer to you already\.' },
        @{ name='GUEST_DATE_EVENT'; path=$guestLog.FullName; pattern='NLQA MP DATE GUEST EVENT: actor=nl-host action=date_activity npc=marisol' }
    )
    foreach ($check in $checks) {
        if (-not (Wait-LogPattern $check.path $check.pattern 240)) {
            throw "$($check.name) did not arrive in $($check.path)"
        }
    }
    $passed = $true
} catch {
    $failure = $_.Exception.Message
    Write-Output "DATE_FAILURE=$failure"
} finally {
    if (Test-Path $serverLog) { Copy-Item $serverLog (Join-Path $evidence 'server.DebugLog.txt') -Force }
    if ($hostLog) { Copy-Item $hostLog.FullName (Join-Path $evidence 'host.DebugLog.txt') -Force }
    if ($guestLog) { Copy-Item $guestLog.FullName (Join-Path $evidence 'guest.DebugLog.txt') -Force }
    if ($passed) {
        'PASS: actual host-plus-guest two-step NPC date activity reached server authority and guest event replication' |
            Set-Content (Join-Path $evidence 'RESULT.txt')
        Write-Output 'PASS: actual host-plus-guest two-step NPC date activity reached server authority and guest event replication'
    } else {
        "RESULT: date activity probe incomplete: $failure" |
            Set-Content (Join-Path $evidence 'RESULT.txt')
    }
    Stop-IsolatedProcesses
}
if (-not $passed) { exit 1 }
