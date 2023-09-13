#!/bin/bash
set -e

# Define default values for flags
FORCE=""
DEV=""
PROD=""
HELP=""
VERBOSE=""

# Define function to print help message
print_help() {
    echo "Usage: $0 [-f] [-d|-p] [-h] [-v]"
    echo "    -f, --force         Force uninstallation without prompting"
    echo "    -d, --dev           Install development dependencies"
    echo "    -p, --prod          Install production dependencies"
    echo "    -h, --help          Show this help message"
    echo "    -v, --verbose       Enable verbose mode"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -f|--force)
        FORCE="-y"
        shift
        ;;
        -d|--dev)
        DEV="1"
        shift
        ;;
        -p|--prod)
        PROD="1"
        shift
        ;;
        -h|--help)
        HELP="1"
        shift
        ;;
        -v|--verbose)
        VERBOSE="1"
        shift
        ;;
        *)
        echo "Unknown option: $1"
        print_help
        exit 1
        ;;
    esac
done

# If help flag is present, print help message and exit
if [ -n "$HELP" ]; then
    print_help
    exit 0
fi

# If neither dev nor prod flag is present, print help message and exit
if [ -z "$DEV" ] && [ -z "$PROD" ]; then
    echo "Either -d or -p flag must be provided."
    print_help
    exit 1
fi

# Check for necessary dependencies
command -v python3 >/dev/null 2>&1 || { echo >&2 "Python 3 is required but it's not installed. Aborting."; exit 1; }
command -v pip >/dev/null 2>&1 || { echo >&2 "pip is required but it's not installed. Aborting."; exit 1; }
command -v poetry >/dev/null 2>&1 || { echo >&2 "poetry is required but it's not installed. Aborting."; exit 1; }
command -v pipx >/dev/null 2>&1 || { echo >&2 "pipx is required but it's not installed. Aborting."; exit 1; }

# Create virtual environment
echo "Creating virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Upgrade pip within the virtual environment
echo "Upgrading pip within the virtual environment..."
pip install -U pip

# Install Meta Package Manager (MPM)
echo "Installing Meta Package Manager (MPM)..."
pip install meta-package-manager

# Take snapshot of installed packages before installation
echo "Taking snapshot of installed packages before installation..."
mpm --output-format toml snapshot > ~/.config/mpm/packages_before.toml

# Update all outdated packages within the virtual environment
echo "Updating outdated packages within the virtual environment..."
pip install -U $(pip list outdated 2> /dev/null | grep -v 'Version' | grep -v '\-\-\-\-\-\-' | awk '{printf $1 " " }' && echo)

# Install dependencies
if [ -n "$DEV" ]; then
    echo "Installing development dependencies..."
    poetry install --no-root
fi

if [ -n "$PROD" ]; then
    echo "Installing production dependencies..."
    poetry install --no-dev --no-root
fi

# Upgrade pipx packages
echo "Upgrading pipx packages..."
pipx upgrade-all

# Install packages from requirements.txt
echo "Installing packages from requirements.txt..."
pip install -r requirements.txt

# Take snapshot of installed packages after installation
echo "Taking snapshot of installed packages after installation..."
mpm --output-format toml snapshot > ~/.config/mpm/packages_after.toml

echo "Done!"
