param(
    [string]$ProfileRoot = 'E:\pzmod\test-profile-v100-native-roster',
    [string]$EvidenceRoot = 'E:\pzmod\evidence\v100\actual\native-roster'
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

Stop-IsolatedProcesses
& pwsh -NoProfile -ExecutionPolicy Bypass -File `
    (Join-Path $root 'tools\launch-multiplayer-qa.ps1') `
    -NativeRosterProbe -ProfileRoot $base -EvidenceRoot $evidence
$launcherExit = $LASTEXITCODE
"QA launcher exit=$launcherExit" | Set-Content (Join-Path $evidence 'launcher.stdout.log')
if ($launcherExit -ne 0) { throw "QA launcher failed with exit $launcherExit" }

$serverDebug = $null
$deadline = (Get-Date).AddSeconds(120)
do {
    $serverDebug = Get-ChildItem (Join-Path $serverProfile 'Logs') -Filter '*_DebugLog-server.txt' `
        -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($serverDebug) { break }
    Start-Sleep -Seconds 2
} while ((Get-Date) -lt $deadline)
if (-not $serverDebug) { throw "Server debug log was not found under $serverProfile" }
if (-not (Wait-LogPattern $serverDebug.FullName 'NLQA NATIVE ROSTER PROBE: before=' 180)) {
    throw "Native roster probe did not execute; inspect $($serverDebug.FullName)"
}

# Let both clients receive the ordinary authoritative presence packet before
# deciding the client-side bridge result. The server-side roster experiment
# mutates only a fresh getOnlinePlayers() copy and must not suppress the
# compatibility stream used by this separate observation.
$hostLog = $null
$guestLog = $null
$clientDeadline = (Get-Date).AddSeconds(120)
do {
    $hostLog = Get-ChildItem (Join-Path $hostProfile 'Logs') -Filter '*_DebugLog.txt' -File `
        -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $guestLog = Get-ChildItem (Join-Path $guestProfile 'Logs') -Filter '*_DebugLog.txt' -File `
        -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $hostProbe = $hostLog -and (Select-String -Path $hostLog.FullName -Pattern 'NLQA MP NATIVE CLIENT ROSTER PROBE:' -Quiet)
    $guestProbe = $guestLog -and (Select-String -Path $guestLog.FullName -Pattern 'NLQA MP NATIVE CLIENT ROSTER PROBE:' -Quiet)
    if ($hostProbe -or $guestProbe) { break }
    Start-Sleep -Seconds 2
} while ((Get-Date) -lt $clientDeadline)

Copy-Item (Join-Path $serverProfile 'server.stdout.log') (Join-Path $evidence 'server.stdout.log') -Force
Copy-Item $serverDebug.FullName (Join-Path $evidence 'server.DebugLog.txt') -Force
if ($hostLog) { Copy-Item $hostLog.FullName (Join-Path $evidence 'host.DebugLog.txt') -Force }
if ($guestLog) { Copy-Item $guestLog.FullName (Join-Path $evidence 'guest.DebugLog.txt') -Force }
$bridgeResult = Select-String -Path $serverDebug.FullName -Pattern 'NLQA NATIVE BRIDGE PROBE:' |
    Select-Object -Last 1
if ($bridgeResult) { $bridgeResult.Line | Set-Content (Join-Path $evidence 'server-bridge-result.txt') }

$nativePattern = 'NATIVE ROSTER RESULT: count=[1-9][0-9]* entries=.*source=engine-online-players'
$hostNative = $hostLog -and (Select-String -Path $hostLog.FullName -Pattern $nativePattern -Quiet)
$guestNative = $guestLog -and (Select-String -Path $guestLog.FullName -Pattern $nativePattern -Quiet)
$serverResult = Select-String -Path $serverDebug.FullName -Pattern 'NLQA NATIVE ROSTER PROBE:' | Select-Object -Last 1
$serverResult.Line | Set-Content (Join-Path $evidence 'server-roster-result.txt')
$clientRoster = @()
if ($hostLog) {
    $clientRoster += Select-String -Path $hostLog.FullName -Pattern 'NLQA MP NATIVE CLIENT ROSTER PROBE:'
}
if ($guestLog) {
    $clientRoster += Select-String -Path $guestLog.FullName -Pattern 'NLQA MP NATIVE CLIENT ROSTER PROBE:'
}
if ($clientRoster.Count -gt 0) {
    $clientRoster | ForEach-Object { $_.Line } | Set-Content (Join-Path $evidence 'client-roster-result.txt')
}
$clientBridgeUnavailable = @($clientRoster | Where-Object { $_.Line -like '*status=GameClient-unavailable*' }).Count -gt 0
if ($hostNative -or $guestNative) {
    $result = 'PASS: engine-native NPC body reached a client online-player roster'
} elseif ($clientRoster.Count -gt 0 -and -not $clientBridgeUnavailable) {
    $result = 'RESULT: client-native roster bridge accepted a QA-local compatibility replica; server native replication remains unproven'
} elseif ($clientBridgeUnavailable) {
    $result = 'RESULT: client GameClient roster bridge is not exposed to Lua; server native replication remains unproven'
} else {
    $result = 'RESULT: online-player roster mutation did not produce an engine-native NPC client body'
}
$result | Set-Content (Join-Path $evidence 'RESULT.txt')
Write-Output $result
Stop-IsolatedProcesses
