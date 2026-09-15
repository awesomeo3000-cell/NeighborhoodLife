param(
    [switch]$VerifyHouseholdPersistence,
    [switch]$VerifyDatePersistence,
    [string]$ProfileRoot = 'E:\pzmod\test-profile',
    [string]$EvidenceRoot = 'E:\pzmod\evidence\v55'
)
$ErrorActionPreference = 'Stop'
$root = 'E:\pzmod'
$game = 'E:\SteamLibrary\steamapps\common\ProjectZomboid'
$serverProfile = Join-Path ([System.IO.Path]::GetFullPath($ProfileRoot)) 'mp-server'
$hostProfile = Join-Path ([System.IO.Path]::GetFullPath($ProfileRoot)) 'mp-host'
$evidence = [System.IO.Path]::GetFullPath($EvidenceRoot)
New-Item -ItemType Directory -Force $evidence | Out-Null
$serverLog = Join-Path $serverProfile 'server.stdout.log'
$hostLog = Get-ChildItem (Join-Path $hostProfile 'Logs') -Filter '*_DebugLog.txt' -File |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $hostLog) { throw 'Host debug log was not found' }
$guestLog = Get-ChildItem (Join-Path ([System.IO.Path]::GetFullPath($ProfileRoot)) 'mp-guest\Logs') -Filter '*_DebugLog.txt' -File |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

function Wait-LogPattern($path, $pattern, $seconds) {
    $deadline = (Get-Date).AddSeconds($seconds)
    do {
        if (Select-String -Path $path -Pattern $pattern -Quiet -ErrorAction SilentlyContinue) { return $true }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    return $false
}

if ($VerifyHouseholdPersistence -or $VerifyDatePersistence) {
    if ($VerifyDatePersistence) {
        Write-Output 'DATE VERIFY BASELINE: using the existing persisted date in the isolated profile'
    } else {
        Write-Output 'HOUSEHOLD VERIFY BASELINE: using the existing persisted household in the isolated profile'
    }
} elseif (-not (Wait-LogPattern $hostLog.FullName 'NPC INVENTORY REQUEST RESULT' 420)) {
    throw "Initial inventory exchange did not complete; inspect $($hostLog.FullName)"
}
$hostLogOffset = (Get-Item $hostLog.FullName).Length

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

function Wait-ClientLogPatternAfterRestart($profile, $oldPath, $oldOffset, $pattern, $seconds) {
    $deadline = (Get-Date).AddSeconds($seconds)
    do {
        $logs = @(Get-ChildItem (Join-Path $profile 'Logs') -Filter '*_DebugLog.txt' -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending)
        foreach ($log in $logs) {
            $offset = if ($log.FullName -eq $oldPath) { $oldOffset } else { 0 }
            if ($log.Length -le $offset) { continue }
            $stream = [System.IO.File]::Open($log.FullName, [System.IO.FileMode]::Open,
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

$serverProcesses = @(Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -and $_.CommandLine -like '*zombie.network.GameServer*' -and `
        $_.CommandLine -like '*mp-server*'
})
if ($serverProcesses.Count -ne 1) {
    throw "Expected exactly one isolated QA server process, found $($serverProcesses.Count)"
}
$oldPid = [int]$serverProcesses[0].ProcessId
$oldHostLogPath = $hostLog.FullName
$oldHostLogOffset = (Get-Item $hostLog.FullName).Length
$oldGuestLogPath = if ($guestLog) { $guestLog.FullName } else { '' }
$oldGuestLogOffset = if ($guestLog) { (Get-Item $guestLog.FullName).Length } else { 0 }
if ($VerifyDatePersistence) {
    $clientProcesses = @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -eq 'javaw.exe' -and $_.CommandLine -and $_.CommandLine -like "*$hostProfile*"
    })
    $clientProcesses += @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -eq 'javaw.exe' -and $_.CommandLine -and $_.CommandLine -like "*$(Join-Path ([System.IO.Path]::GetFullPath($ProfileRoot)) 'mp-guest')*"
    })
    foreach ($client in ($clientProcesses | Sort-Object ProcessId -Unique)) {
        Stop-Process -Id ([int]$client.ProcessId) -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 3
}
Stop-Process -Id $oldPid -Force
Start-Sleep -Seconds 3
if (Get-Process -Id $oldPid -ErrorAction SilentlyContinue) { throw "Server PID $oldPid did not stop" }
if ($VerifyHouseholdPersistence) {
    $probeConfig = Join-Path $serverProfile 'mods\NeighborhoodQA\42\media\lua\server\NLQAPersistenceConfig.lua'
    Set-Content $probeConfig 'NLQAPreserveHouseholdRestart = true'
}
Set-Content (Join-Path $hostProfile 'reconnect-request') 'restart'

$java = Join-Path $game 'jre64\bin\java.exe'
$args = @('--enable-native-access=ALL-UNNAMED','--add-exports=java.base/jdk.internal.misc=ALL-UNNAMED',
    '-Xmx2048m','-Dzomboid.steam=0','-Djava.library.path=./win64/;./','-cp','projectzomboid.jar',
    'zombie.network.GameServer','-servername','servertest',"-cachedir=$serverProfile",
    '-adminusername','admin','-adminpassword','qa-admin-password','-nosteam','-debug')
$restartStdout = Join-Path $serverProfile 'server.restart.stdout.log'
$restartStderr = Join-Path $serverProfile 'server.restart.stderr.log'
Set-Content $restartStdout ''
Set-Content $restartStderr ''
$server = Start-Process $java -ArgumentList $args -WorkingDirectory $game `
    -RedirectStandardOutput $restartStdout -RedirectStandardError $restartStderr -PassThru
$server.Id | Set-Content (Join-Path $evidence 'restart-server.pid')
if (-not (Wait-LogPattern $restartStdout '\*\*\* SERVER STARTED' 120)) {
    throw "Restarted dedicated server did not start; inspect $restartStdout"
}
Write-Output "QA server restarted: old=$oldPid new=$($server.Id)"
if ($VerifyDatePersistence) {
    $javaw = Join-Path $game 'jre64\bin\javaw.exe'
    $common = @('-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED',
        '--add-exports=java.base/jdk.internal.misc=ALL-UNNAMED','-Xmx2048m',
        '-Dzomboid.steam=0','-Djava.library.path=./win64/;./','-cp','projectzomboid.jar')
    $hostArgs = $common + @('-javaagent:E:/pzmod/tests/hands-free-qa.jar=' + $hostProfile,
        'zombie.gameStates.MainScreenState',"-cachedir=$hostProfile",'-nosteam','-nosound')
    $guestProfile = Join-Path ([System.IO.Path]::GetFullPath($ProfileRoot)) 'mp-guest'
    $guestArgs = $common + @('-javaagent:E:/pzmod/tests/hands-free-qa.jar=' + $guestProfile,
        'zombie.gameStates.MainScreenState',"-cachedir=$guestProfile",'-nosteam','-nosound')
    $hostRestartStdout = Join-Path $hostProfile 'restart.stdout.log'
    $hostRestartStderr = Join-Path $hostProfile 'restart.stderr.log'
    $guestRestartStdout = Join-Path $guestProfile 'restart.stdout.log'
    $guestRestartStderr = Join-Path $guestProfile 'restart.stderr.log'
    Set-Content $hostRestartStdout ''
    Set-Content $hostRestartStderr ''
    Set-Content $guestRestartStdout ''
    Set-Content $guestRestartStderr ''
    Start-Process $javaw -ArgumentList $hostArgs -WorkingDirectory $game `
        -RedirectStandardOutput $hostRestartStdout -RedirectStandardError $hostRestartStderr | Out-Null
    Start-Sleep -Seconds 5
    Start-Process $javaw -ArgumentList $guestArgs -WorkingDirectory $game `
        -RedirectStandardOutput $guestRestartStdout -RedirectStandardError $guestRestartStderr | Out-Null
}
if ($VerifyDatePersistence -and -not (Wait-LogPattern $restartStdout 'NLQA DATE SEED SKIPPED: persisted completedDates=1' 180)) {
    throw "Restarted dedicated server did not load the persisted completed date; inspect $restartStdout"
}
if ($VerifyDatePersistence) {
    if (-not (Wait-ClientLogPatternAfterRestart $hostProfile $oldHostLogPath $oldHostLogOffset `
            'NLQA MP CONNECTED: nl-host' 240)) {
        $latestHostLog = Get-ChildItem (Join-Path $hostProfile 'Logs') -Filter '*_DebugLog.txt' -File |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        throw "Host did not reconnect after dedicated-server restart; inspect $($latestHostLog.FullName)"
    }
    if (-not (Wait-ClientLogPatternAfterRestart `
            (Join-Path ([System.IO.Path]::GetFullPath($ProfileRoot)) 'mp-guest') `
            $oldGuestLogPath $oldGuestLogOffset 'NLQA MP CONNECTED: nl-guest' 240)) {
        throw "Guest did not reconnect after dedicated-server restart"
    }
} elseif (-not (Wait-LogPatternAfter $hostLog.FullName 'NLQA MP CONNECTED: nl-host' $hostLogOffset 180)) {
    throw "Host did not reconnect after dedicated-server restart; inspect $($hostLog.FullName)"
}
if ($VerifyHouseholdPersistence) {
    if (-not (Wait-LogPatternAfter $hostLog.FullName 'HOUSEHOLD RESTART SNAPSHOT' $hostLogOffset 300)) {
        throw "Host did not observe persisted household after dedicated-server restart; inspect $($hostLog.FullName)"
    }
    Write-Output 'PASS: host observed persisted household membership, furnishing, and storage after dedicated-server restart'
}
if ($VerifyDatePersistence) {
    Write-Output 'PASS: dedicated server loaded persisted completed NPC date with fresh host and guest connected'
}
if (-not $VerifyHouseholdPersistence -and -not $VerifyDatePersistence) {
    if (-not (Wait-LogPatternAfter $hostLog.FullName 'NPC INVENTORY RESTART SNAPSHOT' $hostLogOffset 300)) {
        throw "Host did not observe persisted NPC inventory after reconnect; inspect $($hostLog.FullName)"
    }
    if (-not (Wait-LogPatternAfter $hostLog.FullName 'NPC INVENTORY REQUEST RESULT' $hostLogOffset 300)) {
        throw "Host did not complete post-restart inventory exchange; inspect $($hostLog.FullName)"
    }
}
if (-not $VerifyHouseholdPersistence -and -not $VerifyDatePersistence) {
    if (-not (Wait-LogPatternAfter $hostLog.FullName 'CAREER WORK RESTART SNAPSHOT' $hostLogOffset 180)) {
        throw "Host did not observe persisted career work after reconnect; inspect $($hostLog.FullName)"
    }
}
if ($VerifyHouseholdPersistence) {
    Write-Output 'PASS: host observed persisted household membership, furnishing, and storage after dedicated-server restart'
} elseif ($VerifyDatePersistence) {
    Write-Output 'PASS: dedicated server loaded persisted completed NPC date with fresh host and guest connected'
} else {
    Write-Output 'PASS: host observed persisted NPC inventory and career work after dedicated-server restart'
}
if ($VerifyDatePersistence) {
    # The date verifier owns its fresh server/clients. Stop them before the
    # parent waits on this helper so no descendant keeps the QA pipe open.
    $dateBase = [System.IO.Path]::GetFullPath($ProfileRoot)
    $dateProcesses = @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -in @('java.exe', 'javaw.exe') -and $_.CommandLine -and
            $_.CommandLine -like "*$dateBase*"
    })
    foreach ($dateProcess in $dateProcesses) {
        Stop-Process -Id ([int]$dateProcess.ProcessId) -Force -ErrorAction SilentlyContinue
    }
}
