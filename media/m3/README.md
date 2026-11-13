# Ψ M3 (`v3.2.0`) — Standalone `N_m3u8DL-RE` Stream Extraction, Decryption & Remux Orchestrator

`M3` is a standalone, production-hardened CLI and interactive TUI wrapper around `N_m3u8DL-RE` and `ffmpeg` for extracting, decrypting, concatenating, and remuxing HLS (`.m3u8`), MPEG-DASH (`.mpd`), and Microsoft Smooth Streaming (`.ism`) manifests on Arch Linux (`theworkpc`). It operates 100% independently as a general-purpose stream ripper and also provides optional post-extraction hooks (`--cast`, `--upload`) that hand completed media directly to [SVPcast](https://www.svp-team.com/wiki/Manual:SVPcast) / `svp-cli` or a local Caddy LAN server for instant playback on an Apple TV (`AppleTV5,3`).

## Overview of Contents

1. Architectural Audit & Bug Mitigations Applied in `v3.2.0`
2. Runtime Dependencies & Binary Resolution Order
3. Installation & XDG Directory Layout
4. Persistent Configuration File (`~/.config/m3u8/m3u8.conf`)
5. Complete CLI Flag & Option Reference
6. VOD vs. Live Stream Manifest Handling (`--vod` vs. `--live`)
7. Custom HTTP Headers, User-Agent Spoofing, Cookies & Proxies
8. Widevine / PlayReady / ClearKey Decryption (`-k` & `--key-file`)
9. Batch Queue Processing (`-i` / `--input-file`)
10. Post-Extraction Apple TV SVPlayer & Caddy LAN Casting (`--cast` & `--upload`)
11. Interactive TUI Command Deck (`M3` with No Arguments)
12. Diagnostic Dry-Run Mode (`--dry-run`) & Troubleshooting Matrix

## 1. Architectural Audit & Bug Mitigations Applied in `v3.2.0`

| Defect ID | Legacy Behavior | Root Cause | `v3.2.0` Mitigation in `M3` |
| :--- | :--- | :--- | :--- |
| **`M3-BUG-01`** | Running `M3 -c` (`--create-config`) wrote a dead PID path (`TMP_DIR="/home/andro/.cache/m3u8dl/14922"`) into `m3u8.conf`, which was deleted on exit by `trap cleanup EXIT`. | `TMP_DIR` included `$$` at declaration time and was serialized directly by `save_config`. | Separated persistent `TMP_BASE="${XDG_CACHE_HOME:-$HOME/.cache}/m3u8dl"` from ephemeral runtime `TMP_DIR="${TMP_BASE}/$$"`. `save_config` writes only `TMP_BASE`. |
| **`M3-BUG-02`** | VOD `.m3u8` manifests served by Akamai or Cloudflare without a trailing `#EXT-X-ENDLIST` tag stalled indefinitely at 99%. | Both `LIVE_REAL_TIME_MERGE=1` and `LIVE_PERFORM_AS_VOD=1` were hardcoded on by default for all streams. | Default mode is now strictly VOD (`LIVE_REAL_TIME_MERGE=0`, `LIVE_PERFORM_AS_VOD=0`). Live flags are activated only when `--live` or TUI Option `4` is selected. |
| **`M3-BUG-03`** | Extracted audio and video tracks were left as separate `.mp4` and `.m4a` files in `$SAVE_DIR` when `--mux-after-done` was omitted. | Missing post-merge container remux directive in the default argument array. | Added `-M, --mux-format <mp4\|mkv\|ts\|none>` (default: `mp4`) and `--mux-engine <ffmpeg\|mkvmerge>` (default: `ffmpeg`), passing `--mux-after-done format=mp4:muxer=ffmpeg` automatically. |
| **`M3-BUG-04`** | CDN-protected `.m3u8` URLs returned `403 Forbidden` when fetched with `N_m3u8DL-RE`'s default client headers. | Missing default desktop browser `User-Agent` and lack of repeatable `-H` header flags. | Injects a hardened Linux Firefox `User-Agent` by default and supports repeatable `-H "Header: Value"` flags for `Referer`, `Origin`, `Cookie`, and `Authorization`. |
| **`M3-BUG-05`** | `M3` was previously folded into `svp-cli`, breaking standalone invocation in scripts and terminal aliases. | Monolithic script merge during prior session. | Restored `M3` as a first-class standalone executable while allowing `svp-cli m3u8` to delegate cleanly to `M3`. |

## 2. Runtime Dependencies & Binary Resolution Order

`M3` automatically probes `PATH` for the following binaries:

| Component | Probed Binary Names (in Priority Order) | Purpose | Arch Linux Package |
| :--- | :--- | :--- | :--- |
| **Extractor Core** | `N_m3u8DL-RE`, `n-m3u8dl-re`, `N-m3u8DL-RE`, `n-m3u8dl-re-git`, `N-m3u8dl-RE-git` | Parallel HLS/DASH/MSS segment downloader and parser | `yay -S n-m3u8dl-re-bin` |
| **Muxer Engine** | `ffmpeg`, `mkvmerge` | Post-download container remuxing (`mp4`, `mkv`, `ts`) and concat demuxing | `sudo pacman -S ffmpeg mkvtoolnix-cli` |
| **Decryptor (Optional)** | `mp4decrypt`, `shaka-packager` | CENC / CBCS decryption when `-k` or `--key-file` is passed | `yay -S bento4 shaka-packager-bin` |
| **Cast Bridge (Optional)** | `svp-cli`, `svp`, `caddy`, `curl`, `python3` | Zero-copy LAN streaming (`--cast`) or multipart upload (`--upload`) to Apple TV | `sudo pacman -S caddy curl python` |

## 3. Installation & XDG Directory Layout

Install `M3` into `~/.local/bin` or `/usr/local/bin`:

```bash
install -Dm755 ./M3 ~/.local/bin/M3
# Or system-wide via install_svp.sh:
sudo bash install_svp.sh --install-tools
```

Verify installation and version:

```bash
M3 --version
# Output: 3.2.0
```

### XDG Base Directory Paths

* **Configuration File:** `${XDG_CONFIG_HOME:-$HOME/.config}/m3u8/m3u8.conf` (overridable via `M3_CONFIG_FILE`)
* **Runtime Segment Cache:** `${XDG_CACHE_HOME:-$HOME/.cache}/m3u8dl/<PID>` (base directory overridable via `M3_TMP_BASE`; cleaned automatically on `EXIT`, `INT`, `TERM`, `HUP`)
* **Execution Logs:** `${XDG_DATA_HOME:-$HOME/.local/share}/logs/n-m3u8dl-re.log` (overridable via `M3_LOG_DIR`)
* **Default Output Directory:** `$HOME/streamdir` (overridable via `-d` or `M3_SAVE_DIR`)

## 4. Persistent Configuration File (`~/.config/m3u8/m3u8.conf`)

Generate or update your persistent configuration file at any time using `-c` / `--create-config` (combines with any CLI flags passed on the same line):

```bash
M3 -t 16 -r 8 -d /Nas/Nas/Streams -M mp4 --svp-host http://192.168.1.211 -c
```

This writes `~/.config/m3u8/m3u8.conf` with mode `0600`:

```ini
# === Ψ M3 (N_m3u8DL-RE) Persistent Configuration === (c) 2026 - 4ndr0666
# Note: TMP_BASE is stored without runtime PID ($$) to prevent stale path locks.
THREAD_COUNT="16"
RETRY_COUNT="8"
SAVE_DIR="/Nas/Nas/Streams"
TMP_BASE="/home/andro/.cache/m3u8dl"
LOG_DIR="/home/andro/.local/share/logs"
PROXY_URL=""
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64; rv:135.0) Gecko/20100101 Firefox/135.0"
MUX_FORMAT="mp4"
MUX_ENGINE="ffmpeg"
AUTO_SELECT="1"
SKIP_MERGE="0"
DEL_AFTER_DONE="1"
USE_FFMPEG_CONCAT="0"
LIVE_REAL_TIME_MERGE="0"
LIVE_PERFORM_AS_VOD="0"
AUTO_SUB_FIX="1"
SVP_HOST="http://192.168.1.211"
CADDY_PORT="3000"
PRESET_URL_1="https://example.com/master.m3u8"
PRESET_LABEL_1="Preset Stream 1 (VOD Master)"
PRESET_URL_2="https://example.com/live.m3u8"
PRESET_LABEL_2="Preset Stream 2 (Live Feed)"
```

## 5. Complete CLI Flag & Option Reference

| Short | Long Option | Argument | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `-o` | `--output` | `<name>` | `stream_<YYYYMMDD_HHMMSS>` | Output filename base without extension. |
| `-d` | `--save-dir` | `<dir>` | `$HOME/streamdir` | Directory where final muxed media files are saved. |
| `-t` | `--threads` | `<uint>` | `8` | Concurrent segment download threads (`--thread-count`). |
| `-r` | `--retries` | `<uint>` | `5` | Per-segment retry count (`--download-retry-count`). |
| `-M` | `--mux-format` | `mp4\|mkv\|ts\|none` | `mp4` | Container format for `--mux-after-done`. Pass `none` to skip post-muxing. |
| *None* | `--mux-engine` | `ffmpeg\|mkvmerge` | `ffmpeg` | Muxing binary used by `--mux-after-done`. |
| `-i` | `--input-file` | `<path>` | *None* | Path to batch file containing one `URL` or `URL\|save_name` per line. |
| `-H` | `--header` | `"Key: Value"` | *Repeatable* | Custom HTTP header passed via `-H` to `N_m3u8DL-RE`. |
| `-U` | `--user-agent` | `<string>` | Firefox 135 Linux | Custom `User-Agent` header value. |
| `-p` | `--proxy` | `<url>` | *None* | HTTP or SOCKS5 proxy URL (`--custom-proxy`). |
| `-R` | `--max-speed` | `<rate>` | *Unlimited* | Throttle download speed (e.g., `20M`, `500K`). |
| `-k` | `--key` | `<KID:KEY>` | *Repeatable* | Hex `KID:KEY` pair for Widevine/PlayReady/ClearKey decryption. |
| *None* | `--key-file` | `<path>` | *None* | File containing multiple `KID:KEY` lines (`--key-text-file`). |
| *None* | `--live` | *Flag* | Off (`0`) | Enables `--live-real-time-merge` and `--live-perform-as-vod`. |
| *None* | `--vod` | *Flag* | On (`1`) | Forces VOD mode (disables live flags even if enabled in `m3u8.conf`). |
| *None* | `--concat` | *Flag* | Off (`0`) | Enables `--use-ffmpeg-concat-demuxer` for complex discontinuities. |
| *None* | `--binary-merge` | *Flag* | Off (`0`) | Enables `--binary-merge` for raw TS byte concatenation. |
| *None* | `--skip-merge` | *Flag* | Off (`0`) | Downloads segments without merging (`--skip-merge`). |
| *None* | `--keep-temp` | *Flag* | Off (`0`) | Disables `--del-after-done` to inspect raw segment chunks. |
| *None* | `--sub-only` | *Flag* | Off (`0`) | Downloads and merges subtitle tracks only (`--sub-only`). |
| *None* | `--no-auto-select` | *Flag* | Off (`0`) | Disables `--auto-select` so `N_m3u8DL-RE` prompts for track selection. |
| *None* | `--cast` | *Flag* | Off | Serves output file via Caddy on LAN and triggers SVPlayer `/r/play`. |
| *None* | `--up`, `--upload` | *Flag* | Off | Uploads output file to SVPlayer `/r/upload` via multipart POST. |
| *None* | `--svp-host` | `<url>` | `http://192.168.1.211` | Target SVPlayer endpoint (or authenticated Caddy gateway URL). |
| *None* | `--caddy-port` | `<port>` | `3000` | Local Caddy port used when `--cast` is active without `svp-cli`. |
| `-c` | `--create-config` | *Flag* | Off | Saves current settings to `~/.config/m3u8/m3u8.conf` and exits. |
| *None* | `--dry-run` | *Flag* | Off | Prints the exact `N_m3u8DL-RE` command array without executing. |
| `-v` | `--version` | *Flag* | Off | Prints version (`3.2.0`) and exits. |
| `-h` | `--help` | *Flag* | Off | Prints comprehensive CLI usage help and exits. |

## 6. VOD vs. Live Stream Manifest Handling (`--vod` vs. `--live`)

### Standard VOD Extraction (Default)
By default, `M3` runs in strict VOD mode so manifests with missing `#EXT-X-ENDLIST` tags finish cleanly as soon as all listed segments are fetched:

```bash
M3 -t 16 -o "feature_film" "https://cdn.example.com/hls/master.m3u8"
```

### Live Stream Recording (`--live`)
When capturing a live broadcast or linear channel where the manifest sliding window updates dynamically, pass `--live`:

```bash
M3 --live -o "live_event" "https://live.example.com/channel1/index.m3u8"
```

### Handling `#EXT-X-DISCONTINUITY` Ad-Inserted Streams (`--concat`)
If a VOD stream contains mid-roll ad discontinuities with differing audio/video codec parameters, use `--concat` so FFmpeg's concat demuxer normalizes timestamps:

```bash
M3 --concat -M mkv -o "clean_show" "https://cdn.example.com/show/master.m3u8"
```

## 7. Custom HTTP Headers, User-Agent Spoofing, Cookies & Proxies

Many streaming CDNs bind `.m3u8` tokens to the originating `Referer`, `Origin`, `Cookie`, and `User-Agent` headers. Pass as many `-H` flags as needed:

```bash
M3 \
  -H "Referer: https://player.example.com/" \
  -H "Origin: https://player.example.com" \
  -H "Cookie: session_id=xyz987; hdnts=exp=1794390000~acl=/*" \
  -p "http://127.0.0.1:8080" \
  -o "protected_stream" \
  "https://edge.cdn.example.com/hls/master.m3u8"
```

## 8. Widevine / PlayReady / ClearKey Decryption (`-k` & `--key-file`)

When extracting encrypted MPEG-DASH (`.mpd`) or HLS (`SAMPLE-AES` / `cbcs`) streams with known content keys:

```bash
# Single or multiple KID:KEY pairs on the command line:
M3 \
  -k "0123456789abcdef0123456789abcdef:fedcba9876543210fedcba9876543210" \
  -k "11112222333344445555666677778888:9999aaaabbbbccccddddeeeeffff0000" \
  -M mkv \
  -o "decrypted_uhd" \
  "https://cdn.example.com/dash/manifest.mpd"

# Or load keys from a text file:
M3 --key-file ~/.config/m3u8/keys.txt -o "decrypted_movie" "https://cdn.example.com/dash/manifest.mpd"
```

## 9. Batch Queue Processing (`-i` / `--input-file`)

Create a queue file (`queue.txt`) with one URL per line. Append `|<custom_name>` to any line to name that output file explicitly:

```text
# Season 1 Batch Queue
https://cdn.example.com/s01e01/master.m3u8|Show_S01E01_1080p
https://cdn.example.com/s01e02/master.m3u8|Show_S01E02_1080p
https://cdn.example.com/s01e03/master.m3u8|Show_S01E03_1080p
```

Run the batch queue (and optionally `--cast` or `--upload` each episode):

```bash
M3 -t 16 -M mp4 -i queue.txt
```

## 10. Post-Extraction Apple TV SVPlayer & Caddy LAN Casting (`--cast` & `--upload`)

Why `.m3u8` URLs often fail or get hijacked when pasted directly into the Apple TV SVPlayer WebUI:
1. `theworkpc` is often connected to a WireGuard VPN or holds session cookies/headers that the Apple TV (`192.168.1.211`) lacks.
2. Dual-core A8 CPU threads inside `libmpv` on `AppleTV5,3` can stall when remote CDN segments time out.

Using `M3 --cast` solves both problems: `N_m3u8DL-RE` downloads and remuxes the stream into an `.mp4` over your workstation's full network/VPN stack, and `M3` immediately serves it over physical LAN via Caddy and triggers `/r/play` on the Apple TV:

```bash
# Rip via N_m3u8DL-RE and immediately LAN-stream to Apple TV (Zero ATV cache wear):
M3 --cast -t 16 -o "tonights_stream" "https://cdn.example.com/live/master.m3u8"

# Rip via N_m3u8DL-RE and multipart-upload the MP4 to Apple TV cache:
M3 --upload -o "short_clip" "https://cdn.example.com/clips/highlight.m3u8"
```

## 11. Interactive TUI Command Deck (`M3` with No Arguments)

Running `M3` in an interactive terminal without arguments launches the `#15FFFF` TUI Command Deck:

```text
      === // Ψ M3 STREAM EXTRACTOR v3.2.0 // ===
  Save Dir: /home/andro/streamdir | Threads: 8 | Retries: 5 | Mux: mp4 | Mode: VOD

  1. Extract VOD Stream (.m3u8 / .mpd / .ism)
  2. Extract VOD Stream & Auto-Cast to Apple TV via Caddy (--cast)
  3. Extract VOD Stream & Upload to Apple TV Cache (--upload)
  4. Extract Live Stream (Real-Time Merge enabled)
  5. Process Batch URL Queue File (-i)
  6. Launch Preset 1: Preset Stream 1 (VOD Master)
  7. Launch Preset 2: Preset Stream 2 (Live Feed)
  8. Configure Threads / Retries / Save Directory / Headers
  s. Save Current Configuration to /home/andro/.config/m3u8/m3u8.conf
  q. Quit
```

## 12. Diagnostic Dry-Run Mode (`--dry-run`) & Troubleshooting Matrix

Use `--dry-run` to inspect the exact command line `M3` will invoke without making network requests:

```bash
M3 --dry-run -t 12 -M mkv -H "Referer: https://example.com/" -o test_out "https://example.com/master.m3u8"
```

| Symptom | Cause | Solution |
| :--- | :--- | :--- |
| Stream hangs at `99%` on VOD manifest | CDN omits `#EXT-X-ENDLIST` while live flags were set in `m3u8.conf`. | Pass `--vod` on the CLI and run `M3 --vod -c` to reset `m3u8.conf`. |
| `HTTP 403 Forbidden` on segment fetch | CDN checks `Referer` or `Cookie` headers. | Pass `-H "Referer: https://<site>/"` and `-H "Cookie: <cookie>"`. |
| Audio and video out of sync after merge | Discontinuity tags across ad-spliced segments. | Pass `--concat` to use FFmpeg's concat demuxer. |
| Apple TV drops frames on extracted file | Stream uses 10-bit HEVC (`Main10`), which the A8 GPU cannot hardware-decode. | Transcode via SVPcast H.264 8-bit (`yuv420p`) or select an H.264 (`avc1`) track via `--no-auto-select`. |
