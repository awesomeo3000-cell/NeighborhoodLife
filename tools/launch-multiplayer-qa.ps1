param(
    [switch]$InventoryCrashProbe,
    [switch]$HouseholdCrashProbe,
    [switch]$GlobalJournalCrashProbe,
    [switch]$DeliveryCrashProbe,
    [switch]$PromotionProbe,
    [switch]$NativeRosterProbe,
    [switch]$NativeBridgeProbe,
    [switch]$NpcMovementProbe,
    [switch]$PartnershipProbe,
    [switch]$HomeAspirationProbe,
    [switch]$VerticalSliceProbe,
    [switch]$NativeReflectionProbe,
    [switch]$NpcInteractionProbe,
    [switch]$DateProbe,
    [switch]$SocialBreadthProbe,
    [switch]$NpcScheduleProbe,
    [switch]$ZombiesDisabledProbe,
    [switch]$PreserveHousehold,
    [switch]$VerifyHouseholdMetadata,
    [string]$ProfileRoot = 'E:\pzmod\test-profile',
    [string]$EvidenceRoot = 'E:\pzmod\evidence\v14'
)
$ErrorActionPreference = 'Stop'
$root = 'E:\pzmod'
$game = 'E:\SteamLibrary\steamapps\common\ProjectZomboid'
$base = [System.IO.Path]::GetFullPath($ProfileRoot)
New-Item -ItemType Directory -Force $base | Out-Null
$serverProfile = Join-Path $base 'mp-server'
$hostProfile = Join-Path $base 'mp-host'
$guestProfile = Join-Path $base 'mp-guest'
$evidence = [System.IO.Path]::GetFullPath($EvidenceRoot)
$profiles = @($serverProfile, $hostProfile, $guestProfile)
New-Item -ItemType Directory -Force $evidence | Out-Null

foreach ($profile in $profiles) {
    New-Item -ItemType Directory -Force "$profile\mods" | Out-Null
    # Build 42 creates this sentinel on first boot and otherwise resets
    # default.txt to an empty mod list. Seed it before a disposable client
    # starts so the QA copies remain enabled on a clean profile.
    $resetMods = Join-Path $profile 'mods\reset-mods-42_00.txt'
    if (-not (Test-Path $resetMods)) {
        'Hands-free QA profile: preserve the launcher-provided mod list.' | Set-Content $resetMods
    }
    [System.IO.File]::Delete((Join-Path $profile 'reconnect-request'))
    foreach ($modId in @('NeighborhoodLife','NeighborhoodQA')) {
        $stale = Join-Path $profile "mods\$modId"
        if (Test-Path $stale) { Remove-Item -LiteralPath $stale -Recurse -Force }
    }
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

if ($InventoryCrashProbe -or $HouseholdCrashProbe -or $GlobalJournalCrashProbe -or $DeliveryCrashProbe) {
    $faultLines = @()
    if ($InventoryCrashProbe) { $faultLines += "NLQAInventoryFaultMode = 'player-applied'" }
    if ($HouseholdCrashProbe) {
        $faultLines += "NLQAHouseholdFaultMode = 'player-applied'"
        $faultLines += "NLQAPreserveHouseholdRestart = true"
    }
    if ($GlobalJournalCrashProbe) {
        $faultLines += "NLQAGlobalJournalFaultMode = 'before-clear'"
        $faultLines += "NLQAGlobalJournalFaultCommand = 'task'"
        $faultLines += "NLQAPreserveHouseholdRestart = true"
    }
    if ($DeliveryCrashProbe) { $faultLines += "NLQADeliveryFaultMode = 'player-applied'" }
    $faultLines | Set-Content "$serverProfile\mods\NeighborhoodQA\42\media\lua\server\NLQAFaultConfig.lua"
}

# Per-client identity: the engine has no no-Steam username source at the main menu,
# so the isolated launcher writes one small identity file into each QA client copy.
$preserveHouseholdValue = if ($PreserveHousehold) { 'true' } else { 'false' }
$metadataProbeValue = if ($VerifyHouseholdMetadata) { 'true' } else { 'false' }
$deliveryCrashProbeValue = if ($DeliveryCrashProbe) { 'true' } else { 'false' }
$globalJournalCrashProbeValue = if ($GlobalJournalCrashProbe) { 'true' } else { 'false' }
$promotionProbeValue = if ($PromotionProbe) { 'true' } else { 'false' }
$nativeRosterProbeValue = if ($NativeRosterProbe) { 'true' } else { 'false' }
$nativeBridgeProbeValue = if ($NativeBridgeProbe) { 'true' } else { 'false' }
$npcMovementProbeValue = if ($NpcMovementProbe) { 'true' } else { 'false' }
$partnershipProbeValue = if ($PartnershipProbe) { 'true' } else { 'false' }
$homeAspirationProbeValue = if ($HomeAspirationProbe) { 'true' } else { 'false' }
$verticalSliceProbeValue = if ($VerticalSliceProbe) { 'true' } else { 'false' }
$nativeReflectionProbeValue = if ($NativeReflectionProbe) { 'true' } else { 'false' }
$npcInteractionProbeValue = if ($NpcInteractionProbe) { 'true' } else { 'false' }
$dateProbeValue = if ($DateProbe) { 'true' } else { 'false' }
$socialBreadthProbeValue = if ($SocialBreadthProbe) { 'true' } else { 'false' }
$npcScheduleProbeValue = if ($NpcScheduleProbe) { 'true' } else { 'false' }
$zombiesDisabledProbeValue = if ($ZombiesDisabledProbe) { 'true' } else { 'false' }
if ($NativeRosterProbe) {
    "NLQANativeRosterProbe = true" | Set-Content "$serverProfile\mods\NeighborhoodQA\42\media\lua\server\NLQANativeRosterConfig.lua"
}
if ($NativeBridgeProbe) {
    "NLQANativeBridgeProbe = true" | Set-Content "$serverProfile\mods\NeighborhoodQA\42\media\lua\server\NLQANativeBridgeConfig.lua"
}
if ($NativeReflectionProbe) {
    "NLQANativeReflectionProbe = true" | Set-Content "$serverProfile\mods\NeighborhoodQA\42\media\lua\server\NLQANativeReflectionConfig.lua"
}
"NLQAZombiesDisabled = $zombiesDisabledProbeValue" | Set-Content "$serverProfile\mods\NeighborhoodQA\42\media\lua\server\NLQAZombieModeConfig.lua"
if ($PartnershipProbe) {
    "NLQAPartnershipProbe = true" | Set-Content "$serverProfile\mods\NeighborhoodQA\42\media\lua\server\NLQAPartnershipConfig.lua"
}
if ($NpcMovementProbe) {
    "NLQANpcMovementProbe = true" | Set-Content "$serverProfile\mods\NeighborhoodQA\42\media\lua\server\NLQANpcMovementConfig.lua"
}
if ($DateProbe) {
    "NLQADateProbe = true" | Set-Content "$serverProfile\mods\NeighborhoodQA\42\media\lua\server\NLQADateConfig.lua"
}
if ($SocialBreadthProbe) {
    "NLQASocialBreadthProbe = true" | Set-Content "$serverProfile\mods\NeighborhoodQA\42\media\lua\server\NLQASocialBreadthConfig.lua"
}
if ($NpcScheduleProbe) {
    "NLQANpcScheduleProbe = true" | Set-Content "$serverProfile\mods\NeighborhoodQA\42\media\lua\server\NLQANpcScheduleConfig.lua"
}
"NLQAIdentity = { username = `"nl-host`", address = `"127.0.0.1:16261`", password = `"qa-account-password`", reconnect = true, preserveHousehold = $preserveHouseholdValue, metadataProbe = $metadataProbeValue, deliveryCrashProbe = $deliveryCrashProbeValue, globalJournalCrashProbe = $globalJournalCrashProbeValue, promotionProbe = $promotionProbeValue, nativeRosterProbe = $nativeRosterProbeValue, nativeBridgeProbe = $nativeBridgeProbeValue, nativeReflectionProbe = $nativeReflectionProbeValue, npcInteractionProbe = $npcInteractionProbeValue, dateProbe = $dateProbeValue, socialBreadthProbe = $socialBreadthProbeValue, npcScheduleProbe = $npcScheduleProbeValue, zombiesDisabledProbe = $zombiesDisabledProbeValue, npcMovementProbe = $npcMovementProbeValue, partnershipProbe = $partnershipProbeValue, homeAspirationProbe = $homeAspirationProbeValue, verticalSliceProbe = $verticalSliceProbeValue }" | Set-Content "$hostProfile\mods\NeighborhoodQA\42\media\lua\client\NLQAIdentity.lua"
"NLQAIdentity = { username = `"nl-guest`", address = `"127.0.0.1:16261`", password = `"qa-account-password`", reconnect = true, preserveHousehold = $preserveHouseholdValue, metadataProbe = $metadataProbeValue, deliveryCrashProbe = $deliveryCrashProbeValue, globalJournalCrashProbe = $globalJournalCrashProbeValue, promotionProbe = $promotionProbeValue, nativeRosterProbe = $nativeRosterProbeValue, nativeBridgeProbe = $nativeBridgeProbeValue, nativeReflectionProbe = $nativeReflectionProbeValue, npcInteractionProbe = $npcInteractionProbeValue, dateProbe = $dateProbeValue, socialBreadthProbe = $socialBreadthProbeValue, npcScheduleProbe = $npcScheduleProbeValue, zombiesDisabledProbe = $zombiesDisabledProbeValue, npcMovementProbe = $npcMovementProbeValue, partnershipProbe = $partnershipProbeValue, homeAspirationProbe = $homeAspirationProbeValue, verticalSliceProbe = $verticalSliceProbeValue }" | Set-Content "$guestProfile\mods\NeighborhoodQA\42\media\lua\client\NLQAIdentity.lua"

# Keep both QA client windows windowed and silent; never leave a fullscreen QA window.
function Set-WindowedOptions($path) {
    $defaults = [ordered]@{ width='1280'; height='720'; fullScreen='false'; borderless='false'; soundVolume='0'; musicVolume='0'; ambientVolume='0' }
    $lines = @(Get-Content $path -ErrorAction SilentlyContinue)
    foreach ($key in $defaults.Keys) {
        $pattern = '^' + [regex]::Escape($key) + '='
        $found = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match $pattern) { $lines[$i] = "$key=$($defaults[$key])"; $found = $true }
        }
        if (-not $found) { $lines += "$key=$($defaults[$key])" }
    }
    $lines | Set-Content $path
}
Set-WindowedOptions "$hostProfile\options.ini"
Set-WindowedOptions "$guestProfile\options.ini"

$serverConfig = Join-Path $serverProfile 'Server'
New-Item -ItemType Directory -Force $serverConfig | Out-Null
if ($ZombiesDisabledProbe) { $zombiePopulation = 6 } else { $zombiePopulation = 4 }
@"
SandboxVars = {
    VERSION = 6,
    Zombies = $zombiePopulation,
    ZombieRespawn = 4,
    ZombieMigrate = false,
}
"@ | Set-Content "$serverConfig\servertest_SandboxVars.lua"
@'
AntiCheatChecksum=4
DoLuaChecksum=false
Public=false
Open=true
PauseEmpty=false
UPnP=false
DefaultPort=16261
ResetID=0
Mods=NeighborhoodLifeHUD;NeighborhoodQA
Map=Muldraugh, KY
PVP=false
SleepAllowed=false
PlayerSafehouse=false
# QA-only profile: save frequently so restart/persistence probes do not wait for
# the normal production interval. This file never enters NeighborhoodLife.zip.
SaveWorldEveryMinutes=1
'@ | Set-Content "$serverConfig\servertest.ini"
$java = "$game\jre64\bin\java.exe"
$common = @('-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED',
    '--add-exports=java.base/jdk.internal.misc=ALL-UNNAMED','-Xmx2048m',
    '-Dzomboid.steam=0','-Djava.library.path=./win64/;./','-cp','projectzomboid.jar')
$serverArgs = @('-Ddebug=true','--enable-native-access=ALL-UNNAMED','--add-exports=java.base/jdk.internal.misc=ALL-UNNAMED',
    '-Xmx2048m','-Dzomboid.steam=0','-Djava.library.path=./win64/;./','-cp','projectzomboid.jar',
    'zombie.network.GameServer','-servername','servertest',"-cachedir=$serverProfile",
    '-adminusername','admin','-adminpassword','qa-admin-password','-nosteam')
if ($NativeBridgeProbe) {
    $serverArgs = @('-javaagent:E:/pzmod/tests/native-bridge-qa.jar=' + $serverProfile) + $serverArgs
}
Set-Content "$serverProfile\server.stdout.log" ''
Set-Content "$serverProfile\server.stderr.log" ''
$server = Start-Process $java -ArgumentList $serverArgs -WorkingDirectory $game -RedirectStandardOutput "$serverProfile\server.stdout.log" -RedirectStandardError "$serverProfile\server.stderr.log" -PassThru
$server.Id | Set-Content "$evidence\mp-server.pid"
$deadline = (Get-Date).AddSeconds(120)
do {
    Start-Sleep -Seconds 2
    $started = Select-String -Path "$serverProfile\server.stdout.log" -Pattern '\*\*\* SERVER STARTED' -Quiet -ErrorAction SilentlyContinue
} while (-not $started -and (Get-Date) -lt $deadline)
if (-not $started) { throw "Dedicated server did not reach SERVER STARTED; inspect $serverProfile\server.stdout.log" }

function Start-QAClient($profile, $username) {
    $args = $common + @('-javaagent:E:/pzmod/tests/hands-free-qa.jar=' + $profile,
        'zombie.gameStates.MainScreenState',"-cachedir=$profile",'-nosteam','-nosound')
    return Start-Process "$game\jre64\bin\javaw.exe" -ArgumentList $args -WorkingDirectory $game -PassThru
}

$hostProcess = Start-QAClient $hostProfile 'nl-host'
Start-Sleep -Seconds 5
$guestProcess = Start-QAClient $guestProfile 'nl-guest'
@("server=$($server.Id)","host=$($hostProcess.Id)","guest=$($guestProcess.Id)") | Set-Content "$evidence\mp-processes.txt"
Write-Output "QA multiplayer processes started: server=$($server.Id) host=$($hostProcess.Id) guest=$($guestProcess.Id)"
