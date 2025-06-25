#!/usr/bin/env bash
# Author: 4ndr0666 
set -euo pipefail
# ================== // CODEX-MERGE-CLEAN.SH //
## Description: cleans <<<<<<</=======/>>>>>>> blocks (Codex or Git) 
#               from text files. Keeps the *upper* half (“ours”) by 
#               default; can optionally keep the lower.
# ----------------------------------------------------------

declare KEEP_UPPER=1 # set to 0 with --keep-lower

print_usage() {
    printf 'Usage: %s [--keep-lower] <file ...>\n' "${0##*/}"
    printf 'Removes merge-artifact blocks, keeping the chosen half.\n'
    exit 1
}

warn() { printf '%s\n' "$*" >&2; }

cleanup() {
    # Check if CURRENT_TMP_FILE is set and not empty, and if the file exists.
    if [ -n "${CURRENT_TMP_FILE:-}" ] && [ -f "${CURRENT_TMP_FILE}" ]; then
        warn "Cleaning up temporary file: ${CURRENT_TMP_FILE}"
        rm -f -- "${CURRENT_TMP_FILE}"
    fi
}
trap cleanup EXIT INT TERM

while [ $# -gt 0 ]; do
    case $1 in
        --keep-lower)
            KEEP_UPPER=0
            ;;
        -h|--help)
            print_usage
            ;;
        --) # End of options
            shift # Consume the --
            break
            ;;
        -*) # Unknown option
            warn "Unknown option: $1"
            print_usage
            ;;
        *) # First non-option argument (should be a file)
            break
            ;;
    esac
    shift # Consume the processed argument (option or file)
done

if [ $# -eq 0 ]; then
    warn "No files provided."
    print_usage
fi

declare CURRENT_TMP_FILE=""

for f in "$@"; do
    # Check if the argument is a regular file.
    if [ ! -f "$f" ]; then
        warn "Error: File not found or not a regular file: $f"
        # Continue to the next file instead of exiting the script entirely
        # for a single bad file, unless strict processing is required.
        # Original script exited, let's stick to that for consistency unless
        # specified otherwise, but warning and continuing is often better.
        # Sticking to original behavior: exit on first file error.
        exit 2 # Exit code 2 for file not found/invalid.
    fi

    # Create a unique temporary file in the same directory as the original file.
    # This helps prevent cross-device linking issues with mv.
    # Use XXXXXXXXXX pattern for mktemp to ensure uniqueness.
    CURRENT_TMP_FILE=$(mktemp "${f}.XXXXXXXXXX")
    # Check if mktemp succeeded.
    if [ $? -ne 0 ]; then
        warn "Error: Failed to create temporary file for $f"
        exit 3 # Exit code 3 for temporary file creation failure.
    fi

    # Process the file using awk to remove merge markers.
    # Pass the keep_upper variable to awk using -v.
    # The awk script is enclosed in single quotes to prevent shell expansion.
    # shellcheck disable=SC2016 # This disable is correct as $keep_upper is an awk variable.
    awk -v keep_upper="$KEEP_UPPER" '
        BEGIN { inside = 0; take = 1 } # Initialize state variables
        /^[[:space:]]*<{7}/ { # Match start of merge block (<<<<<<<)
            inside = 1;       # Set inside flag
            take = keep_upper; # Determine whether to take the upper block
            next              # Skip printing the marker line
        }
        /^[[:space:]]*={7}/ { # Match separator line (=======)
            if (inside) {     # Only process if inside a merge block
                take = !keep_upper; # Flip the take flag for the lower block
                next          # Skip printing the separator line
            }
            # If not inside, this line is just ======= and should be printed by the default rule
        }
        /^[[:space:]]*>{7}/ { # Match end of merge block (>>>>>>>)
            inside = 0;       # Clear inside flag
            next              # Skip printing the marker line
        }
        { # Default action for all other lines
            if (!inside) { # If not inside a merge block, print the line
                print;
                next
            }
            if (inside && take) { # If inside and currently taking this block
                sub(/\r$/, ""); # Remove carriage return (Windows line endings)
                print           # Print the line
            }
            # If inside and not taking, the line is simply skipped
        }
    ' "$f" > "${CURRENT_TMP_FILE}" # Redirect awk output to the temporary file

    # Check if the awk command executed successfully.
    if [ $? -ne 0 ]; then
        warn "Error: awk failed processing $f"
        # The trap will handle the cleanup of CURRENT_TMP_FILE.
        exit 4 # Exit code 4 for awk processing failure.
    fi

    # Atomically replace the original file with the processed temporary file.
    # Use -f to force overwrite, -- to handle filenames starting with -.
    mv -f -- "${CURRENT_TMP_FILE}" "$f"

    # Check if the mv command executed successfully.
    if [ $? -ne 0 ]; then
        warn "Error: mv failed replacing $f with processed content"
        # If mv failed, CURRENT_TMP_FILE might still exist or be partially moved.
        # The trap will attempt cleanup, which is the best we can do here.
        exit 5 # Exit code 5 for file replacement failure.
    fi

    # If mv succeeded, the temporary file is gone (it became the original file).
    # Clear the variable so the trap doesn't try to remove the original file.
    CURRENT_TMP_FILE=""

    # Processing for file $f is complete and successful.
done
