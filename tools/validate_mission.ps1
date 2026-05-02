param(
    [string]$MissionSource,
    [Alias('MissionPbo')]
    [string]$MissionTarget
)

$ErrorActionPreference = 'Stop'

function Fail {
    param([string]$Message)

    Write-Error $Message
    exit 1
}

if ([string]::IsNullOrWhiteSpace($MissionSource)) {
    Fail 'MissionSource parameter is required.'
}

if ([string]::IsNullOrWhiteSpace($MissionTarget)) {
    Fail 'MissionTarget parameter is required.'
}

$requiredSourceFiles = @(
    'mission.sqm',
    'description.ext',
    'init.sqf',
    'CO_adminDefaults.sqf'
)

foreach ($fileName in $requiredSourceFiles) {
    $path = Join-Path $MissionSource $fileName
    if (!(Test-Path -LiteralPath $path)) {
        Fail "Mission source is missing required file: $path"
    }
}

$missionSqmPath = Join-Path $MissionSource 'mission.sqm'
$missionSqmText = Get-Content -LiteralPath $missionSqmPath -Raw

if ($missionSqmText -notmatch 'class\s+Groups') {
    Fail "Mission source $missionSqmPath does not define any groups."
}

if ($missionSqmText -notmatch 'player\s*=\s*"') {
    Fail "Mission source $missionSqmPath does not contain any playable slots."
}

if (!(Test-Path -LiteralPath $MissionTarget)) {
    Fail "Mission target not found: $MissionTarget"
}

$targetItem = Get-Item -LiteralPath $MissionTarget

if ($targetItem.PSIsContainer) {
    foreach ($fileName in $requiredSourceFiles) {
        $targetPath = Join-Path $MissionTarget $fileName
        if (!(Test-Path -LiteralPath $targetPath)) {
            Fail "The deployed mission folder is missing required file: $targetPath"
        }
    }

    Write-Host "[OK] Mission validation passed for $MissionTarget"
    Write-Host "[OK] Source mission contains mission.sqm with playable slots and the deployed mission folder contains the core mission files."
    exit 0
}

if ($targetItem.Length -lt 8192) {
    Write-Warning "Mission PBO is unusually small ($($targetItem.Length) bytes). Validate the packed contents carefully."
}

$pboBytes = [System.IO.File]::ReadAllBytes($MissionTarget)
$pboText = -join ($pboBytes | ForEach-Object {
    if ($_ -ge 32 -and $_ -le 126) {
        [char]$_
    } else {
        ' '
    }
})

if (-not $pboText.Contains('mission.sqm')) {
    if ($pboText.Contains('config.bin') -and $pboText.Contains('prefix')) {
        Fail "The deployed mission PBO does not contain mission.sqm and appears to be packed like an addon (it contains config.bin/prefix metadata). For local testing, use local_start_server.bat so the unpacked mission folder is staged automatically. For a release mission PBO, rebuild it with a mission-aware exporter instead of Addon Builder."
    }

    Fail "The deployed mission PBO does not contain mission.sqm. Rebuild and redeploy the mission before starting the server."
}

if (-not $pboText.Contains('init.sqf')) {
    Fail "The deployed mission PBO does not contain init.sqf."
}

if (-not ($pboText.Contains('description.ext') -or $pboText.Contains('description.bin'))) {
    Fail "The deployed mission PBO does not contain description.ext or description.bin."
}

Write-Host "[OK] Mission validation passed for $MissionTarget"
Write-Host "[OK] Source mission contains mission.sqm with playable slots and the deployed PBO contains the core mission files."