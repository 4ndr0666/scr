#!/usr/bin/env bash
# ==============================================================================
# ☠️ 4ndr0tools filetree_packager.sh ☠️
# Core Operational Target: Universal Stream-Isolated Packaging Suite
# Engine Revision: Apex Polish, Canonical .skill Ext, Sealed Color Matrix
# Author: 4ndr0666
# License: MIT
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# UI / Color Matrix (Sealed)
# ------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
# Default Execution Parameters
# ------------------------------------------------------------------------------
MODE="FULL"
HEADLESS="false"
SINGLE_SKILL_NAME=""
FINAL_PACKAGE_ID="assembled-framework-distribution"
SKILLS_ONLY="false"
GENERATE_CHECKSUM="false"
QUIET="false"
VERBOSE="false"

# Centralized Exclusion Arrays (Canonical to package_skill.py)
EXCLUDE_DIRS=("__pycache__" "node_modules" ".git" ".github")
EXCLUDE_FILES=("*.pyc" ".DS_Store" "*.log" ".env" "*.tmp")
ROOT_EXCLUDE_DIRS=("evals")

# ------------------------------------------------------------------------------
# Logging Handlers
# ------------------------------------------------------------------------------
log_info() { if [ "$QUIET" == "false" ]; then echo -e "${CYAN}   -> ${NC}$1"; fi }
log_success() { if [ "$QUIET" == "false" ]; then echo -e "${GREEN}   ✅ ${NC}$1"; fi }
log_warn() { if [ "$QUIET" == "false" ]; then echo -e "${YELLOW}   ⚠️ WARNING: ${NC}$1"; fi }
log_error() { echo -e "${RED}   ❌ CRITICAL FAULT: ${NC}$1${NC}" >&2; }
log_verbose() { if [ "$VERBOSE" == "true" ] && [ "$QUIET" == "false" ]; then echo -e "${BLUE}      [VERBOSE] ${NC}$1"; fi }

# ------------------------------------------------------------------------------
# Phase 1: Argument Parsing & CI Auto-Detection
# ------------------------------------------------------------------------------
print_help() {
    echo -e "${RED}==============================================================================${NC}"
    echo -e "${YELLOW} ☠️ 4ndr0tools filetree_packager.sh - High-Capacity Workspace Packager${NC}"
    echo -e "${RED}==============================================================================${NC}"
    echo -e "${CYAN}Usage:${NC} $0 [OPTIONS]"
    echo ""
    echo -e "${CYAN}Options:${NC}"
    echo -e "  -f, --full              Comprehensive mode: package all discovered skills (Default)"
    echo -e "  -s, --selective         Interactive pruning: manually approve/reject each skill"
    echo -e "  --single SKILL_NAME     Single mode: Package ONLY the specified skill directory"
    echo -e "  -y, --headless          Non-interactive mode: assume yes, disable prompts (CI Safe)"
    echo -e "  -o, --output NAME       Custom output archive name (without extension)"
    echo -e "  -k, --skills-only       Skip structural foundation; package ONLY skills payload"
    echo -e "  -c, --checksum          Generate SHA256 cryptographic hash of final archive"
    echo -e "  -q, --quiet             Suppress standard execution output (errors will still print)"
    echo -e "  -v, --verbose           Enable deep diagnostic logging for each processed node"
    echo -e "  -h, --help              Display this execution manifesto"
    echo -e "${RED}==============================================================================${NC}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--full) MODE="FULL"; shift ;;
        -s|--selective) MODE="SELECTIVE"; shift ;;
        --single) SINGLE_SKILL_NAME="$2"; MODE="SINGLE"; shift 2 ;;
        -y|--headless) HEADLESS="true"; shift ;;
        -o|--output) FINAL_PACKAGE_ID="$2"; shift 2 ;;
        -k|--skills-only) SKILLS_ONLY="true"; shift ;;
        -c|--checksum) GENERATE_CHECKSUM="true"; shift ;;
        -q|--quiet) QUIET="true"; shift ;;
        -v|--verbose) VERBOSE="true"; shift ;;
        -h|--help) print_help; exit 0 ;;
        *) log_error "Unknown parameter: $1"; print_help; exit 1 ;;
    esac
done

if [ ! -t 0 ]; then
    log_warn "Non-TTY environment detected. Forcing HEADLESS mode."
    HEADLESS="true"
fi

if [ "$HEADLESS" == "true" ] && [ "$MODE" == "SELECTIVE" ]; then
    log_warn "Cannot use SELECTIVE interactive pruning in HEADLESS mode. Overriding to FULL mode."
    MODE="FULL"
fi

if [ "$QUIET" == "false" ]; then
    echo -e "${CYAN}🔬 Initiating pristine repository scanning protocol [Mode: ${MODE}]...${NC}"
fi

# ------------------------------------------------------------------------------
# Phase 2: Absolute Workspace Anchoring (Groot Protocol)
# ------------------------------------------------------------------------------
groot() {
    if git rev-parse --show-toplevel &> /dev/null; then
        cd "$(git rev-parse --show-toplevel)" || { log_error "Failed to change to Git repository root."; return 1; }
    else
        log_warn "Not inside a Git repository. Attempting fallback anchor detection..."
        local current_dir="$PWD"
        while [ "$current_dir" != "/" ]; do
            if [ -f "$current_dir/README.md" ] && [ -d "$current_dir/skills" ]; then
                cd "$current_dir" || { log_error "Failed to change to fallback root."; return 1; }
                return 0
            fi
            current_dir="$(dirname "$current_dir")"
        done
        log_error "Could not resolve absolute repository root. Ensure execution within the framework."
        return 1
    fi
}

groot || exit 1
WORKSPACE_ROOT="$PWD"
log_info "Anchored True Workspace Root: $WORKSPACE_ROOT"

if [ ! -d "$WORKSPACE_ROOT/skills" ]; then
    log_error "Target schema constraint failed. 'skills/' directory not found in root."
    exit 1
fi

STAGING_DIR="$WORKSPACE_ROOT/dynamic_build_stage"
OUTPUT_SKILL_FILE="$WORKSPACE_ROOT/${FINAL_PACKAGE_ID}.skill"
OUTPUT_TAR_FILE="$WORKSPACE_ROOT/${FINAL_PACKAGE_ID}.tar.gz"

# Pre-execution cleanup
rm -f "$OUTPUT_SKILL_FILE" "$OUTPUT_TAR_FILE"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/skills"

# ------------------------------------------------------------------------------
# Phase 3: Foundation Hydration (Configurable)
# ------------------------------------------------------------------------------
if [ "$MODE" != "SINGLE" ] && [ "$SKILLS_ONLY" == "false" ]; then
    log_info "Hydrating structural distribution foundation layers..."

    ROOT_FILES_TO_STAGE=("ATTACK_COVERAGE.md" "CITATION.cff" "index.json" "README.md")

    for asset in "${ROOT_FILES_TO_STAGE[@]}"; do
        if [ -f "$WORKSPACE_ROOT/$asset" ]; then
            cp "$WORKSPACE_ROOT/$asset" "$STAGING_DIR/"
            log_verbose "Staged root asset: $asset"
        fi
    done

    # Sync infrastructure frameworks
    for infrastructure_dir in "claude-plugin" "mappings" "tools" "skill_builder" "skill_creator"; do
        if [ -d "$WORKSPACE_ROOT/$infrastructure_dir" ]; then
            cp -r "$WORKSPACE_ROOT/$infrastructure_dir" "$STAGING_DIR/"
            log_verbose "Staged infrastructure module: $infrastructure_dir"
        fi
    done
elif [ "$SKILLS_ONLY" == "true" ]; then
    log_info "SKILLS_ONLY flag detected. Bypassing root infrastructure mapping."
fi

# ------------------------------------------------------------------------------
# Phase 4: Stream-Isolated Canonical Capability Ingestion
# ------------------------------------------------------------------------------
log_info "Processing operational skill folder structures..."

STAGED_COUNT=0
PROCESSED_COUNT=0

# Safely construct the dynamic find command to prevent array parsing bottlenecks
if [ "$MODE" == "SINGLE" ]; then
    TOTAL_DISCOVERED=1
    if [ ! -d "$WORKSPACE_ROOT/skills/$SINGLE_SKILL_NAME" ]; then
        log_error "Target skill directory not found: $WORKSPACE_ROOT/skills/$SINGLE_SKILL_NAME"
        exit 1
    fi
    FIND_CMD=("find" "$WORKSPACE_ROOT/skills/$SINGLE_SKILL_NAME" "-maxdepth" "0" "-type" "d" "-print0")
else
    TOTAL_DISCOVERED=$(find "$WORKSPACE_ROOT/skills" -maxdepth 1 -mindepth 1 -type d ! -name "dynamic_build_stage" | wc -l | xargs)
    FIND_CMD=("find" "$WORKSPACE_ROOT/skills" "-maxdepth" "1" "-mindepth" "1" "-type" "d" "!" "-name" "dynamic_build_stage" "-print0")
fi

log_info "Tracking $TOTAL_DISCOVERED targeted module directories..."

# Execute stream processing pipe mapped directly from find command array
while IFS= read -r -d '' skill_path; do
    skill_basename=$(basename "$skill_path")
    ((PROCESSED_COUNT++))
    
    # Inline UI Progress Bar
    if [ "$QUIET" == "false" ]; then
        if [ "$HEADLESS" == "false" ]; then
            printf "\r${CYAN}   -> Progress: [%d/%d] Scanning: %-40s${NC}" "$PROCESSED_COUNT" "$TOTAL_DISCOVERED" "${skill_basename:0:40}"
        elif (( PROCESSED_COUNT % 100 == 0 )) || [ "$PROCESSED_COUNT" -eq "$TOTAL_DISCOVERED" ]; then
            echo -e "${CYAN}   -> Processing batch [$PROCESSED_COUNT/$TOTAL_DISCOVERED]...${NC}"
        fi
    fi

    # Canonical Validation Constraint (Must possess SKILL.md)
    if [ ! -f "$skill_path/SKILL.md" ]; then
        if [ "$QUIET" == "false" ] && [ "$HEADLESS" == "false" ]; then echo ""; fi
        log_warn "Skipping $skill_basename: Canonical SKILL.md missing."
        continue
    fi

    skill_desc="Asset Container"
    extracted_desc=$(grep -i "^description:" "$skill_path/SKILL.md" | head -n 1 | sed 's/^description:[[:space:]]*//' | xargs || true)
    if [ -n "$extracted_desc" ]; then
        skill_desc="$extracted_desc"
    fi

    include_node="true"
    if [ "$MODE" == "SELECTIVE" ]; then
        echo ""
        echo -e "${YELLOW}   ---------------------------------------------------------------------------${NC}"
        echo -e "   Capability Path Node Discovered: ${GREEN}skills/$skill_basename${NC}"
        echo -e "   Dynamic Mapping Profile:        ${CYAN}$skill_desc${NC}"
        read -r -p "   [?] Authorize inclusion of this structure inside the payload bundle? [Y/n]: " node_choice < /dev/tty
        case "$node_choice" in
            [nN][oO]|[nN]) include_node="false" ;;
            *) include_node="true" ;;
        esac
    fi

    if [ "$include_node" == "true" ]; then
        dest_dir="$STAGING_DIR/skills/$skill_basename"
        mkdir -p "$dest_dir"
        
        # Subshell explicitly enforces dotglob to capture `.env` or other dotfiles safely
        (
            shopt -s dotglob
            cp -r "$skill_path"/* "$dest_dir/" 2>/dev/null || true
        )
        
        # ----------------------------------------------------------------------
        # Enhanced Canonical Compliance Filter
        # ----------------------------------------------------------------------
        # 1. Root exclusion ONLY for specific dirs (evals)
        for root_ex in "${ROOT_EXCLUDE_DIRS[@]}"; do
            if [ -d "$dest_dir/$root_ex" ]; then
                rm -rf "$dest_dir/$root_ex"
                log_verbose "Root exclusion applied: $root_ex inside $skill_basename"
            fi
        done
        
        # 2. Global recursive exclusions for unwanted directories
        for ex_dir in "${EXCLUDE_DIRS[@]}"; do
            find "$dest_dir" -type d -name "$ex_dir" -exec rm -rf {} + 2>/dev/null || true
        done
        
        # 3. Global recursive exclusions for unwanted files
        for ex_file in "${EXCLUDE_FILES[@]}"; do
            find "$dest_dir" -type f -name "$ex_file" -delete 2>/dev/null || true
        done
        
        # Post-Staging Validation Check
        if [ ! -f "$dest_dir/SKILL.md" ]; then
            log_error "Post-staging validation failed for $skill_basename. Missing SKILL.md in stage."
            rm -rf "$dest_dir"
            continue
        fi

        ((STAGED_COUNT++))
        log_verbose "Successfully staged node: $skill_basename"
    fi
done < <("${FIND_CMD[@]}" | sort -z)

if [ "$QUIET" == "false" ] && [ "$HEADLESS" == "false" ]; then echo ""; fi # Clear progress line
log_success "Capability processing stream complete."

# ------------------------------------------------------------------------------
# Phase 5: Continuous Telemetry Manifest Synthesis
# ------------------------------------------------------------------------------
log_info "Running live telemetry compilation manifest initialization..."
DYNAMIC_MANIFEST_OUT="$STAGING_DIR/compilation_manifest.json"

# Write headers
cat << EOF > "$DYNAMIC_MANIFEST_OUT"
{
  "distribution_package_id": "$FINAL_PACKAGE_ID",
  "build_timestamp_utc": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "metrics": {
    "total_skills_scanned": $TOTAL_DISCOVERED,
    "total_skills_staged": $STAGED_COUNT,
    "mode": "$MODE",
    "skills_only": $SKILLS_ONLY
  },
  "staged_file_nodes": [
EOF

# Write array elements continuously to prevent RAM saturation on massive trees
first_node="true"
while IFS= read -r file_node; do
    if [ -f "$file_node" ]; then
        rel_node_path="${file_node#$STAGING_DIR/}"
        node_size=$(wc -c < "$file_node" | xargs || echo "0")
        
        if [ "$first_node" == "false" ]; then
            printf ",\n" >> "$DYNAMIC_MANIFEST_OUT"
        fi
        
        # Sanitize JSON escaping natively
        safe_path="${rel_node_path//\\/\\\\}"
        safe_path="${safe_path//\"/\\\"}"
        
        printf '    {"path": "%s", "size_bytes": %s}' "$safe_path" "$node_size" >> "$DYNAMIC_MANIFEST_OUT"
        first_node="false"
    fi
done < <(find "$STAGING_DIR" -type f | sort)

printf '\n  ]\n}\n' >> "$DYNAMIC_MANIFEST_OUT"
log_success "Staging manifest verified and locked to target context location."

# ------------------------------------------------------------------------------
# Phase 6: Archive Compression Fallback & Checksum Generation
# ------------------------------------------------------------------------------
log_info "Executing archive serialization via subshell context..."

if command -v zip >/dev/null 2>&1; then
    # Create the canonical .skill archive (which is intrinsically a zip format)
    (cd "$STAGING_DIR" && zip -q -r "$OUTPUT_SKILL_FILE" ./*)
    FINAL_ARCHIVE="$OUTPUT_SKILL_FILE"
elif command -v tar >/dev/null 2>&1; then
    log_warn "System 'zip' compiler binary not found. Falling back to tar.gz compression."
    (cd "$STAGING_DIR" && tar -czf "$OUTPUT_TAR_FILE" ./*)
    FINAL_ARCHIVE="$OUTPUT_TAR_FILE"
else
    log_error "No compression engine (zip/tar) found on host system."
    echo -e "${YELLOW}   -> Staging paths compiled cleanly for manual reduction at: '$STAGING_DIR/'${NC}"
    exit 1
fi

FINAL_CHECKSUM="Not Requested"
if [ "$GENERATE_CHECKSUM" == "true" ]; then
    if command -v sha256sum >/dev/null 2>&1; then
        FINAL_CHECKSUM=$(sha256sum "$FINAL_ARCHIVE" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        FINAL_CHECKSUM=$(shasum -a 256 "$FINAL_ARCHIVE" | awk '{print $1}')
    else
        FINAL_CHECKSUM="Hashing Binary Unavailable"
    fi
fi

if [ "$QUIET" == "false" ]; then
    echo -e "${GREEN}==============================================================================${NC}"
    echo -e "${CYAN}💀Ψ Verification Complete: High-Capacity Workspace Tree Aggregation Successful${NC}"
    echo -e "${GREEN}==============================================================================${NC}"
    echo -e "📦 Output Container:     ${YELLOW}$FINAL_ARCHIVE${NC}"
    echo -e "📁 Modules Bound:         ${GREEN}$STAGED_COUNT / $TOTAL_DISCOVERED${NC} Capabilities Consolidated"
    echo -e "📄 Total Tracked Files:   $(find "$STAGING_DIR" -type f | wc -l | xargs)"
    if [ "$GENERATE_CHECKSUM" == "true" ]; then
        echo -e "🔐 SHA-256 Checksum:      ${CYAN}$FINAL_CHECKSUM${NC}"
    fi
    echo -e "${GREEN}==============================================================================${NC}"
fi

# Clean up staging partition
rm -rf "$STAGING_DIR"
exit 0
