# 4ndr0service — Unbound Self-Healing Dev Environment

God-tier multi-toolchain orchestrator for Arch Linux.  
Fully XDG-compliant, production-grade, self-healing, and now **permanently unbound** thanks to the void-gaze installer.

## Core Philosophy
Everything lives in user-space. System Python/pip/gems/node/go/rust remain untouched.  
Daily systemd timer auto-heals env vars, dirs, tools.  
Config-driven — extend via `config.json` without touching code.

## God-Install Ritual (Recommended)
```bash
# Clone anywhere, then run the void-gaze installer
git clone https://github.com/4ndr0666/4ndr0service.git /tmp/4ndr0service
cd /tmp/4ndr0service
bash install.sh
```

This:
- Clones/updates to `/opt/4ndr0service`
- Embeds absolute `PKG_PATH` into every .sh
- Creates canonical symlink `/usr/local/bin/4ndr0service`
- Sets up default config skeleton
- Runs smoke test

After install, simply run:
```bash
4ndr0service          # interactive menu (dialog/fzf/cli)
4ndr0service --fix    # auto-heal
4ndr0service --parallel --report  # fast parallel checks
```

## Quick Commands
```bash
4ndr0service --test           # smoke + full verify
4ndr0service --fix --report   # heal + report
4ndr0service --dry-run        # simulate everything
```

## Systemd Healing Heartbeat
Installed automatically via `install_env_maintenance.sh` (or run manually):
- `env_maintenance.timer` → daily `4ndr0service --fix --report`
- Randomized 15m delay to avoid thundering herd

## Development & Contribution
- All scripts must pass `shellcheck`
- Use `.editorconfig` for formatting
- Add new `optimize_*.sh` in `service/`
- Plugins go in `plugins/`
- Tests in `test/bats/`

## License
MIT — do what thou wilt.
