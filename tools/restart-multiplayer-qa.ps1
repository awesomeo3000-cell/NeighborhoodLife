$ErrorActionPreference = 'Stop'
$root = 'E:\pzmod'
$game = 'E:\SteamLibrary\steamapps\common\ProjectZomboid'
$serverProfile = Join-Path $root 'test-profile\mp-server'
$hostProfile = Join-Path $root 'test-profile\mp-host'
$serverLog = Join-Path $serverProfile 'server.stdout.log'
$hostLog = Get-ChildItem (Join-Path $hostProfile 'Logs') -Filter '*_DebugLog.txt' -File |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $hostLog) { throw 'Host debug log was not found' }

function Wait-LogPattern($path, $pattern, $seconds) {
    $deadline = (Get-Date).AddSeconds($seconds)
    do {
        if (Select-String -Path $path -Pattern $pattern -Quiet -ErrorAction SilentlyContinue) { return $true }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    return $false
}

if (-not (Wait-LogPattern $hostLog.FullName 'NPC INVENTORY REQUEST RESULT' 420)) {
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

$serverProcesses = @(Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -and $_.CommandLine -like '*zombie.network.GameServer*' -and `
        $_.CommandLine -like '*mp-server*'
})
if ($serverProcesses.Count -ne 1) {
    throw "Expected exactly one isolated QA server process, found $($serverProcesses.Count)"
}
$oldPid = [int]$serverProcesses[0].ProcessId
Stop-Process -Id $oldPid -Force
Start-Sleep -Seconds 3
if (Get-Process -Id $oldPid -ErrorAction SilentlyContinue) { throw "Server PID $oldPid did not stop" }
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
$server.Id | Set-Content (Join-Path $root 'evidence\v55\restart-server.pid')
if (-not (Wait-LogPattern $restartStdout '\*\*\* SERVER STARTED' 120)) {
    throw "Restarted dedicated server did not start; inspect $restartStdout"
}
Write-Output "QA server restarted: old=$oldPid new=$($server.Id)"
if (-not (Wait-LogPatternAfter $hostLog.FullName 'NLQA MP CONNECTED: nl-host' $hostLogOffset 180)) {
    throw "Host did not reconnect after dedicated-server restart; inspect $($hostLog.FullName)"
}
if (-not (Wait-LogPatternAfter $hostLog.FullName 'NPC INVENTORY RESTART SNAPSHOT' $hostLogOffset 300)) {
    throw "Host did not observe persisted NPC inventory after reconnect; inspect $($hostLog.FullName)"
}
if (-not (Wait-LogPatternAfter $hostLog.FullName 'NPC INVENTORY REQUEST RESULT' $hostLogOffset 300)) {
    throw "Host did not complete post-restart inventory exchange; inspect $($hostLog.FullName)"
}
Write-Output 'PASS: host observed persisted NPC inventory after dedicated-server restart'
