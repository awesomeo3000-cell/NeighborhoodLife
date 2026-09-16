param(
    [string]$ProfileRoot = 'E:\pzmod\test-profile-v141-native-persistence',
    [string]$EvidenceRoot = 'E:\pzmod\evidence\v141\actual\native-persistence'
)

$ErrorActionPreference = 'Stop'
$root = 'E:\pzmod'
$game = 'E:\SteamLibrary\steamapps\common\ProjectZomboid'
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
        if ($path -and (Test-Path -LiteralPath $path) -and
            (Select-String -Path $path -Pattern $pattern -Quiet -ErrorAction SilentlyContinue)) {
            return $true
        }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    return $false
}

function Wait-PatternAfter($path, $pattern, $offset, $seconds) {
    $deadline = (Get-Date).AddSeconds($seconds)
    do {
        if ((Test-Path -LiteralPath $path) -and (Get-Item -LiteralPath $path).Length -gt $offset) {
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

function Start-NativeServer($stdout, $stderr) {
    $java = Join-Path $game 'jre64\bin\java.exe'
    $agentArg = "-javaagent:E:/pzmod/tests/native-bridge-qa.jar=$serverProfile"
    $cacheArg = "-cachedir=$serverProfile"
    $args = @($agentArg,
        '-Ddebug=true','--enable-native-access=ALL-UNNAMED',
        '--add-exports=java.base/jdk.internal.misc=ALL-UNNAMED','-Xmx2048m',
        '-Dzomboid.steam=0','-Djava.library.path=./win64/;./','-cp','projectzomboid.jar',
        'zombie.network.GameServer','-servername','servertest',$cacheArg,
        '-adminusername','admin','-adminpassword','qa-admin-password','-nosteam')
    Set-Content -LiteralPath $stdout ''
    Set-Content -LiteralPath $stderr ''
    Start-Process $java -ArgumentList $args -WorkingDirectory $game `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
}

function Start-NativeClient($ClientProfile, $stdout, $stderr) {
    $javaw = Join-Path $game 'jre64\bin\javaw.exe'
    $agentArg = "-javaagent:E:/pzmod/tests/hands-free-qa.jar=$ClientProfile"
    $cacheArg = "-cachedir=$ClientProfile"
    $args = @('-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED',
        '--add-exports=java.base/jdk.internal.misc=ALL-UNNAMED','-Xmx2048m',
        '-Dzomboid.steam=0','-Djava.library.path=./win64/;./','-cp','projectzomboid.jar',
        $agentArg,
        'zombie.gameStates.MainScreenState',$cacheArg,'-nosteam','-nosound')
    Set-Content -LiteralPath $stdout ''
    Set-Content -LiteralPath $stderr ''
    Start-Process $javaw -ArgumentList $args -WorkingDirectory $game `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
}

$serverLog = $null
$hostLog = $null
$guestLog = $null
$restartServerLog = $null
$passed = $false
$failure = $null
try {
    Stop-IsolatedProcesses
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\build-hands-free-qa.ps1') |
        Set-Content (Join-Path $evidence 'bridge-agent-build.log')
    if ($LASTEXITCODE -ne 0) { throw "QA agent build failed with exit $LASTEXITCODE" }

    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\launch-multiplayer-qa.ps1') `
        -NativeRosterProbe -NativeBridgeProbe -NpcMovementProbe -ZombiesDisabledProbe `
        -ProfileRoot $base -EvidenceRoot $evidence
    $launchExit = $LASTEXITCODE
    "QA launcher exit=$launchExit" | Set-Content (Join-Path $evidence 'launcher.stdout.log')
    if ($launchExit -ne 0) { throw "QA launcher failed with exit $launchExit" }

    $deadline = (Get-Date).AddSeconds(240)
    do {
        $serverLog = Find-Log $serverProfile $true
        $hostLog = Find-Log $hostProfile $false
        $guestLog = Find-Log $guestProfile $false
        $serverReady = $serverLog -and (Select-String -Path $serverLog.FullName `
            -Pattern 'NLQA NPC PRODUCTION REANNOUNCE source=typed sent=3' -Quiet -ErrorAction SilentlyContinue)
        $hostReady = $hostLog -and (Select-String -Path $hostLog.FullName `
            -Pattern 'NLQA MP NPC MOTION OBSERVED:.*mode=native' -Quiet -ErrorAction SilentlyContinue)
        $guestReady = $guestLog -and (Select-String -Path $guestLog.FullName `
            -Pattern 'NLQA MP NPC MOTION OBSERVED:.*mode=native' -Quiet -ErrorAction SilentlyContinue)
        if ($serverReady -and $hostReady -and $guestReady) { break }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    if (-not $serverLog -or -not $hostLog -or -not $guestLog -or
        -not $serverReady -or -not $hostReady -or -not $guestReady) {
        throw 'Initial native bridge roster/motion evidence was incomplete'
    }

    $saveOffset = (Get-Item -LiteralPath $serverLog.FullName).Length
    if (-not (Wait-PatternAfter $serverLog.FullName 'Saving GlobalModData' $saveOffset 240)) {
        throw "Dedicated server did not reach a real world save; inspect $($serverLog.FullName)"
    }
    $beforeLine = Select-String -Path $serverLog.FullName -Pattern 'NLQA NPC MOTION SAMPLE:.*marisol=' |
        Select-Object -Last 1
    if (-not $beforeLine) { throw 'No authoritative native motion sample was captured before save' }
    $beforeMatch = [regex]::Match($beforeLine.Line,
        'marisol=(?<x>-?[0-9]+\.[0-9]+),(?<y>-?[0-9]+\.[0-9]+)')
    if (-not $beforeMatch.Success) { throw "Could not parse pre-restart motion sample: $($beforeLine.Line)" }
    $beforeX = [double]$beforeMatch.Groups['x'].Value
    $beforeY = [double]$beforeMatch.Groups['y'].Value
    $beforeLine.Line | Set-Content (Join-Path $evidence 'native-before-restart-result.txt')
    Copy-Item $serverLog.FullName (Join-Path $evidence 'server-before-restart.DebugLog.txt') -Force
    Copy-Item $hostLog.FullName (Join-Path $evidence 'host-before-restart.DebugLog.txt') -Force
    Copy-Item $guestLog.FullName (Join-Path $evidence 'guest-before-restart.DebugLog.txt') -Force

    $oldProcesses = @(Get-IsolatedProcesses)
    $oldIds = $oldProcesses | ForEach-Object { "pid=$($_.ProcessId)" }
    $oldIds | Set-Content (Join-Path $evidence 'pre-restart-processes.txt')
    Stop-IsolatedProcesses

    $restartStdout = Join-Path $serverProfile 'native-persistence-restart.stdout.log'
    $restartStderr = Join-Path $serverProfile 'native-persistence-restart.stderr.log'
    $restart = Start-NativeServer $restartStdout $restartStderr
    $restart.Id | Set-Content (Join-Path $evidence 'restart-server.pid')
    if (-not (Wait-Pattern $restartStdout '\*\*\* SERVER STARTED' 180)) {
        throw "Restarted dedicated server did not start; inspect $restartStdout"
    }

    $hostRestartStdout = Join-Path $hostProfile 'native-persistence-restart.stdout.log'
    $hostRestartStderr = Join-Path $hostProfile 'native-persistence-restart.stderr.log'
    $guestRestartStdout = Join-Path $guestProfile 'native-persistence-restart.stdout.log'
    $guestRestartStderr = Join-Path $guestProfile 'native-persistence-restart.stderr.log'
    $hostProcess = Start-NativeClient $hostProfile $hostRestartStdout $hostRestartStderr
    Start-Sleep -Seconds 5
    $guestProcess = Start-NativeClient $guestProfile $guestRestartStdout $guestRestartStderr
    @("host=$($hostProcess.Id)", "guest=$($guestProcess.Id)") |
        Set-Content (Join-Path $evidence 'post-restart-processes.txt')

    $deadline = (Get-Date).AddSeconds(240)
    $restored = $false
    $typed = $false
    do {
        $restartServerLog = Find-Log $serverProfile $true
        $hostLog = Find-Log $hostProfile $false
        $guestLog = Find-Log $guestProfile $false
        $serverSources = @()
        if ($restartServerLog -and (Test-Path $restartServerLog.FullName)) { $serverSources += $restartServerLog.FullName }
        if (Test-Path $restartStdout) { $serverSources += $restartStdout }
        $restored = [bool]($serverSources | Where-Object {
            Select-String -Path $_ -Pattern 'RESTORE id=marisol x=' -Quiet -ErrorAction SilentlyContinue
        })
        $typed = [bool]($serverSources | Where-Object {
            Select-String -Path $_ -Pattern 'NLQA NPC PRODUCTION REANNOUNCE source=typed sent=3' -Quiet -ErrorAction SilentlyContinue
        })
        $hostNative = $hostLog -and (Select-String -Path $hostLog.FullName `
            -Pattern 'NLQA MP NATIVE ROSTER RESULT: count=[1-9][0-9]* entries=.*source=engine-online-players' -Quiet -ErrorAction SilentlyContinue)
        $guestNative = $guestLog -and (Select-String -Path $guestLog.FullName `
            -Pattern 'NLQA MP NATIVE ROSTER RESULT: count=[1-9][0-9]* entries=.*source=engine-online-players' -Quiet -ErrorAction SilentlyContinue)
        if ($restored -and $typed -and $hostNative -and $guestNative) { break }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    if (-not $restored -or -not $typed -or -not $hostNative -or -not $guestNative) {
        throw "Native persistence evidence incomplete: restored=$restored typed=$typed hostNative=$hostNative guestNative=$guestNative"
    }

    $restoreLine = $null
    foreach ($source in $serverSources) {
        $found = Select-String -Path $source -Pattern 'RESTORE id=marisol x=' -ErrorAction SilentlyContinue | Select-Object -Last 1
        if ($found) { $restoreLine = $found; break }
    }
    if (-not $restoreLine) { throw "Could not find restored native position line" }
    $restoreMatch = [regex]::Match($restoreLine.Line,
        'RESTORE id=marisol x=(?<x>-?[0-9]+\.[0-9]+) y=(?<y>-?[0-9]+\.[0-9]+)')
    if (-not $restoreMatch.Success) { throw "Could not parse restored native position: $($restoreLine.Line)" }
    $restoreX = [double]$restoreMatch.Groups['x'].Value
    $restoreY = [double]$restoreMatch.Groups['y'].Value
    $delta = [math]::Sqrt([math]::Pow($restoreX - $beforeX, 2) + [math]::Pow($restoreY - $beforeY, 2))
    $restoreLine.Line | Set-Content (Join-Path $evidence 'native-after-restart-result.txt')
    if ($delta -gt 2.0) {
        throw "Restored native position moved $([math]::Round($delta, 2)) tiles from the saved sample"
    }
    if ($restartServerLog -and (Test-Path $restartServerLog.FullName)) {
        Copy-Item $restartServerLog.FullName (Join-Path $evidence 'server-after-restart.DebugLog.txt') -Force
    }
    if (Test-Path $restartStdout) {
        Copy-Item $restartStdout (Join-Path $evidence 'server-after-restart.stdout.log') -Force
    }
    Copy-Item $hostLog.FullName (Join-Path $evidence 'host-after-restart.DebugLog.txt') -Force
    Copy-Item $guestLog.FullName (Join-Path $evidence 'guest-after-restart.DebugLog.txt') -Force
    "PASS: native NPC position restored across dedicated-server restart delta=$([math]::Round($delta, 2)) before=$beforeX,$beforeY after=$restoreX,$restoreY" |
        Set-Content (Join-Path $evidence 'RESULT.txt')
    Get-Content (Join-Path $evidence 'RESULT.txt')
    $passed = $true
} catch {
    $failure = $_.Exception.Message
    "RESULT: native NPC persistence probe incomplete: $failure" |
        Set-Content (Join-Path $evidence 'RESULT.txt')
    Write-Output $failure
} finally {
    if ($serverLog -and (Test-Path $serverLog.FullName)) { Copy-Item $serverLog.FullName (Join-Path $evidence 'server.DebugLog.txt') -Force }
    if ($hostLog -and (Test-Path $hostLog.FullName)) { Copy-Item $hostLog.FullName (Join-Path $evidence 'host.DebugLog.txt') -Force }
    if ($guestLog -and (Test-Path $guestLog.FullName)) { Copy-Item $guestLog.FullName (Join-Path $evidence 'guest.DebugLog.txt') -Force }
    if ($restartServerLog -and (Test-Path $restartServerLog.FullName)) { Copy-Item $restartServerLog.FullName (Join-Path $evidence 'server.restart.DebugLog.txt') -Force }
    if (Test-Path $restartStdout) { Copy-Item $restartStdout (Join-Path $evidence 'server.restart.stdout.log') -Force }
    $agentLog = Join-Path $serverProfile 'native-bridge-qa.log'
    if (Test-Path -LiteralPath $agentLog) {
        Copy-Item $agentLog (Join-Path $evidence 'native-bridge-agent.log') -Force
    }
    Stop-IsolatedProcesses
}
if (-not $passed) { exit 1 }
