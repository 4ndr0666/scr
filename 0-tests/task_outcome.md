Updated 4ndr0base-beta.sh with dry-run and help options
added tests.

Added CanonicalParamLoader module for Hailuo prompt parameters with tests.
Updated media merge tests to gracefully skip when bats-support is unavailable and documented the dependency.
Enhanced pauseallmpv with option parsing and strict mode.
Added bkp-unified.sh consolidating backup scripts with dry-run and ISO support.
Enhanced ufw.sh: fixed logging setup, improved rule validation and quoting, switched to printf, enabled ShellCheck.
Handled missing expressvpn command for --vpn flag in ufw.sh.
Implemented status reporting, swappiness parameter, UFW comment detection, and removed unused temp arrays.
Added dry-run option and XDG temp dir to maintain/dependencies/deps; improved argument parsing.
Tweaked deps-beta requirement check to avoid ShellCheck warning.
