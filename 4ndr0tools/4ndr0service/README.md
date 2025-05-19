# 4ndr0service — Self-Healing Python Environment

This suite ensures your development and CI environment is always XDG-compliant, production-grade, and fully **self-healing**. All Python tools (pyenv, pipx, poetry, dev tools) are installed and managed *only* in user space; the system Python and global pip are never touched unless explicitly required.

## OS Target: Arch Linux

> These scripts assume an Arch Linux environment. For other distros, adjust the installation logic as needed.

---

## Environment Setup and Audit

- **Validate environment:**  
  `bash ./test/src/verify_environment.sh --report`
- **Fix or bootstrap environment:**  
  `bash ./test/src/verify_environment.sh --fix`
- **Optimize Python stack:**  
  `bash ./test/src/optimize_python.sh`
- **Install systemd user timer (for daily checks):**  
  `bash ./test/src/install_env_maintenance.sh`

### Systemd units are installed to  
`$XDG_CONFIG_HOME/systemd/user`  
and enabled as a user service (`env_maintenance.timer`).

---

## Version Pinning

All Python tools are version-pinned for maximal reproducibility:

- **Python:** 3.10.14 (via pyenv)
- **Poetry:** 1.8.2 (via pipx)
- **pipx:** 1.7.1
- **pyenv:** 2.3.40

---

## Self-Healing Protocol

- All required env vars, directories, and tools (pyenv, pipx, poetry, devtools) are checked and optionally fixed.
- Shell scripts are linted via [ShellCheck](https://www.shellcheck.net/) in CI.
- Systemd timer runs `verify_environment.sh` daily to auto-heal the dev environment.
- Everything is fully XDG compliant and can be safely wiped by removing `.config`, `.local/share`, `.cache`.

---

## Development/Contribution

- All `.sh` scripts must pass `shellcheck`.
- Formatting is enforced via `.editorconfig`.
- Use `main` branch only.

---

## Troubleshooting

If a tool is missing or an error is reported, re-run with `--fix` or consult the relevant error message for manual install commands.

---

For support, open an issue at [4ndr0666/scr](https://github.com/4ndr0666/scr).
