# makex

Fixes executable bits across a directory tree **by looking at what files actually are**, not just what they are called. Scripts become executable; documents, media, data and archives do not. Native binaries are left alone.

**Version:** 2.3.0 · **Author:** 4ndr0666 · **Requires:** bash 4+ (tested on 5.2), GNU findutils (`find` with `-perm /mode`), coreutils. `sudo` is optional and only used as a fallback.

---

## Quick start

```bash
makex -n .          # preview: shows what would change, modifies nothing
makex               # apply to the current directory
makex -q ~/bin ~/projects/tools
```

Install:

```bash
install -m 755 makex ~/.local/bin/makex
```

---

## Modes

| Mode | Scripts | Everything else |
|---|---|---|
| **Default** | Gain `u+x` if they lack it | Files detected as non-executable types **lose all exec bits** |
| **`-r` (reverse)** | **Lose all exec bits** (`a-x`) | Same as default: non-executable types lose exec |

Reverse mode **never grants** exec to anything. Its job is to make sure scripts are not executable while documents and data stay non-executable.

---

## How detection works

For every file makex reads at most 4 KiB once (no subprocesses per file) and applies these layers in order. The first conclusive layer wins.

| # | Layer | Result |
|---|---|---|
| 1 | **Name / extension** is a non-executable type: documents, markup, config/data, images, audio, video, archives, fonts, keys, lock/backup files, compiled-language source (`.md .txt .html .json .toml .mp4 .zip .c .rs` and ~130 more), or a name like `README`, `LICENSE`, `Makefile`, or a shell dotfile such as `.bashrc` | **non-executable**, even if it contains a shebang |
| 2 | **Shebang**: first line is `#!/…` for *any* interpreter (shell, Python, Perl, Ruby, Node, awk…) | **script** |
| 3 | **Native executable** magic bytes: ELF, Mach-O, PE | **never touched** |
| 4 | **`.sh` name**: a strong hint, but content can overrule it (binary data, or clearly Python/Perl/Ruby/Node source, is not a shell script) | **script** |
| 5 | **Known data magic bytes** (PNG, JPEG, GIF, PDF, ZIP, gzip, xz, zstd, 7z, SQLite, Ogg, FLAC, MP3/ID3, RIFF, WOFF, RAR, bzip2), so a file with no or a wrong extension is still recognized | **non-executable** |
| 6 | **Interpreted-language extension with no shebang** (`.py .rb .js .pl .php .lua …`): the kernel can't execute it meaningfully, so the exec bit is meaningless | **non-executable** |
| 7 | **Unknown binary** | **never touched** |
| 8 | **Unknown text with no shebang**: scored for shell-script content (see below) | **script** if conclusive, otherwise never touched |

### Shebang-less shell scripts
A file with no shebang and no helpful extension is treated as a shell script only on strong evidence: at least one block closer (`fi`, `done`, `esac`, `set -e…`, `if [ … ]`) plus at least three distinct shell signals (functions, positional parameters like `$1`/`$@`, `export`/`local`, `echo`/`printf`, `exit N`), and no Python markers. This keeps prose and data files from being flagged.

### Scripts in other languages without a shebang
A shebang-less Python, Perl, Ruby or Node script with an unrecognized name (for example an extensionless `deploy`) **is detected, but not chmod'd**. Running it directly would feed Python source to `sh`, so `chmod +x` alone would make it worse. makex reports these as advisories at the end of the run so you can add the shebang line:

```
! [CAUTION] :: 1 shebang-less file(s) look like scripts; chmod +x cannot make them runnable (add a shebang line):
! [CAUTION] ::   [python] './bin/deploy'
```

---

## Usage

```
makex [-r] [--hidden] [-n] [-q] [-h|--help] [--] [DIR...]
```

| Flag | Meaning |
|---|---|
| `-r` | Reverse mode (see table above) |
| `--hidden` | Include hidden files and directories (default skips dotfiles). `.git` is always pruned |
| `-rh`, `-hr` | Shorthand for `-r --hidden` |
| `-n`, `--dry-run` | Report planned changes; modify nothing |
| `-q`, `--quiet` | Suppress per-file success lines and the advisory file list (errors and summary remain) |
| `-V`, `--version` | Print the version |
| `-h`, `--help` | Show help |
| `--` | End of options (allows directories starting with `-`) |
| `DIR...` | One or more target directories (default `.`) |

`-h` is help, but `-rh` is the reverse-plus-hidden shorthand.

---

## Behavior worth knowing

- **Symlinks:** links inside the tree are skipped (only regular files are touched). A symlink passed *as* a target directory is followed.
- **Privileges:** a plain `chmod` is tried first. Only if the kernel refuses (and you are not root) does makex retry through `sudo`. Files you own never trigger a password prompt. Without `sudo` you get a warning and files owned by others fail.
- **Failure isolation:** if a batch of up to 1000 files is refused, each file is retried on its own, so one bad path can't hide the rest. Every failure is reported with the `chmod` error.
- **Unreadable directories:** skipped, reported in a warning, and counted in the summary. They do not change the exit code on their own.
- **Idempotent:** a second run changes nothing.
- **Safe output:** control characters and backslashes in filenames are neutralized before printing, so a hostile filename can't inject terminal escape sequences.
- **Colors:** disabled when output isn't a terminal or `NO_COLOR` is set. The screen is cleared only on a terminal.
- **Speed:** classification is fork-free. On an 8,000-file test tree v2.3.0 took about 5 s against about 32 s for v2.1.1.

### Exit codes

| Code | Meaning |
|---|---|
| `0` | Success (including dry runs and runs with nothing to change) |
| `1` | Invalid directory, unknown flag, or at least one file could not be modified |
| `130` / `143` | Interrupted by Ctrl-C / SIGTERM (temp files are still cleaned up) |

---

## Tuning

All classification data lives in variables near the top of the script:

| Variable | Purpose |
|---|---|
| `DATA_EXTS` | Extensions that are never executable (layer 1) |
| `DATA_NAMES` | Exact file names that are never executable (layer 1) |
| `SCRIPTY_EXTS` | Interpreted-language extensions that are not executable without a shebang (layer 6) |
| `SNIFF_BYTES`, `SNIFF_LINES` | How much of each file is inspected |
| `BATCH_LIMIT` | Files per `chmod` call |

---

## Caveats

- Run `makex -n` before the first real run on an existing tree. Earlier versions recognized only `*.sh` files, so this version may change more files than you expect.
- Layer 1 wins over content: a `notes.md` that starts with `#!/bin/sh` is treated as a document and loses its exec bit. Remove `md` from `DATA_EXTS` if that is wrong for you.
- Shebang-less shell detection is a heuristic. Unusual files can be missed (left untouched) but ambiguous files are never de-executed.
- Designed for Linux with GNU `find`. BSD/macOS `find` lacks `-perm /mode` and is untested.

---

## Development notes

Built to the Golden Unit Protocol (v5.3): each function was hashed and compared against v2.1.1, and every changed or new unit has a recorded review. The only removal was `build_name_filter`, an unused function. The script passes `shellcheck` cleanly.
