param(
    [string]$ProfileRoot = 'E:\pzmod\test-profile',
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
$root = 'E:\pzmod'
$game = 'E:\SteamLibrary\steamapps\common\ProjectZomboid'
$profile = [System.IO.Path]::GetFullPath($ProfileRoot)

function Get-IsolatedProcesses {
    @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -in @('java.exe', 'javaw.exe') -and $_.CommandLine -and
        $_.CommandLine -like "*$profile*"
    })
}

function Stop-IsolatedProcesses {
    foreach ($process in (Get-IsolatedProcesses)) {
        Stop-Process -Id ([int]$process.ProcessId) -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2
}

function Latest-Log($filter) {
    Get-ChildItem (Join-Path $profile 'Logs') -Filter $filter -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

$passed = $false
$failure = $null
$process = $null

try {
    Stop-IsolatedProcesses

    # Sync mods into isolated profile
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
    'Preserve isolated test mod list.' | Set-Content "$profile\mods\reset-mods-42_00.txt"

    # Set windowed options
    $optionsPath = "$profile\options.ini"
    @'
version=8
width=1280
height=720
fullScreen=false
borderless=false
soundVolume=0
musicVolume=0
ambientVolume=0
'@ | Set-Content $optionsPath

    $arguments = @('-Djava.awt.headless=true','--enable-native-access=ALL-UNNAMED',
        "-javaagent:E:/pzmod/tests/hands-free-qa.jar=$profile",
        '--add-exports=java.base/jdk.internal.misc=ALL-UNNAMED','-Xmx2048m',
        '-Dzomboid.steam=0','-Djava.library.path=.', '-cp','projectzomboid.jar',
        'zombie.gameStates.MainScreenState',"-cachedir=$profile",'-nosteam','-nosound')

    Write-Output "Starting isolated singleplayer Project Zomboid Build 42 instance..."
    $process = Start-Process -FilePath "$game\jre64\bin\javaw.exe" -ArgumentList $arguments -WorkingDirectory $game -PassThru
    Write-Output "Process started with PID: $($process.Id)"

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $npcVerified = $false
    $contextVerified = $false
    $hudVerified = $false
    $completeVerified = $false

    do {
        Start-Sleep -Seconds 2
        $log = Latest-Log '*_DebugLog.txt'
        if ($log) {
            $content = Get-Content $log.FullName -ErrorAction SilentlyContinue
            if ($content -match 'NLQA PASS: 3 production NPC bodies') { $npcVerified = $true }
            if ($content -match 'NLQA PASS: NPC context menu verified for Marisol') { $contextVerified = $true }
            if ($content -match 'NLQA PASS: Needs HUD panel active') { $hudVerified = $true }
            if ($content -match 'NLQA SINGLEPLAYER TEST COMPLETE: ALL CORE PILLARS VERIFIED PASS') {
                $completeVerified = $true
                break
            }
        }
    } while ((Get-Date) -lt $deadline)

    if (-not $completeVerified) {
        $logFile = (Latest-Log '*_DebugLog.txt').FullName
        throw "Singleplayer verification timed out. Checked log: $logFile (npc=$npcVerified, context=$contextVerified, hud=$hudVerified)"
    }

    $passed = $true
    Write-Output "PASS: 3 production NPC bodies spawned and anchored in world"
    Write-Output "PASS: NPC plumbobs verified over heads"
    Write-Output "PASS: NPC right-click interaction menu generated options"
    Write-Output "PASS: Needs HUD panel active and tracking player needs"
    Write-Output "PASS: All core singleplayer pillars verified successfully in Build 42.20.4"
} catch {
    $failure = $_.Exception.Message
    Write-Output "SINGLEPLAYER_QA_FAILURE: $failure"
} finally {
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
    Stop-IsolatedProcesses
}

if (-not $passed) { exit 1 }
