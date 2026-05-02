param(
    [string]$ModRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Fail {
    param([string]$Message)

    Write-Error $Message
    exit 1
}

$addonRoot = Join-Path $ModRoot 'addons'
$sourceRoot = Join-Path $addonRoot 'main'
$pboPath = Join-Path $addonRoot 'co_main.pbo'
$duplicatePboPath = Join-Path $addonRoot 'main.pbo'
$prefixPath = Join-Path $sourceRoot '$PBOPREFIX$'
$functionsPath = Join-Path $sourceRoot 'functions'

if (!(Test-Path -LiteralPath $pboPath)) {
    Fail "Missing addon PBO: $pboPath"
}

if (Test-Path -LiteralPath $duplicatePboPath) {
    Fail "Stale duplicate addon PBO detected: $duplicatePboPath"
}

if (!(Test-Path -LiteralPath $prefixPath)) {
    Fail "Missing PBO prefix file: $prefixPath"
}

$expectedPrefix = [System.Text.Encoding]::ASCII.GetBytes('co_main')
$actualPrefix = [System.IO.File]::ReadAllBytes($prefixPath)
if ($actualPrefix.Length -ne $expectedPrefix.Length -or (@($actualPrefix) -join ',') -ne (@($expectedPrefix) -join ',')) {
    Fail "`$PBOPREFIX$ must contain exactly 'co_main' with no BOM, newline, or extra whitespace."
}

$sourceFunctions = Get-ChildItem -LiteralPath $functionsPath -Filter 'fn_*.sqf' | Sort-Object Name
if ($sourceFunctions.Count -eq 0) {
    Fail "No function source files were found under $functionsPath"
}

$pboLength = (Get-Item -LiteralPath $pboPath).Length
if ($pboLength -lt 65536) {
    Write-Warning "The built PBO is unusually small ($pboLength bytes). Validate that Addon Builder copied the SQF sources."
}

$pboBytes = [System.IO.File]::ReadAllBytes($pboPath)
$pboText = -join ($pboBytes | ForEach-Object {
    if ($_ -ge 32 -and $_ -le 126) {
        [char]$_
    } else {
        ' '
    }
})

if (-not $pboText.Contains('config.bin')) {
    Fail "The built PBO does not appear to contain config.bin."
}

$missingFunctions = $sourceFunctions |
    Where-Object { -not $pboText.Contains($_.Name) } |
    Select-Object -ExpandProperty Name

if ($missingFunctions.Count -gt 0) {
    $examples = ($missingFunctions | Select-Object -First 5) -join ', '
    Fail "The built PBO is missing SQF filename entries for source functions. Missing examples: $examples. In Addon Builder, set 'List of files to copy directly' to include '*.sqf;*.hpp' and rebuild addons/co_main.pbo."
}

Write-Host "[OK] Build validation passed for $pboPath"
Write-Host "[OK] Prefix bytes are exact and function filenames are present in the PBO header."