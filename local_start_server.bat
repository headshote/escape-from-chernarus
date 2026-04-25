@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM ChernOccupation - Local Dedicated Server Launcher
REM ============================================================
REM Edit only these paths if needed.
set "ARMA_SERVER_ROOT=C:\Steam\steamapps\common\Arma 3 Server"
set "ARMA_CLIENT_ROOT=C:\Steam\steamapps\common\Arma 3"
set "WORKSHOP_ROOT=C:\Steam\steamapps\workshop\content\107410"
set "CO_MOD_ROOT=%~dp0"
if "%CO_MOD_ROOT:~-1%"=="\" set "CO_MOD_ROOT=%CO_MOD_ROOT:~0,-1%"

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
set "MISSION_PBO=ChernOccupation.Chernarus.pbo"
set "MISSION_TEMPLATE=ChernOccupation.Chernarus"

REM ============================================================
REM Resolve server executable
REM ============================================================
set "SERVER_EXE=%ARMA_SERVER_ROOT%\arma3server_x64.exe"
if not exist "%SERVER_EXE%" (
    set "SERVER_EXE=%ARMA_CLIENT_ROOT%\arma3server_x64.exe"
)
if not exist "%SERVER_EXE%" (
    echo [ERROR] Could not find arma3server_x64.exe
    echo Checked:
    echo   %ARMA_SERVER_ROOT%\arma3server_x64.exe
    echo   %ARMA_CLIENT_ROOT%\arma3server_x64.exe
    echo Update ARMA_SERVER_ROOT / ARMA_CLIENT_ROOT in this .bat.
    exit /b 1
)

for %%I in ("%SERVER_EXE%") do set "SERVER_INSTALL_ROOT=%%~dpI"
set "SERVER_INSTALL_ROOT=%SERVER_INSTALL_ROOT:~0,-1%"

REM ============================================================
REM Resolve dependency mod paths
REM ============================================================
set "MOD_CBA=%ARMA_CLIENT_ROOT%\@CBA_A3"
set "MOD_CUP_CORE=%ARMA_CLIENT_ROOT%\@CUP_Terrains_Core"
set "MOD_CUP_MAPS=%ARMA_CLIENT_ROOT%\@CUP_Terrains_Maps"
set "MOD_CO=%CO_MOD_ROOT%"

if not exist "%MOD_CBA%\addons" set "MOD_CBA=%WORKSHOP_ROOT%\%WS_CBA%"
if not exist "%MOD_CUP_CORE%\addons" set "MOD_CUP_CORE=%WORKSHOP_ROOT%\%WS_CUP_TERRAINS_CORE%"
if not exist "%MOD_CUP_MAPS%\addons" set "MOD_CUP_MAPS=%WORKSHOP_ROOT%\%WS_CUP_TERRAINS_MAPS%"

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
REM Ensure mission PBO exists in server mpmissions
REM ============================================================
if not exist "%SERVER_INSTALL_ROOT%\mpmissions" mkdir "%SERVER_INSTALL_ROOT%\mpmissions"
if not exist "%SERVER_INSTALL_ROOT%\mpmissions\%MISSION_PBO%" (
    echo [ERROR] Missing mission PBO:
    echo   %SERVER_INSTALL_ROOT%\mpmissions\%MISSION_PBO%
    echo Build mission from missions\ChernOccupation.Chernarus and copy it there.
    exit /b 1
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
echo Mission:    %MISSION_TEMPLATE%
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
