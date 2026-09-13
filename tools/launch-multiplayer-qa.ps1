$ErrorActionPreference = 'Stop'
$root = 'E:\pzmod'
$game = 'E:\SteamLibrary\steamapps\common\ProjectZomboid'
$base = Join-Path $root 'test-profile'
$serverProfile = Join-Path $base 'mp-server'
$hostProfile = Join-Path $base 'mp-host'
$guestProfile = Join-Path $base 'mp-guest'
$profiles = @($serverProfile, $hostProfile, $guestProfile)

foreach ($profile in $profiles) {
    New-Item -ItemType Directory -Force "$profile\mods" | Out-Null
    Copy-Item "$root\NeighborhoodLife" "$profile\mods" -Recurse -Force
    Copy-Item "$root\qa\NeighborhoodQA" "$profile\mods" -Recurse -Force
    @'
VERSION = 1,
mods
{
    mod = NeighborhoodLifeHUD,
    mod = NeighborhoodQA,
}
maps
{
}
'@ | Set-Content "$profile\mods\default.txt"
}

$serverConfig = Join-Path $serverProfile 'Server'
New-Item -ItemType Directory -Force $serverConfig | Out-Null
@'
Public=false
Open=true
PauseEmpty=false
DefaultPort=16261
ResetID=0
Mods=NeighborhoodLifeHUD
Map=Muldraugh, KY
PVP=false
SleepAllowed=false
PlayerSafehouse=false
SaveWorldEveryMinutes=5
'@ | Set-Content "$serverConfig\servertest.ini"
$java = "$game\jre64\bin\java.exe"
$common = @('-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED',
    '--add-exports=java.base/jdk.internal.misc=ALL-UNNAMED','-Xmx2048m',
    '-Dzomboid.steam=0','-Djava.library.path=./win64/;./','-cp','projectzomboid.jar')
$serverArgs = @('--enable-native-access=ALL-UNNAMED','--add-exports=java.base/jdk.internal.misc=ALL-UNNAMED',
    '-Xmx2048m','-Dzomboid.steam=0','-Djava.library.path=./win64/;./','-cp','projectzomboid.jar',
    'zombie.network.GameServer','-servername','servertest',"-cachedir=$serverProfile",
    '-adminusername','admin','-adminpassword','qa-admin-password','-nosteam')
Set-Content "$serverProfile\server.stdout.log" ''
Set-Content "$serverProfile\server.stderr.log" ''
$server = Start-Process $java -ArgumentList $serverArgs -WorkingDirectory $game -RedirectStandardOutput "$serverProfile\server.stdout.log" -RedirectStandardError "$serverProfile\server.stderr.log" -PassThru
$server.Id | Set-Content "$root\evidence\v10\mp-server.pid"
$deadline = (Get-Date).AddSeconds(120)
do {
    Start-Sleep -Seconds 2
    $started = Select-String -Path "$serverProfile\server.stdout.log" -Pattern '\*\*\* SERVER STARTED' -Quiet -ErrorAction SilentlyContinue
} while (-not $started -and (Get-Date) -lt $deadline)
if (-not $started) { throw "Dedicated server did not reach SERVER STARTED; inspect $serverProfile\server.stdout.log" }

function Start-QAClient($profile, $username) {
    $args = $common + @('-javaagent:E:/pzmod/tests/hands-free-qa.jar=' + $profile,
        'zombie.gameStates.MainScreenState',"-cachedir=$profile",'+connect','127.0.0.1:16261',
        '+password','qa-password','-nosteam','-nosound')
    return Start-Process "$game\jre64\bin\javaw.exe" -ArgumentList $args -WorkingDirectory $game -PassThru
}

$hostProcess = Start-QAClient $hostProfile 'nl-host'
$guestProcess = Start-QAClient $guestProfile 'nl-guest'
@("server=$($server.Id)","host=$($hostProcess.Id)","guest=$($guestProcess.Id)") | Set-Content "$root\evidence\v10\mp-processes.txt"
Write-Output "QA multiplayer processes started: server=$($server.Id) host=$($hostProcess.Id) guest=$($guestProcess.Id)"
