## [UNRELEASED]
- Added 0-tests/codex-merge-clean.sh to remove CODEX merge artifacts.
- Mandatory use after every CODEX merge or edit before commit/PR.
- Added genre plugin loader tests for promptlib (test-genre-plugin-loader.bats).

- Implemented CanonicalParamLoader with hot reload and new tests.
- Improved media/ffx: added dependency checks, corrected audio option flags,
  and enhanced dry-run output.
- Added ffx-vidline.sh combining vidline features with multi-filter support and dry-run option.
- Improved ffx-vidline.sh ffmpeg status handling to catch failures correctly.
