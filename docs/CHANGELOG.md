# Changelog
## [Unreleased]
- Fixed swappiness validation in ufw.sh to automatically reset vm.swappiness to 60 when misconfigured.
- Add ffx-cli.sh script providing process, merge, looperang, speed, and probe commands.
- Implement promptlib.py library and sora_prompt_builder.sh CLI for pose-based prompt generation.
- Update shellcheck workflow to fail on warnings.
- Added --foreground and --config options to mem-police with a root privilege check.
- sora_prompt_builder.sh now accepts --copy, --dry-run, and --help flags with improved here-doc handling.
- Added --interactive mode to sora_prompt_builder.sh using prompt_toolkit with autocompletion and custom colors.
- Added --dry-run option to sora_prompt_builder.sh to print the Python command without executing.
- Added --help support to sora_prompt_builder.sh.
- Fixed shebang in promptlib.py and corrected interactive exit logic in sora_prompt_builder.sh.
- Interactive mode in sora_prompt_builder.sh now reads from /dev/tty and reports missing prompt_toolkit.
- Fixed interactive output handling to prevent 'responds_to_cpr' errors with prompt_toolkit.
- Improved interactive session to use prompt_toolkit\x27s create_input/create_output for stable TTY handling.
- Removed obsolete AUR helper function and cleaned up scripts/setup_dependencies.sh.

- Corrected create_input invocation for interactive mode.
- Added optional backup flag and improved VPN detection in ufw.sh; checks ExpressVPN DNS.
- Added ExpressVPN DNS firewall rules with automatic backup/restore hooks.
- Updated cleanup loops in ufw.sh to use run_cmd_dry and added dry-run verification test.
- Defined CAMERA_MOVE_TAGS via promptlib in sora_prompt_builder.sh and fixed PYTHONPATH export.
- Revised plugin_loader.py to use context managers for file reading.
- Added unit tests for plugin_loader and promptlib.
- Clipboard copying is now automatic; the --copy flag was removed and prompts are sanitized before being copied.
