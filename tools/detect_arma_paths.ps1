# tools/detect_arma_paths.ps1
# Locates Arma 3 / Arma 3 Server installs and dependency mods across every
# Steam library on the machine, regardless of drive letter.
#
# Outputs KEY=VALUE lines that the launcher .bat consumes via `for /f`.

[CmdletBinding()]
param(
    [string]$OverrideServerRoot,
    [string]$OverrideClientRoot,
    [string]$OverrideWorkshopRoot,
    [string[]]$ExtraDependencyNames = @('@CBA_A3','@CUP_Terrains_Core','@CUP_Terrains_Maps'),
    [hashtable]$DependencyWorkshopIds = @{
        '@CBA_A3'             = '450814997'
        '@CUP_Terrains_Core'  = '583496184'
        '@CUP_Terrains_Maps'  = '583544987'
    }
)

$ErrorActionPreference = 'Continue'

function Get-SteamInstallPath {
    foreach ($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
        try {
            $val = (Get-ItemProperty -Path $key -ErrorAction Stop)
            if ($val.SteamPath)    { return ($val.SteamPath    -replace '/','\').TrimEnd('\') }
            if ($val.InstallPath)  { return ($val.InstallPath  -replace '/','\').TrimEnd('\') }
        } catch { }
    }
    return $null
}

function Get-SteamLibraryRoots {
    $roots = New-Object System.Collections.Generic.List[string]
    $steam = Get-SteamInstallPath
    if ($steam) { $roots.Add($steam) }

    $vdf = if ($steam) { Join-Path $steam 'steamapps\libraryfolders.vdf' } else { $null }
    if ($vdf -and (Test-Path $vdf)) {
        $content = Get-Content -Raw -Path $vdf
        # libraryfolders.vdf has lines like:   "path"    "D:\\SteamLibrary"
        $matches = [regex]::Matches($content, '"path"\s*"([^"]+)"')
        foreach ($m in $matches) {
            $p = $m.Groups[1].Value -replace '\\\\','\'
            if ($p) { $roots.Add($p.TrimEnd('\')) }
        }
    }

    # Add common defaults so we still work when registry data is missing
    $defaults = @(
        'C:\Steam','C:\Program Files (x86)\Steam','C:\Program Files\Steam',
        'D:\Steam','D:\SteamLibrary','D:\steamlibrary',
        'E:\Steam','E:\SteamLibrary','F:\Steam','F:\SteamLibrary'
    )
    foreach ($d in $defaults) { if (Test-Path $d) { $roots.Add($d.TrimEnd('\')) } }

    # Deduplicate (case-insensitive)
    $seen = @{}
    $unique = New-Object System.Collections.Generic.List[string]
    foreach ($r in $roots) {
        $key = $r.ToLowerInvariant()
        if (-not $seen.ContainsKey($key)) { $seen[$key] = $true; $unique.Add($r) }
    }
    return $unique
}

function First-Existing {
    param([string[]]$Candidates)
    foreach ($c in $Candidates) { if ($c -and (Test-Path $c)) { return $c } }
    return $null
}

$libs = Get-SteamLibraryRoots

# Build candidate lists for server / client / workshop
$serverCandidates  = $libs | ForEach-Object { Join-Path $_ 'steamapps\common\Arma 3 Server\arma3server_x64.exe' }
$clientCandidates  = $libs | ForEach-Object { Join-Path $_ 'steamapps\common\Arma 3' }
$workshopCandidates= $libs | ForEach-Object { Join-Path $_ 'steamapps\workshop\content\107410' }

# Resolve server exe
$serverExe = $null
if ($OverrideServerRoot -and (Test-Path (Join-Path $OverrideServerRoot 'arma3server_x64.exe'))) {
    $serverExe = Join-Path $OverrideServerRoot 'arma3server_x64.exe'
} else {
    $serverExe = First-Existing $serverCandidates
}

# Resolve client root (game client install). May be missing on a server-only laptop.
$clientRoot = $null
if ($OverrideClientRoot -and (Test-Path $OverrideClientRoot)) {
    $clientRoot = $OverrideClientRoot
} else {
    foreach ($c in $clientCandidates) {
        if ((Test-Path (Join-Path $c 'arma3.exe')) -or (Test-Path (Join-Path $c 'arma3server_x64.exe'))) {
            $clientRoot = $c; break
        }
    }
}

# If we still have no server exe but the client root exposes one, use that
if (-not $serverExe -and $clientRoot -and (Test-Path (Join-Path $clientRoot 'arma3server_x64.exe'))) {
    $serverExe = Join-Path $clientRoot 'arma3server_x64.exe'
}

# Workshop content dir
$workshopRoot = $null
if ($OverrideWorkshopRoot -and (Test-Path $OverrideWorkshopRoot)) {
    $workshopRoot = $OverrideWorkshopRoot
} else {
    $workshopRoot = First-Existing $workshopCandidates
}

# Server install root (folder containing the exe)
$serverInstallRoot = $null
if ($serverExe) { $serverInstallRoot = Split-Path -Parent $serverExe }

# Resolve dependency @-folders. Search:
# 1) Override directories (none here per-mod, but server/client roots act as home)
# 2) Server install root
# 3) Client install root
# 4) Every Steam library /common/Arma 3 (Server) folder
# 5) Workshop fallback by ID
function Resolve-Dependency {
    param([string]$Name, [string]$WorkshopId)

    $candidates = New-Object System.Collections.Generic.List[string]
    if ($serverInstallRoot) { $candidates.Add((Join-Path $serverInstallRoot $Name)) }
    if ($clientRoot)        { $candidates.Add((Join-Path $clientRoot $Name)) }
    foreach ($lib in $libs) {
        $candidates.Add((Join-Path $lib "steamapps\common\Arma 3 Server\$Name"))
        $candidates.Add((Join-Path $lib "steamapps\common\Arma 3\$Name"))
    }
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c 'addons')) { return $c.TrimEnd('\') }
    }
    # Workshop fallback (often without leading @)
    if ($workshopRoot -and $WorkshopId) {
        $wsPath = Join-Path $workshopRoot $WorkshopId
        if (Test-Path (Join-Path $wsPath 'addons')) { return $wsPath.TrimEnd('\') }
    }
    return $null
}

$cba   = Resolve-Dependency '@CBA_A3'            $DependencyWorkshopIds['@CBA_A3']
$cupC  = Resolve-Dependency '@CUP_Terrains_Core' $DependencyWorkshopIds['@CUP_Terrains_Core']
$cupM  = Resolve-Dependency '@CUP_Terrains_Maps' $DependencyWorkshopIds['@CUP_Terrains_Maps']

# Emit KEY=VALUE for the launcher to consume
function Emit { param($k,$v) if ($v) { "$k=$v" } else { "$k=" } }

Emit 'SERVER_EXE'         $serverExe
Emit 'SERVER_INSTALL_ROOT' $serverInstallRoot
Emit 'ARMA_SERVER_ROOT'   $serverInstallRoot
Emit 'ARMA_CLIENT_ROOT'   $clientRoot
Emit 'WORKSHOP_ROOT'      $workshopRoot
Emit 'MOD_CBA'            $cba
Emit 'MOD_CUP_CORE'       $cupC
Emit 'MOD_CUP_MAPS'       $cupM
