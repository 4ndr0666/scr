# makex

Bulk-fix executable bits across a directory tree: shell scripts become executable, non-scripts (docs, images, configs) stop being executable. One command, batched `chmod`, no guessing.

**Version:** 2.2.0 · **Author:** 4ndr0666 · **Requires:** bash 4+ (tested on 5.2), GNU findutils (`find` with `-perm /mode` and `-iname`), coreutils. `sudo` is optional and only used as a fallback.

---

## Quick start

```bash
# Preview first: shows what would change, modifies nothing
makex -n .

# Apply to the current directory
makex

# Apply to several directories, quietly
makex -q ~/bin ~/projects/tools
```

Install by putting the script on your `PATH`:

```bash
install -m 755 makex ~/.local/bin/makex
```

---

## What it does

makex runs two phases over every regular file under the target directories.

| Phase | Default mode | Reverse mode (`-r`) |
|---|---|---|
| **1. Scripts** | Adds `u+x` to shell scripts that lack it | Removes `u-x` from shell scripts that have it |
| **2. Non-scripts** | Removes all exec bits (`a-x`) from files matching the safe patterns | Adds `u+x` to files matching the safe patterns that lack it |

### How a file is judged a "script"
A file is a script if **either**:
1. its name ends in `.sh`, or
2. its first line (read up to 256 bytes) is a shell shebang for `bash`, `sh`, `zsh`, `dash`, `ksh` or `ash`.

Recognized shebangs include:

```
#!/bin/sh
#!/bin/bash
#!/usr/bin/bash
#!/usr/bin/env bash
#!/usr/bin/env -S bash -e
#!/usr/bin/env VAR=1 zsh
```

Not matched: `#!/usr/bin/env python3`, `#!/bin/shellfoo`, and any file with no shebang and no `.sh` extension. Other interpreters (Python, Perl, Node) are deliberately left alone.

### Safe (non-script) patterns
Matched case-insensitively, so `photo.JPG` counts:

`*.md *.markdown *.txt *.pdf *.jpg *.jpeg *.png *.gif *.svg *.json *.yml *.yaml *.csv *.html *.css *.rst *.webp *.ico *.toml *.xml *.ini *.log README`

Files matching these are never treated as scripts in Phase 1. Edit `SAFE_NOEXEC_PATTERNS` near the top of the script to change the list.

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
| `-q`, `--quiet` | Suppress per-file success lines; errors and the summary still print |
| `-V`, `--version` | Print the version |
| `-h`, `--help` | Show help |
| `--` | End of options (lets you pass a directory that starts with `-`) |
| `DIR...` | One or more target directories (default `.`) |

Note that `-h` is help, but `-rh` is the reverse-plus-hidden shorthand.

---

## Behavior worth knowing

- **Symlinks:** symlinks inside the tree are skipped (only regular files are touched). A symlink passed *as* a target directory is followed.
- **Privileges:** makex tries a plain `chmod` first. Only if the kernel refuses (and you are not root) does it retry through `sudo`. Files you own never trigger a password prompt. If `sudo` is missing, you get a warning and files owned by others will fail.
- **Failure isolation:** if a batch of up to 1000 files is refused, makex retries each file on its own, so one bad path doesn't hide the rest. Each failure is reported with the `chmod` error.
- **Unreadable directories:** these are skipped, reported in a warning, and counted in the summary. They do not change the exit code on their own.
- **Idempotent:** running it twice changes nothing the second time.
- **Safe output:** control characters and backslashes in filenames are neutralized before printing, so a hostile filename can't inject terminal escape sequences.
- **Colors:** disabled automatically when output isn't a terminal, or when `NO_COLOR` is set. The screen is cleared only on a terminal.

### Exit codes

| Code | Meaning |
|---|---|
| `0` | Success (including a dry run and a run with nothing to change) |
| `1` | Invalid directory, unknown flag, or at least one file could not be modified |
| `130` / `143` | Interrupted by Ctrl-C / SIGTERM (temp files are still cleaned up) |

---

## Examples

```bash
# Preview a reverse-mode sweep of everything, hidden files included
makex -n -rh ~/archive

# Normalize a repo checkout (skips .git, skips dotfiles)
makex ~/src/myrepo

# Directory whose name starts with a dash
makex -- -weird-dir

# Quiet run for scripts; check the exit code
makex -q /srv/deploy || echo "some files could not be changed"
```

---

## Caveats

- Run `makex -n` before the first real run on an existing tree. Version 2.2.0 recognizes extensionless shell scripts that earlier versions silently missed, so it may change more files than you expect.
- Phase 2 in default mode strips execute permission from *every* file matching the safe patterns, including any that really are scripts with a `.md` or `.log` name.
- Designed for Linux with GNU `find`. BSD/macOS `find` does not support `-perm /mode` and is untested.

---

## Development notes

Built to the Golden Unit Protocol (v5.3): every function was hashed and compared against the previous version, and removed or changed behavior was reviewed explicitly. The only removal in 2.2.0 was `build_name_filter`, an unused function. The script passes `shellcheck` cleanly.
