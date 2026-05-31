# Running ChernOccupation on a separate LAN server laptop

This guide assumes the second machine has **no Arma 3 game client** — only the
free **Arma 3 Dedicated Server** tool from Steam. The launcher auto-detects the
install no matter which drive Steam lives on (e.g. `D:\steamlibrary`).

---

## 1. Install prerequisites on the LAN laptop

1. Install Steam (any drive).
2. In Steam, install the free dedicated server:
   `Library → Tools → Arma 3 Server` (App ID `233780`).
   Pick whichever Steam library you want — `D:\steamlibrary` is fine.
3. Subscribe to the three required mods on Steam Workshop with your Steam
   account (or use any other delivery method — see below):
   - **CBA_A3** — `https://steamcommunity.com/sharedfiles/filedetails/?id=450814997`
   - **CUP Terrains – Core** — `https://steamcommunity.com/sharedfiles/filedetails/?id=583496184`
   - **CUP Terrains – Maps** — `https://steamcommunity.com/sharedfiles/filedetails/?id=583544987`

   Workshop content lands in
   `<library>\steamapps\workshop\content\107410\<id>\` and the launcher will
   pick it up automatically.

   > Workshop only delivers to *the game client*. If you don't own / install
   > Arma 3 (the game) on this laptop, you have two clean options:
   > - **Recommended:** Copy the three `@CBA_A3`, `@CUP_Terrains_Core`,
   >   `@CUP_Terrains_Maps` folders from any machine that already has them and
   >   drop them next to `arma3server_x64.exe` (i.e. inside
   >   `...\steamapps\common\Arma 3 Server\`). The launcher searches there.
   > - Use SteamCMD's `workshop_download_item` to fetch the IDs above into the
   >   server's library — same final layout.

## 2. Copy the mod onto the laptop

Copy the entire `@ChernOccupation` folder (this whole repo) anywhere on the
laptop. A natural choice is right next to the server install:

```
D:\steamlibrary\steamapps\common\Arma 3 Server\@ChernOccupation\
```

…but it can live anywhere — `local_start_server.bat` resolves its own location.

The folder must contain at minimum:
- `addons\co_main.pbo` (the prebuilt mod — already in this repo)
- `local_start_server.bat`
- `tools\detect_arma_paths.ps1`
- `missions\ChernOccupation.Chernarus\` (mission source)

You do **not** need Arma 3 Tools on the laptop — the launcher will skip the
rebuild step with a warning if Tools is missing and use the existing PBO.

## 3. Configure (optional)

Open `local_start_server.bat` in a text editor. The defaults are sensible.
Override only if your install lives somewhere unusual:

```bat
set "ARMA_OVERRIDE_SERVER_ROOT="     :: e.g. D:\Games\Arma3Server
set "ARMA_OVERRIDE_CLIENT_ROOT="
set "ARMA_OVERRIDE_WORKSHOP_ROOT="
set "ADMIN_PASSWORD=admin123"        :: change before going live
set "SERVER_PASSWORD="               :: empty = open server
set "SERVER_PORT=2302"
set "SERVER_NAME=ChernOccupation - Local LAN"
```

Auto-detection order (you don't need to do anything for this to work):
1. `ARMA_OVERRIDE_*` if you set them.
2. Steam install from registry (`HKCU\Software\Valve\Steam\SteamPath`).
3. All Steam libraries listed in `steamapps\libraryfolders.vdf`.
4. Common fallback drives: `C:\Steam`, `C:\Program Files (x86)\Steam`,
   `D:\Steam`, `D:\SteamLibrary`, `D:\steamlibrary`, `E:\Steam`, etc.

For each candidate it looks for:
- `<lib>\steamapps\common\Arma 3 Server\arma3server_x64.exe` (preferred), or
- `<lib>\steamapps\common\Arma 3\arma3server_x64.exe` (game install fallback).

Dependency mods are searched next to the server install, next to the game
install, and finally inside `steamapps\workshop\content\107410\<id>\`.

## 4. Start the server

```cmd
cd /d <wherever you put it>\@ChernOccupation
local_start_server.bat
```

You should see:
```
[INFO] Server exe : ...arma3server_x64.exe
[INFO] CBA mod    : ...
[INFO] CUP Core   : ...
[INFO] CUP Maps   : ...
[OK] Build validation passed for ...co_main.pbo
[OK] Staged local mission folder ...
===========================================================
Starting Arma 3 Dedicated Server
===========================================================
Server launched. Connect client to 127.0.0.1:2302
```

A second window opens running `arma3server_x64.exe` — that is the live server.

Live RPT log: `@ChernOccupation\.server_runtime\profiles\arma3server_x64_*.rpt`

## 5. Network setup (LAN only)

Find the laptop's LAN IP:
```powershell
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -eq 'Dhcp' -or $_.PrefixOrigin -eq 'Manual' }
```
Typical result: `192.168.1.42` etc.

Open these UDP ports on the Windows firewall (run PowerShell as admin on the
laptop):
```powershell
New-NetFirewallRule -DisplayName "Arma 3 Server UDP" -Direction Inbound -Protocol UDP -LocalPort 2302-2306 -Action Allow
```

Connect from another LAN PC running the Arma 3 client:
- `Multiplayer → Direct Connect → 192.168.1.42 : 2302`
- The client must have **the same three mods** loaded
  (`@CBA_A3;@CUP_Terrains_Core;@CUP_Terrains_Maps;@ChernOccupation`).
- Admin login at the in-game chat: `#login admin123`

## 6. Updating the mod

Whenever you change SQF / config on your dev box:
1. Run `tools\build_addon.ps1` on the dev box (rebuilds `co_main.pbo`).
2. Copy the updated `@ChernOccupation` folder to the LAN laptop (or just the
   `addons\co_main.pbo` and `missions\` subfolder if mission changed).
3. Restart the server window on the laptop.

`local_start_server.bat` re-stages the mission and re-validates the PBO every
launch, so step-3 alone is enough as long as the files on disk are current.

## 7. Troubleshooting

- **`[ERROR] Could not locate arma3server_x64.exe`** – Either Arma 3 Server is
  not installed on any detected library, or it is in an unusual location. Set
  `ARMA_OVERRIDE_SERVER_ROOT` at the top of `local_start_server.bat`.
- **Mod missing / "you cannot play this mission, dependent on … deleted"** –
  One of `@CBA_A3 / @CUP_Terrains_Core / @CUP_Terrains_Maps` was not found on
  disk. Verify with:
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\detect_arma_paths.ps1
  ```
  Any blank `MOD_*` line means that mod isn't where the script looked.
- **Clients can't see / join the server on the LAN** – firewall is the usual
  culprit. Re-check the UDP 2302–2306 rule is enabled for the active network
  profile (Private vs Public).
- **`AddonBuilder failed`** – Only matters if you're rebuilding on the laptop.
  On a server-only laptop without Arma 3 Tools, the launcher just warns and
  uses the prebuilt PBO that already shipped in `addons\co_main.pbo`.
