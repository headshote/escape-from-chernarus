@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM ChernOccupation - Local Dedicated Server Launcher
REM
REM Auto-detects the Arma 3 / Arma 3 Server install location across
REM common Steam library roots (any drive). You normally do NOT have
REM to edit anything: just drop @ChernOccupation into the same folder
REM as @CBA_A3 / @CUP_Terrains_* and run this .bat.
REM
REM If your Steam library lives somewhere unusual, set ARMA_OVERRIDE_*
REM below or set the same variables in your environment before running.
REM ============================================================

REM Optional manual overrides (leave blank for auto-detect).
set "ARMA_OVERRIDE_SERVER_ROOT="
set "ARMA_OVERRIDE_CLIENT_ROOT="
set "ARMA_OVERRIDE_WORKSHOP_ROOT="

REM Optional: Workshop IDs (used only if local @mod folders are missing)
set "WS_CBA=450814997"
set "WS_CUP_TERRAINS_CORE=583496184"
set "WS_CUP_TERRAINS_MAPS=583544987"

REM Network / runtime settings
set "SERVER_PORT=2302"
set "SERVER_NAME=ChernOccupation Local Dedicated"
set "SERVER_PASSWORD="
set "SERVER_ADMIN_PASSWORD=admin123"
set "MAX_PLAYERS=16"
set "MISSION_SOURCE_TEMPLATE=ChernOccupation.Chernarus"
set "MISSION_TEMPLATE=ChernOccupationLocal.Chernarus"

set "CO_MOD_ROOT=%~dp0"
if "%CO_MOD_ROOT:~-1%"=="\" set "CO_MOD_ROOT=%CO_MOD_ROOT:~0,-1%"

REM ============================================================
REM Detect Arma 3 / Arma 3 Server / dependency mods on any drive
REM (PowerShell handles spaces and parens robustly; CMD can't.)
REM ============================================================
set "DETECT_PS1=%CO_MOD_ROOT%\tools\detect_arma_paths.ps1"
if not exist "%DETECT_PS1%" (
    echo [ERROR] Missing %DETECT_PS1%
    exit /b 1
)
for /f "usebackq tokens=1,* delims==" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%DETECT_PS1%" -OverrideServerRoot "%ARMA_OVERRIDE_SERVER_ROOT%" -OverrideClientRoot "%ARMA_OVERRIDE_CLIENT_ROOT%" -OverrideWorkshopRoot "%ARMA_OVERRIDE_WORKSHOP_ROOT%"`) do (
    set "%%A=%%B"
)

if not defined SERVER_EXE (
    echo [ERROR] Could not locate arma3server_x64.exe.
    echo Either install Arma 3 / Arma 3 Server in any Steam library, or set
    echo ARMA_OVERRIDE_SERVER_ROOT / ARMA_OVERRIDE_CLIENT_ROOT in this .bat.
    exit /b 1
)

for %%I in ("%SERVER_EXE%") do set "SERVER_INSTALL_ROOT=%%~dpI"
set "SERVER_INSTALL_ROOT=%SERVER_INSTALL_ROOT:~0,-1%"

set "MOD_CO=%CO_MOD_ROOT%"

echo [INFO] Server exe : %SERVER_EXE%
echo [INFO] CBA mod    : %MOD_CBA%
echo [INFO] CUP Core   : %MOD_CUP_CORE%
echo [INFO] CUP Maps   : %MOD_CUP_MAPS%

if exist "%MOD_CO%\tools\build_addon.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%MOD_CO%\tools\build_addon.ps1" -ModRoot "%MOD_CO%" -SkipIfUpToDate
    if errorlevel 1 (
        echo [WARN] Addon rebuild step failed or skipped ^(no Arma 3 Tools?^).
        echo Falling back to existing co_main.pbo if available.
    )
)

if not exist "%MOD_CO%\addons\co_main.pbo" (
    echo [ERROR] Missing %MOD_CO%\addons\co_main.pbo
    echo Build and copy your addon PBO to @ChernOccupation\addons\co_main.pbo first.
    exit /b 1
)
if exist "%MOD_CO%\addons\main.pbo" (
    echo [ERROR] Found stale duplicate addon PBO: %MOD_CO%\addons\main.pbo
    echo Arma loads every PBO in the addons folder. Remove or rename main.pbo,
    echo then keep only co_main.pbo for this mod before launching.
    exit /b 1
)
if exist "%MOD_CO%\tools\validate_build.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%MOD_CO%\tools\validate_build.ps1" -ModRoot "%MOD_CO%"
    if errorlevel 1 exit /b 1
)
if not exist "%MOD_CBA%\addons" (
    echo [ERROR] CBA not found at: %MOD_CBA%
    exit /b 1
)
if not exist "%MOD_CUP_CORE%\addons" (
    echo [ERROR] CUP Terrains Core not found at: %MOD_CUP_CORE%
    exit /b 1
)
if not exist "%MOD_CUP_MAPS%\addons" (
    echo [ERROR] CUP Terrains Maps not found at: %MOD_CUP_MAPS%
    exit /b 1
)

REM ============================================================
REM Stage unpacked mission source into server mpmissions for local testing
REM ============================================================
if not exist "%SERVER_INSTALL_ROOT%\mpmissions" mkdir "%SERVER_INSTALL_ROOT%\mpmissions"
set "MISSION_SOURCE_DIR=%MOD_CO%\missions\%MISSION_SOURCE_TEMPLATE%"
set "MISSION_DEPLOY_DIR=%SERVER_INSTALL_ROOT%\mpmissions\%MISSION_TEMPLATE%"

if not exist "%MISSION_SOURCE_DIR%\mission.sqm" (
    echo [ERROR] Missing mission source file:
    echo   %MISSION_SOURCE_DIR%\mission.sqm
    exit /b 1
)

if exist "%MOD_CO%\tools\stage_local_mission.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%MOD_CO%\tools\stage_local_mission.ps1" -MissionSource "%MISSION_SOURCE_DIR%" -MissionDestination "%MISSION_DEPLOY_DIR%"
    if errorlevel 1 exit /b 1
)

if exist "%MOD_CO%\tools\validate_mission.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%MOD_CO%\tools\validate_mission.ps1" -MissionSource "%MISSION_SOURCE_DIR%" -MissionTarget "%MISSION_DEPLOY_DIR%"
    if errorlevel 1 exit /b 1
)

REM ============================================================
REM Write runtime config files (safe to overwrite each run)
REM ============================================================
set "RUNTIME_DIR=%CO_MOD_ROOT%\.server_runtime"
set "CFG_DIR=%RUNTIME_DIR%\cfg"
set "PROFILES_DIR=%RUNTIME_DIR%\profiles"

if not exist "%RUNTIME_DIR%" mkdir "%RUNTIME_DIR%"
if not exist "%CFG_DIR%" mkdir "%CFG_DIR%"
if not exist "%PROFILES_DIR%" mkdir "%PROFILES_DIR%"

set "SERVER_CFG=%CFG_DIR%\server.cfg"
set "BASIC_CFG=%CFG_DIR%\basic.cfg"

(
echo hostname = "%SERVER_NAME%";
echo password = "%SERVER_PASSWORD%";
echo passwordAdmin = "%SERVER_ADMIN_PASSWORD%";
echo maxPlayers = %MAX_PLAYERS%;
echo verifySignatures = 0;
echo BattlEye = 0;
echo voteMissionPlayers = 1;
echo disableVoN = 0;
echo(
echo class Missions
echo {
echo     class CO
echo     {
echo         template = "%MISSION_TEMPLATE%";
echo         difficulty = "Regular";
echo     };
echo };
) > "%SERVER_CFG%"

(
echo MaxMsgSend=256;
echo MaxSizeGuaranteed=1024;
echo MaxSizeNonguaranteed=256;
echo MinBandwidth=2147483647;
echo MaxBandwidth=2147483647;
echo MinErrorToSend=0.001;
echo MinErrorToSendNear=0.01;
) > "%BASIC_CFG%"

set "MODLIST=%MOD_CBA%;%MOD_CUP_CORE%;%MOD_CUP_MAPS%;%MOD_CO%"

echo.
echo ===========================================================
echo Starting Arma 3 Dedicated Server
echo Executable: %SERVER_EXE%
echo Mission:    %MISSION_TEMPLATE% ^(staged from %MISSION_SOURCE_TEMPLATE%^)
echo Port:       %SERVER_PORT%
echo Mods:       %MODLIST%
echo ===========================================================
echo.

start "Arma3Server-CO" /D "%SERVER_INSTALL_ROOT%" "%SERVER_EXE%" ^
    -port=%SERVER_PORT% ^
    -config="%SERVER_CFG%" ^
    -cfg="%BASIC_CFG%" ^
    -profiles="%PROFILES_DIR%" ^
    -name="CO_Local" ^
    -mod="%MODLIST%" ^
    -world=empty ^
    -autoinit ^
    -filePatching

echo.
echo Server launched. Connect client to 127.0.0.1:%SERVER_PORT%
echo Server logs: %PROFILES_DIR%\CO_Local
echo.
endlocal
