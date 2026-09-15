param(
    [switch]$NpcInteractionProbe,
    [string]$ProfileRoot = 'E:\pzmod\test-profile-v104-neighborhood-slice',
    [string]$EvidenceRoot = 'E:\pzmod\evidence\v104\actual\neighborhood-slice'
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
function Latest-Log($profile, $filter) {
    Get-ChildItem (Join-Path $profile 'Logs') -Filter $filter -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

$passed = $false
$failure = $null
try {
    Stop-IsolatedProcesses
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\launch-multiplayer-qa.ps1') `
        -PromotionProbe -PartnershipProbe -VerticalSliceProbe -NpcInteractionProbe:$NpcInteractionProbe `
        -ProfileRoot $base -EvidenceRoot $evidence
    if ($LASTEXITCODE -ne 0) { throw "QA launcher failed with exit $LASTEXITCODE" }

    $serverLog = Join-Path $serverProfile 'server.stdout.log'
    $hostLog = $null
    $guestLog = $null
    $deadline = (Get-Date).AddSeconds(180)
    do {
        $hostLog = Latest-Log $hostProfile '*_DebugLog.txt'
        $guestLog = Latest-Log $guestProfile '*_DebugLog.txt'
        if ($hostLog -and $guestLog) { break }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    if (-not $hostLog -or -not $guestLog) { throw 'Both client debug logs were not found' }

    $checks = @(
        @{ name='SERVER_CAREER_SEED'; path=$serverLog; pattern='NLQA CAREER PROMOTION SEED: item=Base.Bandage amount=8 debugLevelOk=true skill=1' },
        @{ name='SERVER_PARTNERSHIP_SEED'; path=$serverLog; pattern='NLQA PARTNERSHIP SEED: target=marisol dates=2 trust=30 attraction=30 friendship=40' },
        @{ name='HOST_HOUSEHOLD_FURNISHING'; path=$hostLog.FullName; pattern='NLQA MP HOUSEHOLD FURNISHING RESULT:' },
        @{ name='GUEST_HOUSEHOLD_JOIN'; path=$guestLog.FullName; pattern='NLQA MP HOUSEHOLD JOIN RESULT: shared home members=2' },
        @{ name='GUEST_HOUSEHOLD_RETRIEVE'; path=$guestLog.FullName; pattern='NLQA MP HOUSEHOLD FURNISHING RETRIEVE RESULT:' },
        @{ name='HOST_HOUSEHOLD_TASK'; path=$hostLog.FullName; pattern='NLQA MP HOUSEHOLD TASK RESULT:' },
        @{ name='HOST_CAREER_PROMOTION'; path=$hostLog.FullName; pattern='NLQA MP CAREER PROMOTION RESULT: career=medic rank=2 skill=1 xp=[0-9]+ variety=3' },
        @{ name='HOST_PARTNERSHIP'; path=$hostLog.FullName; pattern='NLQA MP PARTNERSHIP HOST RESULT: target=marisol status=Partner exclusive=true isPartner=true' },
        @{ name='GUEST_PARTNERSHIP'; path=$guestLog.FullName; pattern='NLQA MP PARTNERSHIP GUEST RESULT: target=marisol status=Unavailable exclusive=true isPartner=false' },
        @{ name='GUEST_PARTNERSHIP_REJECTION'; path=$guestLog.FullName; pattern='NLQA MP PARTNERSHIP GUEST REJECTION: message=Not completed: Already in a partnership\.' }
    )
    foreach ($check in $checks) {
        if (-not (Wait-LogPattern $check.path $check.pattern 480)) {
            throw "$($check.name) did not arrive in $($check.path)"
        }
    }
    if ($NpcInteractionProbe) {
        $directChecks = @(
            @{ name='HOST_NPC_CONTEXT_CALLBACK'; path=$hostLog.FullName; pattern='NLQA MP NPC CONTEXT CALLBACK: id=marisol action=(introduce|chat)' },
            @{ name='GUEST_NPC_CONTEXT_CALLBACK'; path=$guestLog.FullName; pattern='NLQA MP NPC CONTEXT CALLBACK: id=kenji action=(introduce|chat)' }
        )
        foreach ($check in $directChecks) {
            if (-not (Wait-LogPattern $check.path $check.pattern 480)) {
                throw "$($check.name) did not arrive in $($check.path)"
            }
        }
    }
    $passed = $true
} catch {
    $failure = $_.Exception.Message
    Write-Output "SLICE_FAILURE=$failure"
} finally {
    $serverLog = Join-Path $serverProfile 'server.stdout.log'
    $hostLog = Latest-Log $hostProfile '*_DebugLog.txt'
    $guestLog = Latest-Log $guestProfile '*_DebugLog.txt'
    if (Test-Path $serverLog) { Copy-Item $serverLog (Join-Path $evidence 'server.stdout.log') -Force }
    if ($hostLog) { Copy-Item $hostLog.FullName (Join-Path $evidence 'host.DebugLog.txt') -Force }
    if ($guestLog) { Copy-Item $guestLog.FullName (Join-Path $evidence 'guest.DebugLog.txt') -Force }
    if ($passed) {
        $successMessage = if ($NpcInteractionProbe) {
            'PASS: actual host-plus-guest neighborhood vertical slice and direct NPC context callbacks completed'
        } else {
            'PASS: actual host-plus-guest neighborhood vertical slice completed (household, furnishing, career promotion, partnership)'
        }
        $successMessage | Set-Content (Join-Path $evidence 'RESULT.txt')
        Write-Output $successMessage
    } else {
        "RESULT: neighborhood vertical slice incomplete: $failure" | Set-Content (Join-Path $evidence 'RESULT.txt')
    }
    Stop-IsolatedProcesses
}
if (-not $passed) { exit 1 }
