param(
    [string]$ProfileRoot = 'E:\pzmod\test-profile-v122-date-persistence',
    [string]$EvidenceRoot = 'E:\pzmod\evidence\v122\actual\date-persistence'
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
function Wait-LogPatternAfter($path, $pattern, $offset, $seconds) {
    $deadline = (Get-Date).AddSeconds($seconds)
    do {
        if ((Get-Item $path).Length -gt $offset) {
            $stream = [System.IO.File]::Open($path, [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            try {
                $stream.Seek($offset, [System.IO.SeekOrigin]::Begin) | Out-Null
                $reader = New-Object System.IO.StreamReader($stream)
                $text = $reader.ReadToEnd()
                $reader.Dispose()
            } finally { $stream.Dispose() }
            if ($text -match $pattern) { return $true }
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
    & pwsh -NoProfile -ExecutionPolicy Bypass -File `
        (Join-Path $root 'tools\launch-multiplayer-qa.ps1') `
        -DateProbe -ProfileRoot $base -EvidenceRoot $evidence
    $launchExit = $LASTEXITCODE
    "QA launcher exit=$launchExit" | Set-Content (Join-Path $evidence 'launcher.stdout.log')
    if ($launchExit -ne 0) { throw "QA launcher failed with exit $launchExit" }

    $deadline = (Get-Date).AddSeconds(180)
    do {
        $hostLog = Latest-Log $hostProfile
        $guestLog = Latest-Log $guestProfile
        if ($hostLog -and $guestLog) { break }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    if (-not $hostLog -or -not $guestLog) { throw 'Both client debug logs were not found' }
    if (-not (Wait-LogPattern $hostLog.FullName 'NLQA MP DATE ACTIVITY SNAPSHOT: status=completed completedDates=1' 240)) {
        throw "Initial completed date was not observed; inspect $($hostLog.FullName)"
    }
    $serverLogOffset = (Get-Item $serverLog).Length
    if (-not (Wait-LogPatternAfter $serverLog 'Saving GlobalModData' $serverLogOffset 180)) {
        throw "Dedicated server did not complete a post-date world save; inspect $serverLog"
    }
    Copy-Item $hostLog.FullName (Join-Path $evidence 'host-before-restart.DebugLog.txt') -Force
    Copy-Item $guestLog.FullName (Join-Path $evidence 'guest-before-restart.DebugLog.txt') -Force
    Copy-Item $serverLog (Join-Path $evidence 'server-before-restart.DebugLog.txt') -Force

    $restartStdout = Join-Path $evidence 'restart.stdout.log'
    $restartStderr = Join-Path $evidence 'restart.stderr.log'
    Set-Content $restartStdout ''
    Set-Content $restartStderr ''
    $restartProcess = Start-Process 'pwsh' -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
        (Join-Path $root 'tools\restart-multiplayer-qa.ps1'),
        '-VerifyDatePersistence', '-ProfileRoot', $base, '-EvidenceRoot', $evidence
    ) -WorkingDirectory $root -RedirectStandardOutput $restartStdout `
        -RedirectStandardError $restartStderr -Wait -PassThru
    $restartExit = $restartProcess.ExitCode
    $restartOutput = Get-Content $restartStdout -Raw -ErrorAction SilentlyContinue
    if ($restartExit -ne 0) { throw "QA restart verification failed with exit $restartExit" }
    $passed = $true
} catch {
    $failure = $_.Exception.Message
    Write-Output "DATE_PERSISTENCE_FAILURE=$failure"
} finally {
    if (Test-Path $serverLog) { Copy-Item $serverLog (Join-Path $evidence 'server.DebugLog.txt') -Force }
    $restartLog = Join-Path $serverProfile 'server.restart.stdout.log'
    if (Test-Path $restartLog) { Copy-Item $restartLog (Join-Path $evidence 'server.restart.DebugLog.txt') -Force }
    $hostLog = Latest-Log $hostProfile
    $guestLog = Latest-Log $guestProfile
    if ($hostLog) { Copy-Item $hostLog.FullName (Join-Path $evidence 'host.DebugLog.txt') -Force }
    if ($guestLog) { Copy-Item $guestLog.FullName (Join-Path $evidence 'guest.DebugLog.txt') -Force }
    if ($passed) {
        'PASS: actual dedicated server loaded completed NPC date with fresh host and guest connected' |
            Set-Content (Join-Path $evidence 'RESULT.txt')
        Write-Output 'PASS: actual dedicated server loaded completed NPC date with fresh host and guest connected'
    } else {
        "RESULT: date persistence probe incomplete: $failure" |
            Set-Content (Join-Path $evidence 'RESULT.txt')
    }
    Stop-IsolatedProcesses
}
if (-not $passed) { exit 1 }
