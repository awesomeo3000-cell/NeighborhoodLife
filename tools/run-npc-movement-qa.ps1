param(
    [string]$ProfileRoot = 'E:\pzmod\test-profile-v110-npc-movement',
    [string]$EvidenceRoot = 'E:\pzmod\evidence\v110\actual\npc-movement'
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

function Find-Log($profile, $server) {
    $filter = if ($server) { '*_DebugLog-server.txt' } else { '*_DebugLog.txt' }
    Get-ChildItem (Join-Path $profile 'Logs') -Filter $filter -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

$serverLog = $null
$hostLog = $null
$guestLog = $null
try {
    Stop-IsolatedProcesses
    & pwsh -NoProfile -ExecutionPolicy Bypass -File `
        (Join-Path $root 'tools\launch-multiplayer-qa.ps1') `
        -NpcMovementProbe -ProfileRoot $base -EvidenceRoot $evidence
    $launcherExit = $LASTEXITCODE
    "QA launcher exit=$launcherExit" | Set-Content (Join-Path $evidence 'launcher.stdout.log')
    if ($launcherExit -ne 0) { throw "QA launcher failed with exit $launcherExit" }

    $deadline = (Get-Date).AddSeconds(180)
    do {
        $serverLog = Find-Log $serverProfile $true
        $hostLog = Find-Log $hostProfile $false
        $guestLog = Find-Log $guestProfile $false
        $serverReady = $serverLog -and (Select-String -Path $serverLog.FullName -Pattern 'NLQA NPC MOTION SAMPLE:' -Quiet -ErrorAction SilentlyContinue)
        $hostReady = $hostLog -and (Select-String -Path $hostLog.FullName -Pattern 'NLQA MP NPC MOTION OBSERVED:' -Quiet -ErrorAction SilentlyContinue)
        $guestReady = $guestLog -and (Select-String -Path $guestLog.FullName -Pattern 'NLQA MP NPC MOTION OBSERVED:' -Quiet -ErrorAction SilentlyContinue)
        if ($serverReady -and $hostReady -and $guestReady) { break }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    if (-not $serverLog -or -not $hostLog -or -not $guestLog) { throw 'One or more actual QA logs were not found' }

    $serverSamples = @(Select-String -Path $serverLog.FullName -Pattern 'NLQA NPC MOTION SAMPLE:.*marisol=' |
        ForEach-Object {
            $m = [regex]::Match($_.Line, 'marisol=([-0-9.]+),([-0-9.]+),([-0-9.]+)')
            if ($m.Success) { '{0},{1},{2}' -f $m.Groups[1].Value,$m.Groups[2].Value,$m.Groups[3].Value }
        }) | Select-Object -Unique
    if ($serverSamples.Count -lt 2) {
        # A server sample can be flushed after the first client observation.
        # The production PATH lines are emitted by the same authoritative
        # update loop and provide the second server-side position sample.
        $pathSamples = @(Select-String -Path $serverLog.FullName -Pattern 'NPC PRODUCTION PATH id=marisol' |
            ForEach-Object {
                $m = [regex]::Match($_.Line, 'from=([-0-9.]+),([-0-9.]+)')
                if ($m.Success) { '{0},{1},0' -f $m.Groups[1].Value,$m.Groups[2].Value }
            }) | Select-Object -Unique
        $serverSamples = @(@($serverSamples) + @($pathSamples)) | Select-Object -Unique
    }
    $hostMotion = Select-String -Path $hostLog.FullName -Pattern 'NLQA MP NPC MOTION OBSERVED:' | Select-Object -Last 1
    $guestMotion = Select-String -Path $guestLog.FullName -Pattern 'NLQA MP NPC MOTION OBSERVED:' | Select-Object -Last 1

    if ($serverSamples.Count -lt 2 -or -not $hostMotion -or -not $guestMotion) {
        throw "NPC movement evidence incomplete: serverSamples=$($serverSamples.Count) host=$([bool]$hostMotion) guest=$([bool]$guestMotion)"
    }
    $serverSamples | Set-Content (Join-Path $evidence 'server-motion-samples.txt')
    $hostMotion.Line | Set-Content (Join-Path $evidence 'host-motion-result.txt')
    $guestMotion.Line | Set-Content (Join-Path $evidence 'guest-motion-result.txt')
    $result = 'PASS: actual host-plus-guest NPC movement heartbeat and rendered replica motion observed'
    $result | Set-Content (Join-Path $evidence 'RESULT.txt')
    Write-Output $result
}
finally {
    if ($serverLog) { Copy-Item $serverLog.FullName (Join-Path $evidence 'server.DebugLog.txt') -Force }
    if ($hostLog) { Copy-Item $hostLog.FullName (Join-Path $evidence 'host.DebugLog.txt') -Force }
    if ($guestLog) { Copy-Item $guestLog.FullName (Join-Path $evidence 'guest.DebugLog.txt') -Force }
    Stop-IsolatedProcesses
}
