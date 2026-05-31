param(
    [string]$ModRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$SkipIfUpToDate,
    [string]$ToolsDirectory = ''
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
# Auto-detect Arma 3 Tools if not explicitly provided
if (-not $ToolsDirectory) {
    function Get-SteamLibraryRoots-Build {
        $roots = New-Object System.Collections.Generic.List[string]
        foreach ($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
            try {
                $val = Get-ItemProperty -Path $key -ErrorAction Stop
                $p = if ($val.SteamPath) { $val.SteamPath } elseif ($val.InstallPath) { $val.InstallPath } else { $null }
                if ($p) { $roots.Add(($p -replace '/','\'). TrimEnd('\')) }
                $vdf = Join-Path ($p -replace '/','\'). TrimEnd('\') 'steamapps\libraryfolders.vdf'
                if ($vdf -and (Test-Path $vdf)) {
                    $c = Get-Content -Raw $vdf
                    foreach ($m in [regex]::Matches($c, '"path"\s*"([^"]+)"')) {
                        $roots.Add(($m.Groups[1].Value -replace '\\\\','\').TrimEnd('\'))
                    }
                }
                break
            } catch {}
        }
        foreach ($d in @('C:\Steam','C:\Program Files (x86)\Steam','C:\Program Files\Steam','D:\Steam','D:\SteamLibrary','D:\steamlibrary','E:\Steam','E:\SteamLibrary','F:\Steam','F:\SteamLibrary')) {
            if (Test-Path $d) { $roots.Add($d.TrimEnd('\')) }
        }
        $seen = @{}; $u = New-Object System.Collections.Generic.List[string]
        foreach ($r in $roots) { $k = $r.ToLowerInvariant(); if (-not $seen[$k]) { $seen[$k]=$true; $u.Add($r) } }
        return $u
    }
    foreach ($lib in (Get-SteamLibraryRoots-Build)) {
        $candidate = Join-Path $lib 'steamapps\common\Arma 3 Tools'
        if (Test-Path (Join-Path $candidate 'AddonBuilder\AddonBuilder.exe')) {
            $ToolsDirectory = $candidate; break
        }
    }
}

$builderPath = Join-Path $ToolsDirectory 'AddonBuilder\AddonBuilder.exe'

if (!(Test-Path -LiteralPath $builderPath)) {
    Fail "Addon Builder not found at: $builderPath`nInstall 'Arma 3 Tools' via Steam (Tools library) or set -ToolsDirectory explicitly."
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