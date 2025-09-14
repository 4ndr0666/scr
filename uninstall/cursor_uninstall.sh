#!/bin/bash
# Cursor Complete Uninstall Script for 4ndr0666
# Author: AI Assistant
# Purpose: Remove all Cursor configurations and clean up everything we did
# Usage: ./cursor_uninstall.sh
# Version: 1.0 - Complete Cleanup

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration variables
CURSOR_CONFIG_DIR="$HOME/.config/Cursor"
WORKSPACE_CONFIG_DIR="$HOME/git/clone/.vscode"
SCRIPT_NAME="cursor_uninstall.sh"

# Files to remove
CURSOR_FILES=(
    "CURSOR_MASTERY_GUIDE.md"
    "CURSOR_PRODUCTION_GUIDE.md"
    "WORKING_SHORTCUTS.md"
    "TERMINAL_SOLUTION.md"
    "CURSOR_EXTENSIONS_GUIDE.md"
    "cursor_setup.sh"
    "setup_cursor.sh"
    "install_cursor_extensions.sh"
    "cleanup_cursor_mistakes.sh"
)

main() {
    log_info "Starting complete Cursor uninstall and cleanup..."
    
    # Check if we're running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        exit 1
    fi
    
    # Stop Cursor if running
    stop_cursor
    
    # Remove Cursor configurations
    remove_cursor_configs
    
    # Remove workspace configurations
    remove_workspace_configs
    
    # Remove documentation files
    remove_documentation
    
    # Remove setup scripts
    remove_setup_scripts
    
    # Remove Cursor AppImage
    remove_cursor_appimage
    
    # GitHub unlinking instructions
    show_github_unlink_instructions
    
    # Final cleanup verification
    verify_cleanup
    
    log_success "Complete Cursor uninstall completed successfully!"
}

stop_cursor() {
    log_info "Stopping Cursor if running..."
    
    if pgrep -f "Cursor.*AppImage" >/dev/null 2>&1; then
        log_info "Stopping Cursor AppImage..."
        pkill -f "Cursor.*AppImage"
        sleep 2
        log_success "Cursor stopped"
    else
        log_info "Cursor is not running"
    fi
}

remove_cursor_configs() {
    log_info "Removing Cursor configuration files..."
    
    if [[ -d "$CURSOR_CONFIG_DIR" ]]; then
        log_info "Removing Cursor config directory: $CURSOR_CONFIG_DIR"
        rm -rf "$CURSOR_CONFIG_DIR"
        log_success "Cursor configurations removed"
    else
        log_info "Cursor config directory not found"
    fi
}

remove_workspace_configs() {
    log_info "Removing workspace configuration files..."
    
    if [[ -d "$WORKSPACE_CONFIG_DIR" ]]; then
        log_info "Removing workspace config directory: $WORKSPACE_CONFIG_DIR"
        rm -rf "$WORKSPACE_CONFIG_DIR"
        log_success "Workspace configurations removed"
    else
        log_info "Workspace config directory not found"
    fi
}

remove_documentation() {
    log_info "Removing Cursor documentation files..."
    
    local removed_count=0
    for file in "${CURSOR_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            log_info "Removing: $file"
            rm -f "$file"
            ((removed_count++))
        fi
    done
    
    if [[ $removed_count -gt 0 ]]; then
        log_success "Removed $removed_count documentation files"
    else
        log_info "No documentation files found to remove"
    fi
}

remove_setup_scripts() {
    log_info "Removing Cursor setup scripts..."
    
    local scripts=(
        "cursor_setup.sh"
        "setup_cursor.sh"
        "install_cursor_extensions.sh"
        "cleanup_cursor_mistakes.sh"
        "cursor_setup_final.sh"
    )
    
    local removed_count=0
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            log_info "Removing: $script"
            rm -f "$script"
            ((removed_count++))
        fi
    done
    
    if [[ $removed_count -gt 0 ]]; then
        log_success "Removed $removed_count setup scripts"
    else
        log_info "No setup scripts found to remove"
    fi
}

remove_cursor_appimage() {
    log_info "Removing Cursor AppImage..."
    
    # Check if Cursor is installed as system command
    if command -v cursor >/dev/null 2>&1; then
        log_warning "Cursor is installed as system command at: $(which cursor)"
        log_info "To remove system installation, run: sudo rm /usr/bin/cursor"
        log_info "Or if you want to keep it: log_info 'Cursor system command preserved'"
    fi
    
    # Look for AppImage files
    local appimage_files=()
    while IFS= read -r -d '' file; do
        appimage_files+=("$file")
    done < <(find "/Nas/sandbox" -name "*Cursor*.AppImage" -type f -print0 2>/dev/null || true)
    
    if [[ ${#appimage_files[@]} -gt 0 ]]; then
        log_info "Found AppImage files:"
        for file in "${appimage_files[@]}"; do
            log_info "  $file"
        done
        log_warning "AppImage files found but not automatically removed"
        log_info "Remove manually if desired: rm /path/to/Cursor*.AppImage"
    else
        log_info "No AppImage files found"
    fi
}

show_github_unlink_instructions() {
    log_info "GitHub Unlinking Instructions:"
    echo ""
    echo "To unlink Cursor from GitHub:"
    echo ""
    echo "1. Open GitHub in your browser"
    echo "2. Go to Settings → Applications → Authorized OAuth Apps"
    echo "3. Find 'Cursor' or 'Cursor AI'"
    echo "4. Click 'Revoke' to remove access"
    echo ""
    echo "Alternative method:"
    echo "1. Go to https://github.com/settings/applications"
    echo "2. Find Cursor in the list"
    echo "3. Click 'Revoke'"
    echo ""
    echo "This will prevent Cursor from accessing your GitHub repositories."
    echo ""
}

verify_cleanup() {
    log_info "Verifying cleanup..."
    
    local issues_found=0
    
    # Check if Cursor config still exists
    if [[ -d "$CURSOR_CONFIG_DIR" ]]; then
        log_error "✗ Cursor config directory still exists: $CURSOR_CONFIG_DIR"
        ((issues_found++))
    else
        log_success "✓ Cursor config directory removed"
    fi
    
    # Check if workspace config still exists
    if [[ -d "$WORKSPACE_CONFIG_DIR" ]]; then
        log_error "✗ Workspace config directory still exists: $WORKSPACE_CONFIG_DIR"
        ((issues_found++))
    else
        log_success "✓ Workspace config directory removed"
    fi
    
    # Check for remaining documentation files
    local remaining_files=0
    for file in "${CURSOR_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            log_warning "⚠ Documentation file still exists: $file"
            ((remaining_files++))
        fi
    done
    
    if [[ $remaining_files -eq 0 ]]; then
        log_success "✓ All documentation files removed"
    else
        log_warning "⚠ $remaining_files documentation files remain"
        ((issues_found++))
    fi
    
    # Check if Cursor is still running
    if pgrep -f "Cursor.*AppImage" >/dev/null 2>&1; then
        log_error "✗ Cursor is still running"
        ((issues_found++))
    else
        log_success "✓ Cursor is not running"
    fi
    
    if [[ $issues_found -eq 0 ]]; then
        log_success "✓ Cleanup verification passed - all issues resolved"
    else
        log_warning "⚠ $issues_found issues found during cleanup verification"
    fi
}

# Error handling
trap 'log_error "Uninstall failed at line $LINENO"' ERR

# Execute main function
main

log_success "🚀 Complete Cursor uninstall completed!"
log_info "📋 Summary of what was removed:"
log_info "   ✓ Cursor configuration files"
log_info "   ✓ Workspace configuration files"
log_info "   ✓ Documentation files"
log_info "   ✓ Setup scripts"
log_info "   ✓ Cursor stopped (if running)"
log_info ""
log_info "🔗 Next steps:"
log_info "   1. Follow GitHub unlinking instructions above"
log_info "   2. Remove AppImage files manually if desired"
log_info "   3. Remove system command: sudo rm /usr/bin/cursor (if installed)"
log_info ""
log_info "🎯 Your system is now clean of Cursor configurations!"
log_info "💡 You can return to your preferred development workflow (Neovim + CLI AI)"
