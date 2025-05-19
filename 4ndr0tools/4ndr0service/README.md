## Self-Healing Python Environment

All devtools and CLI tools (pyenv, pipx, poetry, etc) are installed in fully isolated user environments
adhering to the XDG Base Directory specification. System packages are never polluted or upgraded unless
explicitly required, and all scripts are idempotent, cross-shell safe, and CI-validated.

- To validate your environment: `bash ./test/src/verify_environment.sh --report`
- For daily health: use the provided systemd user timer/service.
- To remediate or bootstrap: `bash ./test/src/verify_environment.sh --fix`

### Version Pinning

- **Python:** 3.10.14 (managed by pyenv)
- **Poetry:** 1.8.2 (via pipx)
- **pipx:** 1.7.1 (via pip/pipx)
- **pyenv:** 2.3.40 (installed via pyenv.run)
