$ErrorActionPreference = 'Stop'
$game = 'E:\SteamLibrary\steamapps\common\ProjectZomboid'
$root = 'E:\pzmod'
$profile = Join-Path $root 'test-profile'
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
'Preserve the isolated test mod list.' | Set-Content "$profile\mods\reset-mods-42_00.txt"
if (-not (Test-Path "$profile\options.ini")) {
@'
version=8
width=1280
height=720
fullScreen=false
borderless=false
soundVolume=0
musicVolume=0
ambientVolume=0
'@ | Set-Content "$profile\options.ini"
}
$arguments = @('-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED',
    '-javaagent:E:/pzmod/tests/hands-free-qa.jar=E:/pzmod/test-profile',
    '--add-exports=java.base/jdk.internal.misc=ALL-UNNAMED','-Xmx2048m',
    '-Dzomboid.steam=0','-Djava.library.path=.', '-cp','projectzomboid.jar',
    'zombie.gameStates.MainScreenState',"-cachedir=$profile",'-nosteam','-nosound')
# Deliberately visible: this is the isolated interactive game test window.
$process = Start-Process -FilePath "$game\jre64\bin\javaw.exe" -ArgumentList $arguments -WorkingDirectory $game -PassThru
$process.Id | Set-Content "$root\evidence\v02\qa-process-id.txt"
Write-Output "QA process: $($process.Id); isolated profile: $profile"
