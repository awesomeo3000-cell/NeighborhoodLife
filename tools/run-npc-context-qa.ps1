param(
    [string]$ProfileRoot = 'E:\pzmod\test-profile-v119d-npc-context',
    [string]$EvidenceRoot = 'E:\pzmod\evidence\v119\actual\direct-npc-context'
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
function Latest-Log($profile, $filter) {
    Get-ChildItem (Join-Path $profile 'Logs') -Filter $filter -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

$passed = $false
$failure = $null
try {
    Stop-IsolatedProcesses
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\launch-multiplayer-qa.ps1') `
        -NpcInteractionProbe -ProfileRoot $base -EvidenceRoot $evidence
    if ($LASTEXITCODE -ne 0) { throw "QA launcher failed with exit $LASTEXITCODE" }

    $serverLog = Join-Path $serverProfile 'server.stdout.log'
    $hostLog = $null
    $guestLog = $null
    $deadline = (Get-Date).AddSeconds(180)
    do {
        $hostLog = Latest-Log $hostProfile '*_DebugLog.txt'
        $guestLog = Latest-Log $guestProfile '*_DebugLog.txt'
        if ($hostLog -and $guestLog) { break }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    if (-not $hostLog -or -not $guestLog) { throw 'Both client debug logs were not found' }

    $checks = @(
        @{ name='HOST_NPC_CONTEXT_CALLBACK'; path=$hostLog.FullName; pattern='NLQA MP NPC CONTEXT CALLBACK: id=marisol action=(introduce|chat)' },
        @{ name='GUEST_NPC_CONTEXT_CALLBACK'; path=$guestLog.FullName; pattern='NLQA MP NPC CONTEXT CALLBACK: id=kenji action=(introduce|chat)' },
        @{ name='HOST_SERVER_SOCIAL_RESULT'; path=$serverLog; pattern='NLQA SOCIAL RESULT: username=nl-host message=' },
        @{ name='GUEST_SERVER_SOCIAL_RESULT'; path=$serverLog; pattern='NLQA SOCIAL RESULT: username=nl-guest message=' }
    )
    foreach ($check in $checks) {
        if (-not (Wait-LogPattern $check.path $check.pattern 240)) {
            throw "$($check.name) did not arrive in $($check.path)"
        }
    }
    $passed = $true
} catch {
    $failure = $_.Exception.Message
    Write-Output "NPC_CONTEXT_FAILURE=$failure"
} finally {
    $serverLog = Join-Path $serverProfile 'server.stdout.log'
    $hostLog = Latest-Log $hostProfile '*_DebugLog.txt'
    $guestLog = Latest-Log $guestProfile '*_DebugLog.txt'
    if (Test-Path $serverLog) { Copy-Item $serverLog (Join-Path $evidence 'server.stdout.log') -Force }
    if ($hostLog) { Copy-Item $hostLog.FullName (Join-Path $evidence 'host.DebugLog.txt') -Force }
    if ($guestLog) { Copy-Item $guestLog.FullName (Join-Path $evidence 'guest.DebugLog.txt') -Force }
    if ($passed) {
        'PASS: actual host-plus-guest direct NPC context callbacks reached server-authoritative social authority' |
            Set-Content (Join-Path $evidence 'RESULT.txt')
        Write-Output 'PASS: actual host-plus-guest direct NPC context callbacks reached server-authoritative social authority'
    } else {
        "RESULT: direct NPC context callback probe incomplete: $failure" |
            Set-Content (Join-Path $evidence 'RESULT.txt')
    }
    Stop-IsolatedProcesses
}
if (-not $passed) { exit 1 }
