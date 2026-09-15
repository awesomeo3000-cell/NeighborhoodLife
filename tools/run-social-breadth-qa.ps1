param(
    [string]$ProfileRoot = 'E:\pzmod\test-profile-v138-social-breadth',
    [string]$EvidenceRoot = 'E:\pzmod\evidence\v138\actual\social-breadth'
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

$command = "Set-Location '$root'; & pwsh -NoProfile -ExecutionPolicy Bypass -File '$root\tools\run-social-breadth-qa.ps1' -ProfileRoot '$base' -EvidenceRoot '$evidence'"
$command | Set-Content (Join-Path $evidence 'COMMAND.txt')

try {
    Stop-IsolatedProcesses
    & pwsh -NoProfile -ExecutionPolicy Bypass -File `
        (Join-Path $root 'tools\launch-multiplayer-qa.ps1') `
        -SocialBreadthProbe -ProfileRoot $base -EvidenceRoot $evidence
    $launcherExit = $LASTEXITCODE
    "QA launcher exit=$launcherExit" | Set-Content (Join-Path $evidence 'launcher.stdout.log')
    if ($launcherExit -ne 0) { throw "QA launcher failed with exit $launcherExit" }

    $serverLog = Join-Path $serverProfile 'server.stdout.log'
    $serverPattern = 'NLQA SOCIAL BREADTH SEED: target=marisol met=true friendship=18 trust=8'
    if (-not (Wait-LogPattern $serverLog $serverPattern 180)) {
        throw "Social breadth seed did not arrive; inspect $serverLog"
    }

    $hostLog = $null
    $guestLog = $null
    $deadline = (Get-Date).AddSeconds(120)
    do {
        $hostLog = Get-ChildItem (Join-Path $hostProfile 'Logs') -Filter '*_DebugLog.txt' -File `
            -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        $guestLog = Get-ChildItem (Join-Path $guestProfile 'Logs') -Filter '*_DebugLog.txt' -File `
            -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($hostLog -and $guestLog) { break }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    if (-not $hostLog -or -not $guestLog) { throw 'Both client debug logs were not found' }

    $hostPattern = 'SOCIAL BREADTH HOST RESULT: target=marisol workTalks=1 homeTalks=1 compliments=1'
    $guestPattern = 'SOCIAL BREADTH GUEST EVENTS: actor=nl-host actions=ask_work,talk_home,compliment count=3'
    if (-not (Wait-LogPattern $hostLog.FullName $hostPattern 900)) {
        throw 'Host richer social result did not arrive'
    }
    if (-not (Wait-LogPattern $guestLog.FullName $guestPattern 300)) {
        throw 'Guest richer social event replication did not arrive'
    }

    Copy-Item $serverLog (Join-Path $evidence 'server.stdout.log') -Force
    Copy-Item $hostLog.FullName (Join-Path $evidence 'host.DebugLog.txt') -Force
    Copy-Item $guestLog.FullName (Join-Path $evidence 'guest.DebugLog.txt') -Force
    Select-String -Path $serverLog -Pattern $serverPattern | Select-Object -Last 1 | ForEach-Object Line |
        Set-Content (Join-Path $evidence 'server-social-breadth-seed.txt')
    Select-String -Path $hostLog.FullName -Pattern 'SOCIAL BREADTH (PREPARED|ACTION|STEP|HOST RESULT)' |
        ForEach-Object Line | Set-Content (Join-Path $evidence 'host-social-breadth-result.txt')
    Select-String -Path $guestLog.FullName -Pattern $guestPattern |
        Select-Object -Last 1 | ForEach-Object Line |
        Set-Content (Join-Path $evidence 'guest-social-breadth-result.txt')
    "PASS: actual host-plus-guest richer social action loop completed" |
        Set-Content (Join-Path $evidence 'RESULT.txt')
    Write-Output 'PASS: actual host-plus-guest richer social action loop completed'
}
finally {
    Stop-IsolatedProcesses
}
