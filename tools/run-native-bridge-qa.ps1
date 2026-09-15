param(
    [string]$ProfileRoot = 'E:\pzmod\test-profile-v140-native-bridge',
    [string]$EvidenceRoot = 'E:\pzmod\evidence\v140\actual\native-bridge'
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
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\build-hands-free-qa.ps1') |
        Set-Content (Join-Path $evidence 'bridge-agent-build.log')
    if ($LASTEXITCODE -ne 0) { throw "QA agent build failed with exit $LASTEXITCODE" }

    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\launch-multiplayer-qa.ps1') `
        -NativeRosterProbe -NativeBridgeProbe -NpcMovementProbe -ZombiesDisabledProbe `
        -ProfileRoot $base -EvidenceRoot $evidence
    $launcherExit = $LASTEXITCODE
    "QA launcher exit=$launcherExit" | Set-Content (Join-Path $evidence 'launcher.stdout.log')
    if ($launcherExit -ne 0) { throw "QA launcher failed with exit $launcherExit" }

    $deadline = (Get-Date).AddSeconds(180)
    do {
        $serverLog = Find-Log $serverProfile $true
        $hostLog = Find-Log $hostProfile $false
        $guestLog = Find-Log $guestProfile $false
        $serverReady = $serverLog -and
            (Select-String -Path $serverLog.FullName -Pattern 'NLQA NATIVE TYPED BRIDGE:.*result=True' -Quiet -ErrorAction SilentlyContinue)
        $typedRoute = $serverLog -and
            (Select-String -Path $serverLog.FullName -Pattern 'NLQA NPC PRODUCTION REANNOUNCE source=typed sent=3' -Quiet -ErrorAction SilentlyContinue)
        $hostNative = $hostLog -and
            (Select-String -Path $hostLog.FullName -Pattern 'NLQA MP NATIVE ROSTER RESULT: count=[1-9][0-9]* entries=.*source=engine-online-players' -Quiet -ErrorAction SilentlyContinue)
        $guestNative = $guestLog -and
            (Select-String -Path $guestLog.FullName -Pattern 'NLQA MP NATIVE ROSTER RESULT: count=[1-9][0-9]* entries=.*source=engine-online-players' -Quiet -ErrorAction SilentlyContinue)
        $hostMotion = $hostLog -and
            (Select-String -Path $hostLog.FullName -Pattern 'NLQA MP NPC MOTION OBSERVED:.*mode=native' -Quiet -ErrorAction SilentlyContinue)
        $guestMotion = $guestLog -and
            (Select-String -Path $guestLog.FullName -Pattern 'NLQA MP NPC MOTION OBSERVED:.*mode=native' -Quiet -ErrorAction SilentlyContinue)
        if ($serverReady -and $typedRoute -and $hostNative -and $guestNative -and $hostMotion -and $guestMotion) { break }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)

    if (-not $serverLog -or -not $hostLog -or -not $guestLog) {
        throw 'One or more actual typed-bridge logs were not found'
    }
    $serverBridge = Select-String -Path $serverLog.FullName -Pattern 'NLQA NATIVE TYPED BRIDGE:' | Select-Object -Last 1
    $serverRoute = Select-String -Path $serverLog.FullName -Pattern 'NLQA NPC PRODUCTION REANNOUNCE source=typed' | Select-Object -Last 1
    $hostResult = Select-String -Path $hostLog.FullName -Pattern 'NLQA MP NATIVE ROSTER RESULT:' | Select-Object -Last 1
    $guestResult = Select-String -Path $guestLog.FullName -Pattern 'NLQA MP NATIVE ROSTER RESULT:' | Select-Object -Last 1
    $hostMotionResult = Select-String -Path $hostLog.FullName -Pattern 'NLQA MP NPC MOTION OBSERVED:' | Select-Object -Last 1
    $guestMotionResult = Select-String -Path $guestLog.FullName -Pattern 'NLQA MP NPC MOTION OBSERVED:' | Select-Object -Last 1
    if ($serverBridge) { $serverBridge.Line | Set-Content (Join-Path $evidence 'server-bridge-result.txt') }
    if ($serverRoute) { $serverRoute.Line | Set-Content (Join-Path $evidence 'server-route-result.txt') }
    if ($hostResult) { $hostResult.Line | Set-Content (Join-Path $evidence 'host-native-result.txt') }
    if ($guestResult) { $guestResult.Line | Set-Content (Join-Path $evidence 'guest-native-result.txt') }
    if ($hostMotionResult) { $hostMotionResult.Line | Set-Content (Join-Path $evidence 'host-motion-result.txt') }
    if ($guestMotionResult) { $guestMotionResult.Line | Set-Content (Join-Path $evidence 'guest-motion-result.txt') }
    if (-not $serverReady -or -not $typedRoute -or -not $hostNative -or -not $guestNative -or -not $hostMotion -or -not $guestMotion) {
        throw "Typed bridge evidence incomplete: server=$serverReady route=$typedRoute hostNative=$hostNative guestNative=$guestNative hostMotion=$hostMotion guestMotion=$guestMotion"
    }
    'PASS: typed server bridge reannounced native NPC bodies to both multiplayer clients' |
        Set-Content (Join-Path $evidence 'RESULT.txt')
    Get-Content (Join-Path $evidence 'RESULT.txt')
}
finally {
    if ($serverLog) { Copy-Item $serverLog.FullName (Join-Path $evidence 'server.DebugLog.txt') -Force }
    if ($hostLog) { Copy-Item $hostLog.FullName (Join-Path $evidence 'host.DebugLog.txt') -Force }
    if ($guestLog) { Copy-Item $guestLog.FullName (Join-Path $evidence 'guest.DebugLog.txt') -Force }
    $agentLog = Join-Path $serverProfile 'native-bridge-qa.log'
    if (Test-Path $agentLog) { Copy-Item $agentLog (Join-Path $evidence 'native-bridge-agent.log') -Force }
    Stop-IsolatedProcesses
}
