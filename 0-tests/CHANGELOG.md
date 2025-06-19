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
- Fixed ufw.sh rule execution by parsing quoted rules correctly and handling ShellCheck warnings.
