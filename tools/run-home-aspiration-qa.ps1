param(
    [string]$ProfileRoot = 'E:\pzmod\test-profile-v111-home-aspiration',
    [string]$EvidenceRoot = 'E:\pzmod\evidence\v111\actual\home-aspiration'
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
function Latest-Log($profile) {
    Get-ChildItem (Join-Path $profile 'Logs') -Filter '*_DebugLog.txt' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
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

$passed = $false
$failure = $null
try {
    Stop-IsolatedProcesses
    & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tools\launch-multiplayer-qa.ps1') -PromotionProbe -PartnershipProbe -HomeAspirationProbe -VerticalSliceProbe -ProfileRoot $base -EvidenceRoot $evidence
    if ($LASTEXITCODE -ne 0) { throw "QA launcher failed with exit $LASTEXITCODE" }

    $serverLog = Join-Path $serverProfile 'server.stdout.log'
    $hostLog = $null
    $guestLog = $null
    $deadline = (Get-Date).AddSeconds(180)
    do {
        $hostLog = Latest-Log $hostProfile
        $guestLog = Latest-Log $guestProfile
        if ($hostLog -and $guestLog) { break }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    if (-not $hostLog -or -not $guestLog) { throw 'Both client debug logs were not found' }

    $checks = @(
        @{ name='HOST_HOME_TASK'; path=$hostLog.FullName; pattern='NLQA MP HOME ASPIRATION TASK: host=nl-host task=social' },
        @{ name='GUEST_HOME_TASK'; path=$guestLog.FullName; pattern='NLQA MP HOME ASPIRATION TASK: guest=nl-guest task=meal' },
        @{ name='HOST_HOME_RESULT'; path=$hostLog.FullName; pattern='NLQA MP HOME ASPIRATION RESULT: total=3 stage=3 label=Household Heart: 3/6 household activities \(\+20 credits\)' },
        @{ name='SERVER_HOME_CREDIT'; path=$serverLog; pattern='NLQA HOUSEHOLD RESULT: username=nl-host command=task message=Spend time together complete: \+5 credits / Home aspiration reward \+10 credits' }
    )
    foreach ($check in $checks) {
        if (-not (Wait-LogPattern $check.path $check.pattern 480)) {
            throw "$($check.name) did not arrive in $($check.path)"
        }
    }
    $passed = $true
} catch {
    $failure = $_.Exception.Message
    Write-Output "HOME_ASPIRATION_FAILURE=$failure"
} finally {
    $serverLog = Join-Path $serverProfile 'server.stdout.log'
    $hostLog = Latest-Log $hostProfile
    $guestLog = Latest-Log $guestProfile
    if (Test-Path $serverLog) { Copy-Item $serverLog (Join-Path $evidence 'server.stdout.log') -Force }
    if ($hostLog) { Copy-Item $hostLog.FullName (Join-Path $evidence 'host.DebugLog.txt') -Force }
    if ($guestLog) { Copy-Item $guestLog.FullName (Join-Path $evidence 'guest.DebugLog.txt') -Force }
    if ($passed) {
        'PASS: actual host-plus-guest household activities advanced the linked home aspiration' |
            Set-Content (Join-Path $evidence 'RESULT.txt')
        Write-Output 'PASS: actual host-plus-guest household activities advanced the linked home aspiration'
    } else {
        "RESULT: home aspiration progression incomplete: $failure" |
            Set-Content (Join-Path $evidence 'RESULT.txt')
    }
    Stop-IsolatedProcesses
}
if (-not $passed) { exit 1 }
