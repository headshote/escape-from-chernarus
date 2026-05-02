param(
    [string]$ModRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Fail {
    param([string]$Message)

    Write-Error $Message
    exit 1
}

function Get-PboPrefix {
    param([byte[]]$Bytes)

    $sampleLength = [Math]::Min($Bytes.Length, 4096)
    $sample = $Bytes[0..($sampleLength - 1)]
    $text = [System.Text.Encoding]::ASCII.GetString($sample)
    $tokens = $text -split "`0+" | Where-Object { $_.Length -gt 0 }

    for ($index = 0; $index -lt ($tokens.Count - 1); $index++) {
        if ($tokens[$index] -eq 'prefix') {
            return $tokens[$index + 1]
        }
    }

    return $null
}

$addonRoot = Join-Path $ModRoot 'addons'
$sourceRoot = Join-Path $addonRoot 'main'
$pboPath = Join-Path $addonRoot 'co_main.pbo'
$duplicatePboPath = Join-Path $addonRoot 'main.pbo'
$prefixPath = Join-Path $sourceRoot '$PBOPREFIX$'
$functionsPath = Join-Path $sourceRoot 'functions'
$configPath = Join-Path $sourceRoot 'config.cpp'

if (!(Test-Path -LiteralPath $pboPath)) {
    Fail "Missing addon PBO: $pboPath"
}

if (Test-Path -LiteralPath $duplicatePboPath) {
    Fail "Stale duplicate addon PBO detected: $duplicatePboPath"
}

if (!(Test-Path -LiteralPath $prefixPath)) {
    Fail "Missing PBO prefix file: $prefixPath"
}

$expectedPrefixText = 'main'
$expectedPrefix = [System.Text.Encoding]::ASCII.GetBytes($expectedPrefixText)
$actualPrefix = [System.IO.File]::ReadAllBytes($prefixPath)
if ($actualPrefix.Length -ne $expectedPrefix.Length -or (@($actualPrefix) -join ',') -ne (@($expectedPrefix) -join ',')) {
    Fail "`$PBOPREFIX$ must contain exactly '$expectedPrefixText' with no BOM, newline, or extra whitespace."
}

$sourceFunctions = Get-ChildItem -LiteralPath $functionsPath -Filter 'fn_*.sqf' | Sort-Object Name
if ($sourceFunctions.Count -eq 0) {
    Fail "No function source files were found under $functionsPath"
}

$sourceArtifacts = @(
    Get-ChildItem -LiteralPath $functionsPath -File -Recurse
    Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'ui') -File -Recurse -ErrorAction SilentlyContinue
    Get-Item -LiteralPath $configPath
    Get-Item -LiteralPath $prefixPath
)

$pboLength = (Get-Item -LiteralPath $pboPath).Length
if ($pboLength -lt 65536) {
    Write-Warning "The built PBO is unusually small ($pboLength bytes). Validate that Addon Builder copied the SQF sources."
}

$pboItem = Get-Item -LiteralPath $pboPath
$newestSource = $sourceArtifacts | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($newestSource.LastWriteTime -gt $pboItem.LastWriteTime) {
    Fail "The addon source is newer than addons/co_main.pbo (latest source: $($newestSource.FullName) at $($newestSource.LastWriteTime)). Rebuild the addon before launching the server or client."
}

$pboBytes = [System.IO.File]::ReadAllBytes($pboPath)
$embeddedPrefix = Get-PboPrefix -Bytes $pboBytes
if ($embeddedPrefix -ne $expectedPrefixText) {
    Fail "The built PBO prefix is '$embeddedPrefix'. Expected '$expectedPrefixText'. Rebuild the addon with the correct prefix before launching Arma."
}

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

$configText = Get-Content -LiteralPath $configPath -Raw
if ($configText -notmatch 'file\s*=\s*"\\main\\functions"\s*;') {
    Fail "CfgFunctions in $configPath must use file = \"\\main\\functions\"; to match the packed addon prefix."
}
if ($configText -notmatch 'class\s+CfgFunctions\s*\{[\s\S]*?class\s+co_main\s*\{[\s\S]*?class\s+Main\s*\{') {
    Fail "CfgFunctions in $configPath must register functions under the co_main tag so runtime calls to co_main_fnc_* resolve correctly."
}

$missingFunctions = $sourceFunctions |
    Where-Object { -not $pboText.Contains($_.Name) } |
    Select-Object -ExpandProperty Name

if ($missingFunctions.Count -gt 0) {
    $examples = ($missingFunctions | Select-Object -First 5) -join ', '
    Fail "The built PBO is missing SQF filename entries for source functions. Missing examples: $examples. In Addon Builder, set 'List of files to copy directly' to include '*.sqf;*.hpp' and rebuild addons/co_main.pbo."
}

Write-Host "[OK] Build validation passed for $pboPath"
Write-Host "[OK] Embedded prefix, source prefix, config function path, and function filenames all match."