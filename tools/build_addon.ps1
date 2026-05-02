param(
    [string]$ModRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$SkipIfUpToDate,
    [string]$ToolsDirectory = 'C:\Steam\steamapps\common\Arma 3 Tools'
)

$ErrorActionPreference = 'Stop'

$ModRoot = (Resolve-Path -LiteralPath $ModRoot).Path

function Fail {
    param([string]$Message)

    Write-Error $Message
    exit 1
}

$addonRoot = Join-Path $ModRoot 'addons'
$sourceRoot = Join-Path $addonRoot 'main'
$outputPbo = Join-Path $addonRoot 'co_main.pbo'
$stalePbo = Join-Path $addonRoot 'main.pbo'
$configPath = Join-Path $sourceRoot 'config.cpp'
$prefixPath = Join-Path $sourceRoot '$PBOPREFIX$'
$functionsPath = Join-Path $sourceRoot 'functions'
$uiPath = Join-Path $sourceRoot 'ui'
$builderPath = Join-Path $ToolsDirectory 'AddonBuilder\AddonBuilder.exe'

if (!(Test-Path -LiteralPath $builderPath)) {
    Fail "Addon Builder not found: $builderPath"
}

if (!(Test-Path -LiteralPath $sourceRoot)) {
    Fail "Addon source folder not found: $sourceRoot"
}

$sourceArtifacts = @(
    Get-ChildItem -LiteralPath $functionsPath -File -Recurse
    Get-ChildItem -LiteralPath $uiPath -File -Recurse -ErrorAction SilentlyContinue
    Get-Item -LiteralPath $configPath
    Get-Item -LiteralPath $prefixPath
)

$needsBuild = $true
if ((Test-Path -LiteralPath $outputPbo) -and $SkipIfUpToDate) {
    $pboItem = Get-Item -LiteralPath $outputPbo
    $newestSource = $sourceArtifacts | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $needsBuild = $newestSource.LastWriteTime -gt $pboItem.LastWriteTime
}

if (-not $needsBuild) {
    Write-Host "[OK] Addon PBO is already up to date: $outputPbo"
    exit 0
}

$tempRoot = Join-Path $env:TEMP 'co_addonbuilder'
$tempOutput = Join-Path $tempRoot 'out'
$tempBuild = Join-Path $tempRoot 'build'
$includeFile = Join-Path $tempRoot 'include.txt'

Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $tempOutput -Force | Out-Null
New-Item -ItemType Directory -Path $tempBuild -Force | Out-Null
Set-Content -LiteralPath $includeFile -Value '*.sqf;*.hpp' -Encoding ASCII -NoNewline

& $builderPath $sourceRoot $tempOutput '-clear' "-temp=$tempBuild" "-include=$includeFile" "-toolsDirectory=$ToolsDirectory"
if ($LASTEXITCODE -ne 0) {
    Fail "Addon Builder failed with exit code $LASTEXITCODE"
}

$rebuiltPbo = Join-Path $tempOutput 'main.pbo'
if (!(Test-Path -LiteralPath $rebuiltPbo)) {
    Fail "Addon Builder completed without producing $rebuiltPbo"
}

if (Test-Path -LiteralPath $stalePbo) {
    Remove-Item -LiteralPath $stalePbo -Force
}

if (Test-Path -LiteralPath $outputPbo) {
    Remove-Item -LiteralPath $outputPbo -Force
}

Move-Item -LiteralPath $rebuiltPbo -Destination $outputPbo -Force
Write-Host "[OK] Rebuilt addon PBO: $outputPbo"