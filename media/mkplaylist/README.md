# Ψ `mkplaylist` (`v3.2.0`) — Standalone Lossless M3U Playlist, LAN URL & Caddy Stream Generator

`mkplaylist` is a standalone POSIX `/bin/sh` TUI and CLI utility backed by an embedded Python 3 engine for lossless, symlink-loop-safe filesystem traversal, deterministic sorting (`date`, `size`, `name`, `shuffle`), automatic physical LAN URL injection, and atomic publication of `playlist.m3u` and its coinciding `Caddyfile`. In `v3.2.0`, `mkplaylist` eliminates manual `export MKPLAYLIST_BASE_URL` steps, resolves the `UnboundLocalError` variable scoping bug, automatically fixes transposed LAN IP octets (`192.1.168.x` → `192.168.1.x`), enforces `admin off` in generated Caddyfiles, and supports 1-command Apple TV [SVPlayer](https://www.svp-team.com/wiki/Manual:SVPcast) casting (`-S`).

## Overview of Contents

1. Architectural Audit & Bug Mitigations Applied in `v3.2.0`
2. Design Invariants: Inode Deduplication, Exclusive Locking & Atomic Publishing
3. Installation & Runtime Requirements
4. Complete CLI Option Reference
5. Automatic LAN Base URL Injection (`-u auto`, `-c`, `-a`, `-b`) vs. Relative Mode (`-u rel`)
6. Automatic Octet Transposition Sanitizer (`sanitize_bind_ips`)
7. WireGuard / VPN Bypass in Physical LAN IP Detection (`detect_lan_ip`)
8. Coinciding `Caddyfile` Generation & Validation (`admin off` Enforced)
9. Extended M3U `#EXTINF` Metadata Generation (`-M`)
10. Direct Apple TV SVPlayer Casting (`-S` & `-I <ip>`)
11. Idempotence & Non-Destructive Backup Variants (`-K`)
12. Common Workflows & Troubleshooting Matrix

## 1. Architectural Audit & Bug Mitigations Applied in `v3.2.0`

| Defect ID | Prior Behavior | Root Cause | `v3.2.0` Mitigation in `mkplaylist` |
| :--- | :--- | :--- | :--- |
| **`MKP-BUG-01`** | `UnboundLocalError: cannot access local variable 'records' where it is not associated with a value` at line 233 in `main()`. | URL assembly referenced `records` prior to `records = order_records(discover(root, kind, depth), field, direction)` inside `main()`. | Fixed execution order inside the `fcntl.flock` critical section: `records` is discovered, deduplicated, and sorted strictly before URL formatting. |
| **`MKP-BUG-02`** | Required manually running `export MKPLAYLIST_BASE_URL="http://192.168.1.100:3000"` before every invocation when streaming to SVPlayer. | No CLI flag or automatic LAN URL derivation existed for HTTP streaming playlists. | Added `-u <auto\|rel\|http://...>` and automatic derivation of `http://<LAN_IP>:<PORT>` whenever `-c`, `-a`, or `-b` is passed. |
| **`MKP-BUG-03`** | Passing `-b "192.1.168.100 127.0.0.1"` caused Caddy to fail to bind or rejected the transposed octet. | Common finger-slip transposing `.1.168.` instead of `.168.1.` on a `192.168.1.0/24` LAN. | Added `sanitize_bind_ips()`, which automatically rewrites `192.1.168.<host>` to `192.168.1.<host>` and logs a clear `[WARN]` message to `stderr`. |
| **`MKP-BUG-04`** | Uploading a relative `./subdir/file.mp4` `playlist.m3u` to the SVPlayer WebUI failed to play any entries. | `mpv` on Apple TV resolved `./` relative to `/Library/Caches/SVPlayer/uploads/` instead of the LAN media server. | With automatic `http://<LAN_IP>:<PORT>/` URLs in `playlist.m3u`, the `.m3u` file works both when cast via `/r/play?url=...` AND when drag-and-dropped into `/r/upload`. |
| **`MKP-BUG-05`** | Generated `Caddyfile` did not explicitly disable Caddy's `:2019` admin endpoint. | Missing global `{ admin off }` block in `caddy_config()`. | `caddy_config()` now unconditionally prepends `{\n\tadmin off\n}\n\n` to every generated `Caddyfile`. |

## 2. Design Invariants: Inode Deduplication, Exclusive Locking & Atomic Publishing

1. **Symlink-Loop Immunity & Hardlink Deduplication:** `discover()` tracks directory `(st_dev, st_ino)` tuples without following symlinks (`follow_symlinks=False`), preventing infinite recursion on circular symlinks. Regular files are also keyed by `(st_dev, st_ino)`, ensuring hardlinked duplicates appear only once (choosing the lexicographically shortest relative path).
2. **Surrogate-Safe Byte Paths:** File discovery and sorting operate on raw filesystem bytes via `os.fsencode()` and `urllib.parse.quote_from_bytes(..., safe='/-._~')`, ensuring filenames with non-UTF-8 bytes, spaces, brackets, or Unicode characters are losslessly percent-encoded into valid RFC 3986 URIs.
3. **Exclusive Directory Locking (`fcntl.flock`):** Before scanning or writing, `mkplaylist` opens the target root directory with `O_RDONLY | O_DIRECTORY` and acquires `fcntl.LOCK_EX`, preventing concurrent invocations from racing.
4. **Atomic Staging & Hardlink Archiving (`publish()`):** Outputs are written to a mode-`0644`/`0600` temporary file (`.mkplaylist.XXXXXX` / `.mkcaddy.XXXXXX`), flushed with `os.fsync()`, and atomically moved into place via `os.replace()` after hardlinking any differing prior file to `playlist.<N>.m3u` (`[BACKUP]`). If the newly generated content is byte-identical to the existing file, `mkplaylist` logs `[IDEMPOTENT]` and performs zero disk writes.

## 3. Installation & Runtime Requirements

* **Shell:** POSIX `/bin/sh` (`dash`, `bash`, `ash`, `ksh`, `zsh`)
* **Python:** Python 3.9+ (`python3` standard library only: `fcntl`, `ipaddress`, `pathlib`, `urllib.parse`, `tempfile`)
* **Optional:** `fzf` (for interactive TUI menus), `caddy` (for `-v` config validation and `-S` streaming), `curl` (for `-S` SVPlayer casting)

Install to `~/.local/bin` or `/usr/local/bin`:

```bash
install -Dm755 ./mkplaylist ~/.local/bin/mkplaylist
```

## 4. Complete CLI Option Reference

| Option | Argument | Default | Description |
| :--- | :--- | :--- | :--- |
| **`-t`** | `videos\|images\|both` | `both` | Filter discovered media extensions (`videos` includes video + audio formats). |
| **`-s`** | `date\|size\|name\|shuffle` | `date` | Primary sort field (`date` uses nanosecond `st_mtime_ns`; `shuffle` uses `SystemRandom`). |
| **`-o`** | `desc\|asc` | `desc` | Sort direction (`desc` = newest/largest first; `asc` = oldest/smallest first). |
| **`-r`** | *Flag* | Off | Shorthand for `-s shuffle` (cryptographically random permutation). |
| **`-d`** | `<uint>` | `0` | Maximum directory traversal depth (`0` = unlimited recursion, `1` = root directory only). |
| **`-u`** | `auto\|rel\|<http_url>` | `auto` (with `-c`/`-a`/`-b`) | Prefix for playlist entries: `auto` (`http://LAN_IP:PORT`), `rel` (`./`), or explicit URL. |
| **`-M`** | *Flag* | Off | Emit `#EXTINF:-1,<filename>` metadata lines above each URI entry. |
| **`-K`** | *Flag* | Off (`no`) | Keep primary `playlist.m3u` untouched and write new content to `playlist.<N>.m3u`. |
| **`-e`** | *Flag* | Off (`no`) | Allow publishing an empty `#EXTM3U` file when zero matching media files exist. |
| **`-c`** | *Flag* | Off | Generate a coinciding `Caddyfile` (with `admin off` and CORS `*`) in the target root. |
| **`-a`** | `:<port>` | `:3000` | Listen port for the generated `Caddyfile` (automatically implies `-c` and `-u auto`). |
| **`-b`** | `"<ip1> <ip2>"\|all` | `"<LAN_IP> 127.0.0.1"` | Bind addresses for the generated `Caddyfile` (automatically implies `-c` and `-u auto`). |
| **`-S`** | *Flag* | Off | Start Caddy in the background with the generated `Caddyfile` and cast `playlist.m3u` to SVPlayer. |
| **`-I`** | `<ip_or_host>` | `192.168.1.211` | Target Apple TV SVPlayer IP address used when `-S` is active. |
| **`-v`** | *Flag* | `auto` | Require `caddy adapt --validate` to succeed before publishing files (fail closed if `caddy` is absent). |
| **`-V`** | *Flag* | `auto` | Explicitly skip `caddy` validation even if `caddy` is installed. |
| **`-n`** | *Flag* | Off | Non-interactive mode (never prompt on `stdin`; use CLI flags and defaults). |
| **`-h`** | `--help` | Off | Display the help screen and exit. |

### Supported Media Extensions

* **Videos & Audio (`-t videos` or `-t both`):**
  `mp4, wmv, mkv, avi, mov, mpeg, mpg, mpe, m4v, webm, ts, flv, ogv, 3gp, 3g2, m2ts, mts, m2v, vob, vro, mxf, asf, divx, f4v, mp3, flac, aac, m4a, m4b, ogg, oga, opus, wav, wave, aif, aiff, aifc, au, snd, wma, ac3, eac3, dts, amr, ape, alac, tak, wv, caf, mka`
* **Images (`-t images` or `-t both`):**
  `jpg, jpeg, jpe, png, gif, webp, bmp, dib, tiff, tif, svg, avif, heic, heif, apng, jxl, ico`

## 5. Automatic LAN Base URL Injection (`-u auto`, `-c`, `-a`, `-b`) vs. Relative Mode (`-u rel`)

### Automatic HTTP LAN URL Mode (Zero Manual Exports!)
Whenever you pass `-c`, `-a :<port>`, `-b "<ips>"`, `-S`, or `-u auto`, `mkplaylist` automatically detects your workstation's physical LAN IP (`192.168.1.100`) and port (`3000`) and writes full HTTP URLs into `playlist.m3u`:

```bash
mkplaylist -n -t both -s date -o desc -a :3000 -b "192.168.1.100 127.0.0.1" .
```

Generated `playlist.m3u`:

```m3u
#EXTM3U
http://192.168.1.100:3000/2026_Clips/lena_blue2.mp4
http://192.168.1.100:3000/Movies/Blade%20Runner%202049.mkv
```

### Explicit Custom Base URL Mode (`-u <url>`)
If your media is served behind a reverse proxy or custom hostname:

```bash
mkplaylist -n -t videos -u "http://svp.lan:8090/media" /Nas/Nas/Movies
```

### Relative Path Mode (`-u rel`)
If you want `./path/to/file.mp4` for local desktop `mpv` playback without HTTP:

```bash
mkplaylist -n -t videos -u rel /Nas/Nas/Movies
```

## 6. Automatic Octet Transposition Sanitizer (`sanitize_bind_ips`)

If you accidentally type `192.1.168.100` instead of `192.168.1.100` in `-b`:

```bash
mkplaylist -n -t both -s date -o desc -a :3000 -b "192.1.168.100 127.0.0.1" .
```

`mkplaylist` intercepts the typo before Python's `ipaddress` / Caddy bind step, emits:
`[WARN] Auto-corrected transposed LAN octet '192.1.168.100' -> '192.168.1.100'`
and writes `bind 192.168.1.100 127.0.0.1` and `http://192.168.1.100:3000/...` cleanly!

## 7. WireGuard / VPN Bypass in Physical LAN IP Detection (`detect_lan_ip`)

When `theworkpc` is connected to a WireGuard (`wg0`), OpenVPN (`tun0`), or container bridge (`docker0`, `virbr0`), a naive `ip route get 1.1.1.1` returns the VPN tunnel IP (`10.x.x.x`), which the Apple TV on `192.168.1.211` cannot reach!

`mkplaylist`'s `detect_lan_ip()` explicitly filters out `type wireguard`, `POINTOPOINT`, `lo`, `tun*`, `tap*`, `wg*`, `ppp*`, `docker*`, `br-*`, `veth*`, and `virbr*` interfaces, selecting only global IPv4 addresses on physical `BROADCAST` Ethernet/Wi-Fi interfaces (`enp3s0`).

## 8. Coinciding `Caddyfile` Generation & Validation (`admin off` Enforced)

When `-c` (or `-a` / `-b` / `-S`) is passed, `mkplaylist` generates a hardened `Caddyfile` alongside `playlist.m3u`:

```caddyfile
{
	admin off
}

:3000 {
	bind 192.168.1.100 127.0.0.1
	root * "/23.1"
	handle "/playlist.m3u" {
		header Content-Type "audio/x-mpegurl; charset=utf-8"
		header Cache-Control "no-cache, no-store, must-revalidate"
		header Access-Control-Allow-Origin "*"
		file_server
	}
	handle {
		header Access-Control-Allow-Origin "*"
		file_server {
			hide .git .env .DS_Store *.bak .mkplaylist.* .mkcaddy.* Caddyfile Caddyfile.*
		}
	}
}
```

Before writing `Caddyfile` to disk, `validate_caddy()` runs `caddy adapt --config <temp> --adapter caddyfile --validate` with a 60-second timeout so an invalid configuration is never published.

## 9. Extended M3U `#EXTINF` Metadata Generation (`-M`)

Pass `-M` to include `#EXTINF:-1,<title>` lines for players and WebUIs that display playlist track titles:

```bash
mkplaylist -n -M -t videos -a :3000 /Nas/Nas
```

## 10. Direct Apple TV SVPlayer Casting (`-S` & `-I <ip>`)

Pass `-S` to automate the entire workflow (scan directory → write `playlist.m3u` with LAN URLs → write `Caddyfile` with `admin off` → start Caddy in background → cast `http://<LAN_IP>:<PORT>/playlist.m3u` to `http://192.168.1.211/r/play`):

```bash
mkplaylist -n -t videos -s date -o desc -a :3000 -S /Nas/Nas/Movies
```

## 11. Idempotence & Non-Destructive Backup Variants (`-K`)

* **Default Refresh Mode (without `-K`):** If `playlist.m3u` already exists and its contents differ from the new scan, `mkplaylist` hardlinks the old `playlist.m3u` to `playlist.1.m3u` (`[BACKUP]`) and atomically replaces `playlist.m3u` with the new list.
* **Keep Mode (`-K`):** Preserves `playlist.m3u` untouched and writes the new playlist to the first free numbered slot (`playlist.1.m3u`, `playlist.2.m3u`, etc.), or reuses an existing numbered slot if its bytes already match (`[IDEMPOTENT]`).

## 12. Common Workflows & Troubleshooting Matrix

| Symptom | Cause | Resolution |
| :--- | :--- | :--- |
| `[ERROR] No matching media found; existing outputs preserved` | Target directory has no video/audio/image files matching `-t`. | Verify path or pass `-e` to explicitly allow generating an empty `#EXTM3U` playlist. |
| Apple TV cannot reach `:3000` | Local firewall (`ufw`/`iptables`/`nftables`) blocking TCP `3000` on `enp3s0`. | Run `sudo ufw allow from 192.168.1.0/24 to any port 3000 proto tcp`. |
| Want only top-level directory files (no recursion) | Default depth is `0` (unlimited). | Pass `-d 1` to restrict discovery to the root directory. |


## 13. Internal Python Engine Architecture (`discover`, `order_records`, `publish`)

### Inode & Symlink Traversal Pipeline (`discover()`)
```python
# Directory identity is tracked by (st_dev, st_ino) before descending:
info = entry.stat(follow_symlinks=False)
if stat.S_ISDIR(info.st_mode):
    identity = (info.st_dev, info.st_ino)
    if (depth == 0 or level + 1 < depth) and identity not in directories:
        directories.add(identity)
        children.append((Path(entry.path), level + 1))
```
* Because `follow_symlinks=False` is passed to `entry.stat()`, symbolic links pointing to parent directories (`ln -s .. loop`) are ignored as directories and can never cause infinite recursion.
* Hardlinked files sharing identical `(st_dev, st_ino)` values are deduplicated automatically so the playlist never plays the same underlying media inode twice.

### Deterministic Multi-Key Sorting (`order_records()`)
1. Every discovered record `(relative_path, st_mtime_ns, st_size)` is first sorted lexicographically by raw path bytes (`os.fsencode(row[0])`).
2. Because Python's Timsort is stable, sorting secondarily by `st_mtime_ns` (`-s date`) or `st_size` (`-s size`) guarantees that files with identical modification timestamps or byte sizes remain in deterministic alphabetical order.
3. When `-s shuffle` (or `-r`) is selected, `random.SystemRandom().shuffle(records)` uses OS entropy (`/dev/urandom`) to produce an unbiased cryptographic permutation.

### Crash-Safe Atomic File Publication (`stage()` & `publish()`)
```text
Target Directory (/Nas/Nas)
  ├── [1] Open directory fd (O_RDONLY | O_DIRECTORY) -> fcntl.flock(LOCK_EX)
  ├── [2] Compare new content bytes against existing playlist.m3u
  │       └── If identical -> log [IDEMPOTENT], exit 0 with zero disk writes
  ├── [3] Write new content to .mkplaylist.XXXXXX (mode 0644) + os.fsync()
  ├── [4] Hardlink existing playlist.m3u -> playlist.1.m3u ([BACKUP])
  ├── [5] Atomic os.replace(.mkplaylist.XXXXXX -> playlist.m3u) ([CREATED])
  └── [6] os.fsync(directory_fd) -> release flock
```

## 14. End-to-End Integration Recipes with `svp-cli` and `mkcaddy.sh`

### Recipe A: One-Command Newest-First Movie Night Cast to Apple TV
```bash
# Scans /Nas/Nas/Movies, generates playlist.m3u with http://<LAN_IP>:3000/ URLs,
# writes Caddyfile with admin off, starts Caddy, and casts to 192.168.1.211:
mkplaylist -n -M -t videos -s date -o desc -a :3000 -S /Nas/Nas/Movies
```

### Recipe B: Generating a Playlist for an Existing `mkcaddy.sh -p svp-gateway` Instance on `:8090`
```bash
# Generate playlist.m3u with http://192.168.1.100:8090/ URLs without starting a second Caddy instance:
mkplaylist -n -M -t videos -s date -o desc -u "http://192.168.1.100:8090" /Nas/Nas

# Cast via svp-cli through the authenticated gateway:
SVP_HOST="http://andro:YourStrongPass@127.0.0.1:8090" svp-cli play "http://192.168.1.100:8090/playlist.m3u"
```

### Recipe C: Preserving Historical Numbered Playlists (`-K`)
```bash
# Creates playlist.1.m3u (or reuses an identical numbered variant) without touching playlist.m3u:
mkplaylist -n -K -t videos -r -u "http://192.168.1.100:3000" /Nas/Nas/MusicVideos
```
