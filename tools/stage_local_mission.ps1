param(
    [string]$MissionSource,
    [string]$MissionDestination
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

if ([string]::IsNullOrWhiteSpace($MissionDestination)) {
    Fail 'MissionDestination parameter is required.'
}

if (!(Test-Path -LiteralPath $MissionSource)) {
    Fail "Mission source folder not found: $MissionSource"
}

$requiredFiles = @(
    'mission.sqm',
    'description.ext',
    'init.sqf',
    'CO_adminDefaults.sqf'
)

foreach ($fileName in $requiredFiles) {
    $path = Join-Path $MissionSource $fileName
    if (!(Test-Path -LiteralPath $path)) {
        Fail "Mission source is missing required file: $path"
    }
}

if (!(Test-Path -LiteralPath $MissionDestination)) {
    New-Item -ItemType Directory -Path $MissionDestination | Out-Null
}

$robocopyOutput = robocopy $MissionSource $MissionDestination /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /NP
$robocopyExitCode = $LASTEXITCODE

if ($robocopyExitCode -ge 8) {
    Fail "Robocopy failed while staging the mission folder. Exit code: $robocopyExitCode"
}

Write-Host "[OK] Staged local mission folder to $MissionDestination"