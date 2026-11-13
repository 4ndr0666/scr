# Ψ `svp-cli` (`v3.2.0`) — Standalone Apple TV SVPlayer Controller, Recovery Engine & JS Injector

`svp-cli` (typically installed as `svp-cli` and symlinked to `svp`) is a standalone CLI and interactive TUI controller for the embedded HTTP REST API (`/r/*`) exposed by [SVPlayer TV](https://www.svp-team.com/wiki/Manual:SVPcast) on an **Apple TV HD (4th Generation, `AppleTV5,3`)**. It handles direct URL casting, multipart media/subtitle uploads with progress bars, zero-copy LAN streaming via `mkplaylist` + Caddy, hardware-tuned `mpv.conf` deployment, 1-second restoration of [SVPlayer for Nerds](https://www.svp-team.com/wiki/SVPlayer_for_Nerds) settings after tvOS `cache_delete` purges, Browser DevTools Console JS snippet generation, systemd auto-heal watchdog timers, network share management, and port `62078/tcp` (`lockdownd`) security auditing.

## Overview of Contents

1. Hardware & tvOS Sandbox Context (`AppleTV5,3` @ `192.168.1.211`)
2. Reverse-Engineered SVPlayer `/r/*` REST API Specification
3. Installation, Environment Variables & Authenticated Gateway Routing
4. Complete Subcommand Reference (`play`, `cast-local`, `m3u8`, `upload`, `clear`, `conf`, `nerd`, `js`, `heal`, `install-watchdog`, `share`, `report`, `log`, `audit`)
5. Defeating tvOS `cache_delete` Resets (`svp-cli heal` & `svp-cli nerd`)
6. Hardware-Tuned `mpv.conf` for Apple A8 (`2017 MB RAM`)
7. Browser DevTools Console JS Injector (`svp-cli js`)
8. Automated Systemd User Watchdog (`svp-cli install-watchdog`)
9. Seamless Integration with Standalone `M3` and `mkplaylist`
10. Security Audit Subcommand (`svp-cli audit` & Port `62078/tcp`)
11. Interactive TUI Command Deck
12. Troubleshooting & Operational Edge Cases

## 1. Hardware & tvOS Sandbox Context (`AppleTV5,3` @ `192.168.1.211`)

Telemetry extracted directly from `192.168.1.211` runtime logs:

* **Device Model:** `AppleTV5,3` (Apple TV HD, 4th Generation)
* **SoC & CPU:** Apple A8 (`2 cores, 2288 MHz base`)
* **GPU & Render API:** Apple A8 GPU via MoltenVK (`VK 1.2, drv 0.2.2010`)
* **Memory Envelope:** `2017 MB total` (~`186 MB free` during active `libmpv` + FRC interpolation)
* **Display Modes:** `1920x1080 [x2.0, 96 dpi] @ 24, 25, 30, 50, 60* Hz` (with Automatic Frame Rate switching)
* **Sandbox Working Directory:** `/var/mobile/Containers/Data/Application/<UUID>/Library/Caches/SVPlayer/`

Because Apple prohibits tvOS applications from storing persistent files on disk outside of `NSUserDefaults`, SVPlayer stores `main.cfg`, `frc.cfg`, `profiles.cfg`, `browser.cfg`, `history.cfg`, `mpv.conf`, and `uploads/` inside `/Library/Caches/SVPlayer/`. Whenever tvOS reclaims cache space via `cache_delete`, all settings reset to defaults unless backed up and restored by `svp-cli`.

## 2. Reverse-Engineered SVPlayer `/r/*` REST API Specification

| Endpoint | HTTP Method | Query / Form Parameters | `svp-cli` Subcommand | Description |
| :--- | :--- | :--- | :--- | :--- |
| **`/r/play`** | `GET` | `url=<encoded_url>` | `svp-cli play <url>` | Immediately loads and plays any `.m3u8`, `.m3u`, `.mp4`, or `.mkv` HTTP stream in `mpv`. |
| **`/r/upload`** | `POST` | `multipart/form-data` (`file=@...`) | `svp-cli upload <file...>` | Uploads video or subtitle files into `/Library/Caches/SVPlayer/uploads/`. |
| **`/r/upload-clear`** | `GET` | *None* | `svp-cli clear` | Purges all uploaded media from `/Library/Caches/SVPlayer/uploads/`. |
| **`/r/mpvc`** | `GET` | *None* | `svp-cli conf pull` | Returns JSON `{"conf": "..."}` containing the active `mpv.conf`. |
| **`/r/mpvc`** | `POST` | `conf=<string>` | `svp-cli conf push\|optimal\|edit` | Overwrites `mpv.conf` on the Apple TV. |
| **`/r/settings`** | `GET` | *None* | `svp-cli nerd dump` | Returns JSON of all advanced "SVPlayer for Nerds" configuration keys. |
| **`/r/set-opt`** | `POST` | `n=<key>&v=<value>` | `svp-cli nerd set\|restore\|preset` | Modifies a single setting in `main.cfg` / `frc.cfg` and returns updated JSON. |
| **`/r/log`** | `GET` | `last=<int>` | `svp-cli log [-f]` | Polls runtime log lines newer than `last` (`0` fetches full log history). |
| **`/r/loc`** | `GET` | *None* | `svp-cli share list` | Lists configured network shares (`0`=SMB, `1`=WebDAV, `2`=FTP, `3`=Plex, `4`=Other). |
| **`/r/loc-add`** | `POST` | `n=<type>&t=<title>&u=<url>` | `svp-cli share add <t> <name> <url>` | Registers a new network share in `browser.cfg`. |
| **`/r/loc-del`** | `POST` | `n=<id>` | `svp-cli share del <id>` | Removes a saved network share by ID. |
| **`/r/report`** | `POST` | `m=<message>&e=<email>` | `svp-cli report <msg> [email]` | Sends a diagnostic report via SVPlayer's reporting endpoint. |

## 3. Installation, Environment Variables & Authenticated Gateway Routing

Install `svp-cli` and create the `svp` shorthand symlink:

```bash
install -Dm755 ./svp-cli ~/.local/bin/svp-cli
ln -sf ~/.local/bin/svp-cli ~/.local/bin/svp
```

### Environment Variables

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| **`SVP_HOST`** | `http://192.168.1.211` | Target Apple TV URL, or your Basic-Auth-protected `mkcaddy.sh -p svp-gateway` URL (e.g., `http://andro:SecretPass@127.0.0.1:8090`). |
| **`SVP_STREAM_DIR`** | `$HOME/streamdir` | Directory used for extracted streams when calling `svp-cli m3u8`. |
| **`SVP_CADDY_PORT`** | `3000` | Local Caddy port used by `svp-cli cast-local`. |
| **`XDG_CONFIG_HOME`** | `$HOME/.config` | Base directory for `~/.config/svp/{mpv.conf,nerd-settings.json,svp-nerd-injector.js}`. |

## 4. Complete Subcommand Reference

### A. Playback & Casting (`play`, `cast-local`, `m3u8`, `upload`, `clear`)

```bash
# 1. Cast an external .m3u8 or local Caddy .m3u URL directly to Apple TV:
svp-cli play "http://192.168.1.100:3000/playlist.m3u"

# 2. Zero-copy LAN cast a local video file or entire directory (uses mkplaylist + Caddy):
svp-cli cast-local /Nas/Nas/Movies/Interstellar.mkv
svp-cli cast-local /Nas/Nas/Clips/

# 3. Extract an external .m3u8 via standalone M3 (N_m3u8DL-RE) and auto-cast over LAN:
svp-cli m3u8 --cast -t 16 -r 5 -o live_match "https://cdn.example.com/master.m3u8"

# 4. Extract an external .m3u8 via standalone M3 and upload the MP4 to Apple TV cache:
svp-cli m3u8 --up -o clip "https://cdn.example.com/clip.m3u8"

# 5. Upload one or more local media + sidecar subtitle files with live progress bar:
svp-cli upload movie.mp4 movie.srt

# 6. Clear all uploaded files from /Library/Caches/SVPlayer/uploads/:
svp-cli clear
```

### B. `mpv.conf` Configuration Management (`conf`)

```bash
# Pull the active mpv.conf from Apple TV and save to ~/.config/svp/mpv.conf:
svp-cli conf pull

# Push the built-in Apple A8 (2GB RAM) hardware-tuned mpv.conf to Apple TV:
svp-cli conf optimal

# Push a custom mpv.conf file to Apple TV:
svp-cli conf push /path/to/custom-mpv.conf

# Edit the live Apple TV mpv.conf in $EDITOR (vim/nano) and push on save:
svp-cli conf edit
```

### C. "SVPlayer for Nerds" Settings Management (`nerd`, `js`, `heal`)

```bash
# Snapshot all current /r/settings from Apple TV to ~/.config/svp/nerd-settings.json:
svp-cli nerd dump

# Restore all settings from ~/.config/svp/nerd-settings.json back to Apple TV:
svp-cli nerd restore

# Apply the built-in Apple A8 60fps FRC Nerd Preset without needing a prior dump:
svp-cli nerd preset

# Modify a single Nerd setting key/value:
svp-cli nerd set main.setup.frc.profile 12

# Generate the Browser DevTools Console JS Injector and copy to clipboard:
svp-cli js

# 1-Command Full Recovery (clear cache + push optimal mpv.conf + restore Nerd settings):
svp-cli heal
```

### D. Telemetry, Shares & Security Auditing (`log`, `share`, `report`, `audit`, `install-watchdog`)

```bash
# Dump full SVPlayer runtime log as formatted JSON:
svp-cli log

# Live-tail SVPlayer logs continuously in your terminal (polls every 2s):
svp-cli log -f

# List, add, or remove network shares (0=SMB, 1=WebDAV, 2=FTP, 3=Plex):
svp-cli share list
svp-cli share add 1 "Local Caddy WebDAV" "http://192.168.1.100:8080/dav"
svp-cli share del 1

# Install and enable the 5-minute systemd user auto-heal timer:
svp-cli install-watchdog

# Scan Apple TV open ports (80, 49152, 49153, 62078) and probe lockdownd metadata:
svp-cli audit
```

## 5. Defeating tvOS `cache_delete` Resets (`svp-cli heal` & `svp-cli nerd`)

1. Configure SVPlayer on your Apple TV once as desired.
2. Run `svp-cli conf pull && svp-cli nerd dump` on `theworkpc`. This writes `~/.config/svp/mpv.conf` and `~/.config/svp/nerd-settings.json`.
3. Whenever tvOS wipes `/Library/Caches/SVPlayer/`, run `svp-cli heal`. In under 1 second, `svp-cli`:
   * Calls `/r/upload-clear` to free purgeable cache storage.
   * Pushes your hardware-tuned `mpv.conf` to `/r/mpvc`.
   * Iterates through every key in `nerd-settings.json` and posts it to `/r/set-opt`.
   * Regenerates `~/.config/svp/svp-nerd-injector.js` so your browser console snippet stays synchronized.

## 6. Hardware-Tuned `mpv.conf` for Apple A8 (`2017 MB RAM`)

Running `svp-cli conf optimal` writes and pushes the following configuration tailored to the `AppleTV5,3` hardware profile:

```ini
# === Ψ-4ndr0666 AppleTV5,3 (A8 2GB RAM) Hardened Config ===
# 1. Strictly RAM-only Cache (prevents tvOS eMMC wear & cache_delete resets)
cache=yes
cache-on-disk=no
cache-pause=yes
cache-pause-initial=yes
cache-pause-wait=3
cache-secs=15
demuxer-max-bytes=220MiB
demuxer-max-back-bytes=40MiB
demuxer-readahead-secs=12

# 2. HLS / M3U8 & Caddy LAN Stream Resilience
network-timeout=15
stream-lavf-o=reconnect=1,reconnect_streamed=1,reconnect_delay_max=4
hls-bitrate=max
prefetch-playlist=yes
tls-verify=no
user-agent="Mozilla/5.0 (X11; Linux x86_64; rv:135.0) Gecko/20100101 Firefox/135.0"

# 3. Apple A8 Hardware Decode & MoltenVK Render Sync
hwdec=videotoolbox-copy
video-sync=display-resample
framedrop=vo
vd-lavc-threads=2
ad-lavc-threads=2
sub-auto=fuzzy
```

## 7. Browser DevTools Console JS Injector (`svp-cli js`)

Running `svp-cli js` reads your `~/.config/svp/nerd-settings.json` snapshot (or falls back to the built-in A8 preset), emits a self-executing JavaScript IIFE to `~/.config/svp/svp-nerd-injector.js`, prints it to `stdout`, and copies it to your Wayland (`wl-copy`) or X11 (`xclip`) clipboard. Paste it into your browser's DevTools Console (`F12`) on `http://192.168.1.211/` to restore both `mpv.conf` and all Nerd settings from the browser.

## 8. Automated Systemd User Watchdog (`svp-cli install-watchdog`)

Running `svp-cli install-watchdog` creates `~/.config/systemd/user/svp-autoheal.service` and `~/.config/systemd/user/svp-autoheal.timer`. Every 5 minutes, it checks `GET /r/mpvc`: if `.conf` was wiped (<20 bytes) by tvOS `cache_delete`, it automatically executes `svp-cli heal`.

## 9. Seamless Integration with Standalone `M3` and `mkplaylist`

* When `svp-cli m3u8` is invoked, `resolve_m3_script()` checks for the standalone `M3` binary in the script's directory and in `PATH`, forwarding all thread, retry, output, `--live`, `--cast`, and `--upload` flags directly to `M3`.
* When `svp-cli cast-local <directory>` is invoked, it automatically invokes `mkplaylist -n -t videos -s date -o desc -a :3000 -S <directory>` to build a LAN-URL playlist and cast it to the Apple TV.

## 10. Security Audit Subcommand (`svp-cli audit` & Port `62078/tcp`)

Running `svp-cli audit` runs `nmap -sV -p 80,49152,49153,62078` against the Apple TV IP and, if `libimobiledevice` (`ideviceinfo`) is installed, queries `62078/tcp` (`lockdownd`) with `ideviceinfo -n` to verify what unauthenticated device metadata is exposed over the LAN.

## 11. Interactive TUI Command Deck

Run `svp-cli` with no arguments to open the interactive TUI menu covering direct URL casting, `M3` extraction + LAN casting/uploading, `mkplaylist` directory casting, 1-click `heal`, JS snippet generation, live log tailing, and systemd watchdog installation.

## 12. Troubleshooting & Operational Edge Cases

| Issue | Root Cause | Resolution |
| :--- | :--- | :--- |
| `curl: (7) Failed to connect to 192.168.1.211 port 80` | Apple TV is asleep or SVPlayer app is backgrounded on tvOS. | Wake Apple TV and bring SVPlayer to the foreground; set **Settings → General → Sleep After → Never**. |
| Uploaded `.srt` subtitle does not appear | Basename mismatch or missing `sub-auto=fuzzy` in `mpv.conf`. | Run `svp-cli conf optimal` and ensure video and subtitle share the exact basename (`film.mp4` + `film.srt`). |
| Basic Auth error when using Caddy Gateway | `SVP_HOST` missing credentials. | Export `SVP_HOST="http://andro:YourPass@127.0.0.1:8090"`. |
