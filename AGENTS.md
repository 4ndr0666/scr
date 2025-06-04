# Codex Agent 

## Repo Index 

- Scripts in `4ndr0tools/` are my custom modular program suites and utilities. 
- `install/` contains package or system installers; each subfolder should be self-contained.
- `maintain/` holds automation for backups, cleanup, and ongoing system maintenance.
- `media/` is a sandbox for FFMPEG and multimedia manipulation. Always preserve lossless workflows unless lossy is specified.
- `security/` house scripts for network security, permissions, etc.
- `systemd/` scripts are bound to Arch-based unit management. Use `systemctl --user` unless root is explicitly required.
- `utilities/` is a general-purpose toolkit grouped by domain (`build`, `chroot`, `sysadmin`, etc.)

## Coding Directives

- Every script should be modular, testable, and XDG-compliant.
- Use `shellcheck` on all `.sh` and `.zsh` files.
- Prefer long-form flags (`--help`) and avoid short flags unless they follow industry convention.
- All scripts must support `--help` and `--dry-run` where appropriate.

## Testing Instructions

- Place all validation scripts in `scripts/integration_tests.sh` or the relevant test folder.
- Use `bats` or inline test harnesses where feasible.
- Mock destructive commands in dry-run mode.
- Find the CI plan in the .github/workflows folder.
- Run pnpm turbo run test --filter <project_name> to run every check defined for that package.
- From the package root you can just call pnpm test. The commit should pass all tests before you merge.
- To focus on one step, add the Vitest pattern: pnpm vitest run -t "<test name>".
- Fix any test or type errors until the whole suite is green.
- After moving files or changing imports, run pnpm lint --filter <project_name> to be sure ESLint and TypeScript rules still pass.
- Add or update tests for the code you change, even if nobody asked.

## Command Policies & Behavior

- Use `printf` over `echo`, support non-interactive and piped use.
- For scripts that modify the system state, enforce `sudo` validation and log actions to `$XDG_DATA_HOME/logs/`.
- All newly generated scripts must live in the appropriate category folder and be prefixed clearly (e.g., `ffx-*`, `exo-*`, `git-*`).
- Only make changes to scripts explicitly named or listed in the task prompt.
- For multi-file changes, maintain a clear changelog in `docs/CHANGELOG.md`.
- Write `task_outcome.md` to summarize any multi-step operations for review.
- Use pnpm dlx turbo run where <project_name> to jump to a package instead of scanning with ls.
- Run pnpm install --filter <project_name> to add the package to your workspace so Vite, ESLint, and TypeScript can see it.
- Use pnpm create vite@latest <project_name> -- --template react-ts to spin up a new React + Vite package with TypeScript checks ready.
- Check the name field inside each package's package.json to confirm the right name—skip the top-level one.
