$ErrorActionPreference = 'Stop'
$root = 'E:\pzmod'
$game = 'E:\SteamLibrary\steamapps\common\ProjectZomboid'
$serverProfile = Join-Path $root 'test-profile\mp-server'
$hostProfile = Join-Path $root 'test-profile\mp-host'
$evidence = Join-Path $root 'evidence\v58'
$serverLog = Join-Path $serverProfile 'server.stdout.log'
$restartStdout = Join-Path $serverProfile 'server.crash-restart.stdout.log'
$restartStderr = Join-Path $serverProfile 'server.crash-restart.stderr.log'

function Wait-LogPattern($path, $pattern, $seconds) {
    $deadline = (Get-Date).AddSeconds($seconds)
    do {
        if ((Test-Path $path) -and (Select-String -Path $path -Pattern $pattern -Quiet -ErrorAction SilentlyContinue)) {
            return $true
        }
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

Write-Output 'Starting isolated crash-probe launcher'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\launch-multiplayer-qa.ps1') -InventoryCrashProbe
if ($LASTEXITCODE -ne 0) { throw "QA launcher failed with exit $LASTEXITCODE" }

$initialServerOffset = (Get-Item $serverLog).Length
$hostLog = Get-ChildItem (Join-Path $hostProfile 'Logs') -Filter '*_DebugLog.txt' -File |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $hostLog) { throw 'Host debug log was not found after crash-probe launch' }
$hostOffset = $hostLog.Length

if (-not (Wait-LogPatternAfter $serverLog 'NLQA INVENTORY JOURNAL PARTIAL' $initialServerOffset 600)) {
    throw "Partial inventory journal marker did not arrive; inspect $serverLog"
}
$partialOffset = (Get-Item $serverLog).Length
Write-Output 'QA crash probe: partial player-applied journal phase observed'

if (-not (Wait-LogPatternAfter $serverLog 'SaveAll took' $partialOffset 180)) {
    throw "Server did not save after the partial journal marker; inspect $serverLog"
}
Write-Output 'QA crash probe: pending journal reached SaveAll'

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
Write-Output "QA crash probe: forced server stop old=$oldPid"

Set-Content (Join-Path $hostProfile 'reconnect-request') 'crash-restart'
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
Write-Output "QA crash probe: server restarted old=$oldPid new=$($server.Id)"

if (-not (Wait-LogPatternAfter $hostLog.FullName 'NLQA MP CONNECTED: nl-host' $hostOffset 240)) {
    throw "Host did not reconnect after forced crash; inspect $($hostLog.FullName)"
}
if (-not (Wait-LogPattern $restartStdout 'NLQA INVENTORY JOURNAL RECOVERY: state=repaired' 180)) {
    throw "Pending inventory journal was not repaired after restart; inspect $restartStdout"
}
if (-not (Wait-LogPatternAfter $hostLog.FullName 'Inventory recovery repaired' $hostOffset 180)) {
    throw "Host did not observe the repaired inventory result; inspect $($hostLog.FullName)"
}
Write-Output "QA crash probe: old=$oldPid new=$($server.Id)"
Write-Output 'PASS: partial inventory transaction repaired after forced server crash'
