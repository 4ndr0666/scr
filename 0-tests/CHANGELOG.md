## [UNRELEASED]
- Added 0-tests/codex-merge-clean.sh to remove CODEX merge artifacts.
- Mandatory use after every CODEX merge or edit before commit/PR.
- Added genre plugin loader tests for promptlib (test-genre-plugin-loader.bats).

- Implemented CanonicalParamLoader with hot reload and new tests.
- Improved media/ffx: added dependency checks, corrected audio option flags,
  and enhanced dry-run output.
- Added ffx-vidline.sh combining vidline features with multi-filter support and dry-run option.
- Improved ffx-vidline.sh ffmpeg status handling to catch failures correctly.
- Updated media test suites to skip when bats-support is missing and added README instructions.
- Updated pauseallmpv with help and dry-run; removed ls iteration.

- Refactored utilities/iso/makeiso.sh with modular functions, help and dry-run support.
- Added bkp-unified.sh combining backup methods with config and ISO support.
- Consolidated PKG_PATH detection into ensure_pkg_path in common.sh and updated dependent scripts.
- Refined security/network/ufw.sh with improved logging, rule validation, quoting, and re-enabled ShellCheck.
2025-06-19 • security/network/ufw.sh • +16/-4 • Handle missing expressvpn in --vpn flag
2025-06-20 • security/network/ufw.sh • +91/-22 • Added --status flag, swappiness option, comment support detection, and cleaned tmp logic
2025-06-23 • maintain/dependencies/deps • +43/-27 • Added dry-run mode, XDG temp usage, and argument fixes
2025-06-23 • maintain/dependencies/deps-beta • +1/-1 • Fix regex test for essential tools
2025-06-23 • maintain/dependencies/deps • +93/-3 • Merge beta features, ignore lists, and feature matrix
2025-06-23 • 4ndr0tools/4ndr0update/ANALYSIS.md • +63/-0 • Add code review analysis of 4ndr0update
2025-06-23 • 4ndr0tools/4ndr0update/ANALYSIS.md • +49/-63 • Expand review with rewrite approach and improvements
2025-06-23 • 4ndr0tools/4ndr0update/* • +366/-365 • Apply strict mode, fix bugs, and clean dead code

2025-06-24 • media/ffx_project/bin/ffxd • +129/-0 • Initial unified CLI skeleton
2025-06-25 • media/ffx_project/ffxd • +1052/-0 • Implement advanced prompt, auto-increment output, enhanced composite grid, clean options, and multi-stage atempo
2025-07-03 • media/dmx_project/dmxbeta • +18/-8 • Add Batch Enhance UI handler
2025-07-11 • 4ndr0tools/4ndr0service/* • +71/-70 • Remove global shellcheck disables and fix lint issues
2025-07-11 • media/ffxd • +138/-70 • Format script, fix temp dir creation, remove COMPOSITE flag
