param(
    [string]$ProfileRoot = 'E:\pzmod\test-profile-v137-global-journal',
    [string]$EvidenceRoot = 'E:\pzmod\evidence\v137\actual\global-journal'
)
$ErrorActionPreference = 'Stop'
$root = 'E:\pzmod'
$game = 'E:\SteamLibrary\steamapps\common\ProjectZomboid'
$base = [System.IO.Path]::GetFullPath($ProfileRoot)
$evidence = [System.IO.Path]::GetFullPath($EvidenceRoot)
$serverProfile = Join-Path $base 'mp-server'
$hostProfile = Join-Path $base 'mp-host'
$serverLog = Join-Path $serverProfile 'server.stdout.log'
$restartStdout = Join-Path $serverProfile 'global-journal-restart.stdout.log'
$restartStderr = Join-Path $serverProfile 'global-journal-restart.stderr.log'
New-Item -ItemType Directory -Force $evidence | Out-Null

function Wait-LogPattern($path, $pattern, $seconds) {
    $deadline = (Get-Date).AddSeconds($seconds)
    do {
        if ((Test-Path $path) -and (Select-String -Path $path -Pattern $pattern -Quiet -ErrorAction SilentlyContinue)) { return $true }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    return $false
}

function Wait-LogPatternAfter($path, $pattern, $offset, $seconds) {
    $deadline = (Get-Date).AddSeconds($seconds)
    do {
        if ((Test-Path $path) -and ((Get-Item $path).Length -gt $offset)) {
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

Write-Output 'Starting isolated global ModData journal crash-probe launcher'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\launch-multiplayer-qa.ps1') `
    -GlobalJournalCrashProbe -PreserveHousehold -ProfileRoot $base -EvidenceRoot $evidence
if ($LASTEXITCODE -ne 0) { throw "QA launcher failed with exit $LASTEXITCODE" }

$initialServerOffset = (Get-Item $serverLog).Length
$hostLog = Get-ChildItem (Join-Path $hostProfile 'Logs') -Filter '*_DebugLog.txt' -File |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $hostLog) { throw 'Host debug log was not found after household crash-probe launch' }
$hostOffset = $hostLog.Length
if (-not (Wait-LogPatternAfter $serverLog 'NLQA GLOBAL JOURNAL PARTIAL: command=task' $initialServerOffset 600)) {
    throw "Partial global journal marker did not arrive; inspect $serverLog"
}
$partialOffset = (Get-Item $serverLog).Length
Write-Output 'QA global journal crash probe: partial task journal phase observed'
if (-not (Wait-LogPatternAfter $serverLog 'SaveAll took' $partialOffset 180)) {
    throw "Server did not save after the partial global journal marker; inspect $serverLog"
}
Write-Output 'QA global journal crash probe: pending journal reached SaveAll'

$serverProcesses = @(Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -and $_.CommandLine -like '*zombie.network.GameServer*' -and
        $_.CommandLine -like "*$serverProfile*"
})
if ($serverProcesses.Count -ne 1) {
    throw "Expected exactly one isolated QA server process, found $($serverProcesses.Count)"
}
$oldPid = [int]$serverProcesses[0].ProcessId
Stop-Process -Id $oldPid -Force
Start-Sleep -Seconds 3
if (Get-Process -Id $oldPid -ErrorAction SilentlyContinue) { throw "Server PID $oldPid did not stop" }
Write-Output "QA global journal crash probe: forced server stop old=$oldPid"

Set-Content (Join-Path $hostProfile 'reconnect-request') 'global-journal-restart'
$java = Join-Path $game 'jre64\bin\java.exe'
$args = @('--enable-native-access=ALL-UNNAMED','--add-exports=java.base/jdk.internal.misc=ALL-UNNAMED',
    '-Xmx2048m','-Dzomboid.steam=0','-Djava.library.path=./win64/;./','-cp','projectzomboid.jar',
    'zombie.network.GameServer','-servername','servertest',"-cachedir=$serverProfile",
    '-adminusername','admin','-adminpassword','qa-admin-password','-nosteam','-debug')
Set-Content $restartStdout ''
Set-Content $restartStderr ''
$server = Start-Process $java -ArgumentList $args -WorkingDirectory $game `
    -RedirectStandardOutput $restartStdout -RedirectStandardError $restartStderr -PassThru
$server.Id | Set-Content (Join-Path $evidence 'crash-restart-server.pid')
if (-not (Wait-LogPattern $restartStdout '\*\*\* SERVER STARTED' 180)) {
    throw "Crash-restarted dedicated server did not start; inspect $restartStdout"
}
Write-Output "QA global journal crash probe: server restarted old=$oldPid new=$($server.Id)"

# A Build 42 client that is still inside the old loading state can keep its
# native connection object alive after a hard server stop. Replace both
# disposable clients hands-free, preserving their cachedir/world and proving
# the same saved household is repaired by a fresh client session.
$clientPids = @()
if (Test-Path (Join-Path $evidence 'mp-processes.txt')) {
    $clientPids = @(Get-Content (Join-Path $evidence 'mp-processes.txt') |
        Where-Object { $_ -match '^(host|guest)=(\d+)$' } |
        ForEach-Object { [int]$Matches[2] })
}
foreach ($clientPid in $clientPids) {
    Stop-Process -Id $clientPid -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 3

$common = @('-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED',
    '--add-exports=java.base/jdk.internal.misc=ALL-UNNAMED','-Xmx2048m',
    '-Dzomboid.steam=0','-Djava.library.path=./win64/;./','-cp','projectzomboid.jar')
function Start-QAClient($profile) {
    $clientArgs = $common + @('-javaagent:E:/pzmod/tests/hands-free-qa.jar=' + $profile,
        'zombie.gameStates.MainScreenState',"-cachedir=$profile",'-nosteam','-nosound')
    return Start-Process "$game\jre64\bin\javaw.exe" -ArgumentList $clientArgs -WorkingDirectory $game -PassThru
}
$hostLogBeforeRestart = Get-ChildItem (Join-Path $hostProfile 'Logs') -Filter '*_DebugLog.txt' -File |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
$hostOffsetBeforeRestart = if ($hostLogBeforeRestart) { $hostLogBeforeRestart.Length } else { 0 }
$hostProcess = Start-QAClient $hostProfile
Start-Sleep -Seconds 5
$guestProcess = Start-QAClient (Join-Path $base 'mp-guest')
@("host=$($hostProcess.Id)","guest=$($guestProcess.Id)") | Set-Content (Join-Path $evidence 'crash-reconnect-processes.txt')
$hostLog = Get-ChildItem (Join-Path $hostProfile 'Logs') -Filter '*_DebugLog.txt' -File |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $hostLog) { throw 'Host debug log was not found after crash-client restart' }
$hostOffset = if ($hostLogBeforeRestart -and $hostLog.FullName -eq $hostLogBeforeRestart.FullName) {
    $hostOffsetBeforeRestart
} else { 0 }
Write-Output "QA global journal crash probe: clients restarted host=$($hostProcess.Id) guest=$($guestProcess.Id)"
if (-not (Wait-LogPatternAfter $hostLog.FullName 'NLQA MP CONNECTED: nl-host' $hostOffset 240)) {
    throw "Fresh host did not reconnect after forced crash; inspect $($hostLog.FullName)"
}
$restartDebug = Get-ChildItem (Join-Path $serverProfile 'Logs') -Recurse -Filter '*_DebugLog-server.txt' -File |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $restartDebug) { throw 'Restarted server debug log was not found' }
if (-not (Wait-LogPattern $restartDebug.FullName 'NLQA GLOBAL JOURNAL RECOVERY: state=repaired' 180)) {
    throw "Pending global journal was not repaired after restart; inspect $($restartDebug.FullName)"
}
if (-not (Wait-LogPatternAfter $hostLog.FullName 'GLOBAL JOURNAL RECOVERY RESULT: Global data recovery repaired' $hostOffset 180)) {
    throw "Host did not observe the repaired global result; inspect $($hostLog.FullName)"
}
Write-Output "QA global journal crash probe: old=$oldPid new=$($server.Id)"
Write-Output 'PASS: partial global ModData mutation repaired after forced server crash and fresh host reconnect'
