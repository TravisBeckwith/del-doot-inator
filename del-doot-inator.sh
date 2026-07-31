#!/bin/bash

# =============================================================================
# del-doot-inator — System-Wide Cache & Download Cleanup
# =============================================================================

VERSION="1.0.0"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Defaults
DRY_RUN=false
VERBOSE=false
AGGRESSIVE=false
LOG_FILE=""
INTERACTIVE=false
ONLY=()
SKIP=()

# Track results
CLEANED=()
SKIPPED=()
FAILED=()
WARNINGS=()
START_TIME=$(date +%s)

# =============================================================================
# HELP / USAGE
# =============================================================================
usage() {
    cat << 'EOF'

  ╔═══════════════════════════════════════════════════════════════════╗
  ║                        del-doot-inator                            ║
  ╚═══════════════════════════════════════════════════════════════════╝

  Removes cached downloads and leftover files from package managers
  after updates or installations. Does NOT remove packages themselves.

  USAGE:
      del-doot-inator [OPTIONS]

  OPTIONS:
      -h, --help              Show this help message
      -v, --version           Show version
      -n, --dry-run           Show what would be removed and estimated space
                              freed, without deleting anything
      -a, --aggressive        Deeper clean: removes all cached data, not just
                              stale downloads (see AGGRESSIVE NOTES below)
      -i, --interactive       Prompt before cleaning each manager
      -V, --verbose           Show detailed output for each command
      -l, --log <file>        Log all output to a file
      -o, --only <managers>   Only clean specified managers (comma-separated)
      -s, --skip <managers>   Skip specified managers (comma-separated)
      -L, --list              List detected package managers
      --no-color              Disable colored output

  AVAILABLE MANAGERS:
      apt, brew, pip, conda, npm, cargo, snap, flatpak, firmware

  AGGRESSIVE NOTES:
      --aggressive is safe in that it will never remove installed packages,
      but it clears more cache meaning slower next downloads/builds:
        apt       same (already clears everything by default)
        brew      --prune=all  (removes everything, not just 120-day-old files)
        conda     --all        (adds index cache, package cache, and lock files)
        cargo     removes entire registry + git source cache
                  (requires cargo-cache: cargo install cargo-cache)
        flatpak   removes unused runtimes and extensions
        pip/npm/snap/firmware  same as standard

  EXAMPLES:
      del-doot-inator                     # Clean everything (standard)
      del-doot-inator --dry-run           # Preview what would be removed
      del-doot-inator --aggressive        # Deep clean
      del-doot-inator --only apt,pip      # Only clean apt and pip
      del-doot-inator --skip conda,npm    # Skip conda and npm
      del-doot-inator --interactive       # Prompt before each manager

EOF
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--version)
            echo "del-doot-inator version $VERSION"
            exit 0
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -a|--aggressive)
            AGGRESSIVE=true
            shift
            ;;
        -i|--interactive)
            INTERACTIVE=true
            shift
            ;;
        -V|--verbose)
            VERBOSE=true
            shift
            ;;
        -l|--log)
            LOG_FILE="$2"
            shift 2
            ;;
        -o|--only)
            IFS=',' read -ra ONLY <<< "$2"
            shift 2
            ;;
        -s|--skip)
            IFS=',' read -ra SKIP <<< "$2"
            shift 2
            ;;
        -L|--list)
            echo "Detected package managers:"
            for mgr in apt brew pip conda npm cargo snap flatpak firmware; do
                if command -v "$mgr" &> /dev/null || \
                   { [ "$mgr" = "firmware" ] && command -v fwupdmgr &> /dev/null; } || \
                   { [ "$mgr" = "cargo" ] && command -v rustup &> /dev/null; }; then
                    echo -e "  ${GREEN}✔ ${mgr}${NC}"
                else
                    echo -e "  ${RED}✘ ${mgr}${NC} (not installed)"
                fi
            done
            exit 0
            ;;
        --no-color)
            GREEN='' YELLOW='' RED='' BLUE='' CYAN='' BOLD='' NC=''
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================
divider() {
    echo ""
    echo -e "${BLUE}=================================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}=================================================================${NC}"
    echo ""
}

success()  { echo -e "${GREEN}✔ $1${NC}"; }
warn()     { echo -e "${YELLOW}⚠ $1${NC}"; WARNINGS+=("$1"); }
error()    { echo -e "${RED}✘ $1${NC}"; }
info()     { echo -e "${CYAN}ℹ $1${NC}"; }
dry_info() { echo -e "${YELLOW}[DRY-RUN] $1${NC}"; }

log() {
    if [ -n "$LOG_FILE" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    fi
}

run_cmd() {
    local description="$1"
    shift

    if $VERBOSE; then
        info "Running: $*"
    fi
    log "Running: $*"

    if $DRY_RUN; then
        dry_info "$description"
        dry_info "  → $*"
        return 0
    fi

    if $VERBOSE; then
        "$@" 2>&1 | tee -a "${LOG_FILE:-/dev/null}"
        return "${PIPESTATUS[0]}"
    elif [ -n "$LOG_FILE" ]; then
        "$@" >> "$LOG_FILE" 2>&1
    else
        "$@"
    fi
}

should_clean() {
    local manager="$1"

    if [ ${#ONLY[@]} -gt 0 ]; then
        local found=false
        for o in "${ONLY[@]}"; do
            if [ "$o" = "$manager" ]; then
                found=true
                break
            fi
        done
        if ! $found; then
            return 1
        fi
    fi

    for s in "${SKIP[@]}"; do
        if [ "$s" = "$manager" ]; then
            SKIPPED+=("$manager (user skipped)")
            return 1
        fi
    done

    return 0
}

confirm() {
    local manager="$1"
    if $INTERACTIVE; then
        echo -ne "${BOLD}Clean ${manager}? [Y/n/q] ${NC}"
        read -r answer
        case "$answer" in
            [nN]) SKIPPED+=("$manager (user declined)"); return 1 ;;
            [qQ]) echo "Quitting."; exit 0 ;;
            *) return 0 ;;
        esac
    fi
    return 0
}

# Human-readable size of a path (returns 0 if path doesn't exist)
dir_size() {
    local path="$1"
    if [ -e "$path" ]; then
        du -sh "$path" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}

# =============================================================================
# CLEANERS
# =============================================================================

clean_apt() {
    if ! command -v apt &> /dev/null; then SKIPPED+=("apt"); return; fi
    if ! should_clean "apt"; then return; fi
    if ! confirm "apt"; then return; fi

    divider "Cleaning APT cache"

    local cache_dir="/var/cache/apt/archives"
    local before
    before=$(dir_size "$cache_dir")
    info "Cache size before: ${before}"

    # Standard and aggressive are the same for apt — 'clean' already removes
    # everything (as opposed to 'autoclean' which only removes stale debs).
    if $DRY_RUN; then
        dry_info "Would remove all .deb files from $cache_dir"
        dry_info "  → sudo apt clean"
        CLEANED+=("apt (${before}, dry-run)")
    else
        if run_cmd "Clean APT package cache" sudo apt clean; then
            local after
            after=$(dir_size "$cache_dir")
            CLEANED+=("apt (${before} → ${after})")
            success "APT cache cleaned"
            log "APT cache cleaned"
        else
            FAILED+=("apt")
            error "APT cache clean failed"
        fi
    fi
}

clean_brew() {
    if ! command -v brew &> /dev/null; then SKIPPED+=("brew"); return; fi
    if ! should_clean "brew"; then return; fi
    if ! confirm "brew"; then return; fi

    divider "Cleaning Homebrew cache"

    local cache_dir
    cache_dir=$(brew --cache 2>/dev/null)
    local before
    before=$(dir_size "$cache_dir")
    info "Cache size before: ${before}"

    if $DRY_RUN; then
        if $AGGRESSIVE; then
            dry_info "Would remove all cached downloads (--prune=all)"
            dry_info "  → brew cleanup --prune=all"
        else
            dry_info "Would remove cached downloads older than 120 days"
            dry_info "  → brew cleanup"
        fi
        CLEANED+=("brew (${before}, dry-run)")
    else
        local cmd_args=("brew" "cleanup")
        $AGGRESSIVE && cmd_args+=("--prune=all")

        if run_cmd "Clean Homebrew cache" "${cmd_args[@]}"; then
            local after
            after=$(dir_size "$cache_dir")
            CLEANED+=("brew (${before} → ${after})")
            success "Homebrew cache cleaned"
        else
            FAILED+=("brew")
            error "Homebrew cache clean failed"
        fi
    fi
}

clean_pip() {
    if ! command -v pip &> /dev/null && ! command -v pip3 &> /dev/null; then
        SKIPPED+=("pip")
        return
    fi
    if ! should_clean "pip"; then return; fi
    if ! confirm "pip"; then return; fi

    divider "Cleaning pip cache"

    # Prefer pip3 if available
    local pip_cmd="pip"
    command -v pip3 &> /dev/null && pip_cmd="pip3"

    local cache_dir
    cache_dir=$($pip_cmd cache dir 2>/dev/null)
    local before
    before=$(dir_size "$cache_dir")
    info "Cache size before: ${before}"

    # pip cache purge is the same regardless of --aggressive (it purges everything)
    if $DRY_RUN; then
        dry_info "Would purge all cached wheels and HTTP data from $cache_dir"
        dry_info "  → $pip_cmd cache purge"
        CLEANED+=("pip (${before}, dry-run)")
    else
        if run_cmd "Purge pip cache" "$pip_cmd" cache purge; then
            local after
            after=$(dir_size "$cache_dir")
            CLEANED+=("pip (${before} → ${after})")
            success "pip cache cleaned"
        else
            FAILED+=("pip")
            error "pip cache clean failed"
        fi
    fi
}

clean_conda() {
    if ! command -v conda &> /dev/null; then SKIPPED+=("conda"); return; fi
    if ! should_clean "conda"; then return; fi
    if ! confirm "conda"; then return; fi

    divider "Cleaning Conda cache"

    if $DRY_RUN; then
        if $AGGRESSIVE; then
            dry_info "Would remove tarballs, package cache, index cache, and lock files"
            dry_info "  → conda clean --all --yes"
        else
            dry_info "Would remove downloaded package tarballs only"
            dry_info "  → conda clean --tarballs --yes"
        fi
        CLEANED+=("conda (dry-run)")
    else
        local cmd_args=("conda" "clean" "--yes")
        if $AGGRESSIVE; then
            cmd_args+=("--all")
        else
            cmd_args+=("--tarballs")
        fi

        if run_cmd "Clean Conda cache" "${cmd_args[@]}"; then
            CLEANED+=("conda")
            success "Conda cache cleaned"
        else
            FAILED+=("conda")
            error "Conda cache clean failed"
        fi
    fi
}

clean_npm() {
    if ! command -v npm &> /dev/null; then SKIPPED+=("npm"); return; fi
    if ! should_clean "npm"; then return; fi
    if ! confirm "npm"; then return; fi

    divider "Cleaning npm cache"

    local cache_dir
    cache_dir=$(npm config get cache 2>/dev/null)
    local before
    before=$(dir_size "$cache_dir")
    info "Cache size before: ${before}"

    if $DRY_RUN; then
        dry_info "Would clean npm cache at $cache_dir"
        dry_info "  → npm cache clean --force"
        CLEANED+=("npm (${before}, dry-run)")
    else
        if run_cmd "Clean npm cache" npm cache clean --force; then
            local after
            after=$(dir_size "$cache_dir")
            CLEANED+=("npm (${before} → ${after})")
            success "npm cache cleaned"
        else
            FAILED+=("npm")
            error "npm cache clean failed"
        fi
    fi
}

clean_cargo() {
    if ! command -v cargo &> /dev/null; then SKIPPED+=("cargo"); return; fi
    if ! should_clean "cargo"; then return; fi
    if ! confirm "cargo"; then return; fi

    divider "Cleaning Cargo cache"

    if ! command -v cargo-cache &> /dev/null; then
        warn "cargo-cache not installed — skipping. Install with: cargo install cargo-cache"
        SKIPPED+=("cargo (cargo-cache not installed)")
        return
    fi

    local before
    before=$(dir_size "${CARGO_HOME:-$HOME/.cargo}/registry")

    if $DRY_RUN; then
        if $AGGRESSIVE; then
            dry_info "Would remove entire registry and git source cache"
            dry_info "  → cargo cache --remove-dir all"
        else
            dry_info "Would auto-clean stale registry cache"
            dry_info "  → cargo cache --autoclean"
        fi
        # Show what cargo cache itself reports
        cargo cache 2>/dev/null || true
        CLEANED+=("cargo (${before}, dry-run)")
    else
        local success_flag=false
        if $AGGRESSIVE; then
            if run_cmd "Remove entire cargo cache" cargo cache --remove-dir all; then
                success_flag=true
            fi
        else
            if run_cmd "Auto-clean cargo cache" cargo cache --autoclean; then
                success_flag=true
            fi
        fi

        if $success_flag; then
            local after
            after=$(dir_size "${CARGO_HOME:-$HOME/.cargo}/registry")
            CLEANED+=("cargo (${before} → ${after})")
            success "Cargo cache cleaned"
        else
            FAILED+=("cargo")
            error "Cargo cache clean failed"
        fi
    fi
}

clean_snap() {
    if ! command -v snap &> /dev/null; then SKIPPED+=("snap"); return; fi
    if ! should_clean "snap"; then return; fi
    if ! confirm "snap"; then return; fi

    divider "Cleaning Snap old revisions"

    # Collect snaps with old revisions: name, revision, status
    # 'snap list --all' shows all installed revisions; entries marked
    # 'disabled' are old revisions no longer active.
    local snap_data
    snap_data=$(snap list --all 2>/dev/null | awk 'NR>1 {print $1, $3, $NF}')

    if [ -z "$snap_data" ]; then
        info "No snap data found"
        SKIPPED+=("snap (no data)")
        return
    fi

    local found_any=false

    local snap_err_file
    snap_err_file=$(mktemp)
    trap 'rm -f "$snap_err_file"' RETURN

    while IFS= read -r line; do
        local name rev status
        name=$(echo "$line" | awk '{print $1}')
        rev=$(echo "$line"  | awk '{print $2}')
        status=$(echo "$line" | awk '{print $3}')

        if [ "$status" = "disabled" ]; then
            found_any=true
            if $DRY_RUN; then
                dry_info "Would remove: $name revision $rev"
            else
                info "Removing $name revision $rev..."
                # snap remove can fail if the snap is currently in use /
                # cannot be stopped — warn and skip rather than hard-fail.
                if sudo snap remove "$name" --revision="$rev" 2>"$snap_err_file"; then
                    success "Removed $name rev $rev"
                else
                    local snap_err
                    snap_err=$(cat "$snap_err_file")
                    warn "Could not remove $name rev $rev — ${snap_err:-snap may be in use or require a stopped state}. Skipping."
                fi
            fi
        fi
    done <<< "$snap_data"

    if ! $found_any; then
        success "No old snap revisions found"
    fi

    if $DRY_RUN; then
        CLEANED+=("snap (dry-run)")
    else
        CLEANED+=("snap")
        success "Snap old revision cleanup complete"
    fi
}

clean_flatpak() {
    if ! command -v flatpak &> /dev/null; then SKIPPED+=("flatpak"); return; fi
    if ! should_clean "flatpak"; then return; fi
    if ! confirm "flatpak"; then return; fi

    divider "Cleaning Flatpak"

    # Standard: clear the system and user download caches.
    # Flatpak does not expose a simple 'cache clean' command; the cache
    # lives under ~/.var/app (user) and /var/tmp/flatpak-cache (system).
    local user_cache="${XDG_CACHE_HOME:-$HOME/.cache}/flatpak"
    local sys_cache="/var/tmp/flatpak-cache"

    local before_user before_sys
    before_user=$(dir_size "$user_cache")
    before_sys=$(dir_size "$sys_cache")

    if $DRY_RUN; then
        dry_info "Would remove user flatpak cache ($before_user): $user_cache"
        dry_info "Would remove system flatpak cache ($before_sys): $sys_cache"
        if $AGGRESSIVE; then
            dry_info "Would also remove unused runtimes and extensions"
            dry_info "  → flatpak uninstall --unused -y"
        fi
        CLEANED+=("flatpak (dry-run)")
        return
    fi

    local ok=true

    # Remove user download cache
    if [ -d "$user_cache" ]; then
        if rm -rf "$user_cache"; then
            success "Removed user flatpak cache ($before_user)"
        else
            warn "Could not remove $user_cache"
            ok=false
        fi
    else
        info "No user flatpak cache found at $user_cache"
    fi

    # Remove system download cache (needs sudo)
    if [ -d "$sys_cache" ]; then
        if sudo rm -rf "$sys_cache"; then
            success "Removed system flatpak cache ($before_sys)"
        else
            warn "Could not remove $sys_cache"
            ok=false
        fi
    else
        info "No system flatpak cache found at $sys_cache"
    fi

    # Aggressive: also remove unused runtimes
    if $AGGRESSIVE; then
        info "Removing unused flatpak runtimes and extensions..."
        if run_cmd "Remove unused flatpak runtimes" flatpak uninstall --unused -y; then
            success "Unused flatpak runtimes removed"
        else
            warn "flatpak uninstall --unused had issues"
            ok=false
        fi
    fi

    if $ok; then
        CLEANED+=("flatpak")
        success "Flatpak cache cleaned"
    else
        FAILED+=("flatpak")
        error "Flatpak cache clean had errors"
    fi
}

clean_firmware() {
    if ! command -v fwupdmgr &> /dev/null; then SKIPPED+=("firmware"); return; fi
    if ! should_clean "firmware"; then return; fi
    if ! confirm "firmware"; then return; fi

    divider "Cleaning firmware update history"

    if $DRY_RUN; then
        dry_info "Would clear firmware update history and cached downloads"
        dry_info "  → fwupdmgr clear-history"
        CLEANED+=("firmware (dry-run)")
    else
        if run_cmd "Clear firmware history" fwupdmgr clear-history; then
            CLEANED+=("firmware")
            success "Firmware history cleared"
        else
            FAILED+=("firmware")
            error "Firmware history clear failed"
        fi
    fi
}

# =============================================================================
# SUMMARY
# =============================================================================
print_summary() {
    local end_time elapsed mins secs
    end_time=$(date +%s)
    elapsed=$((end_time - START_TIME))
    mins=$((elapsed / 60))
    secs=$((elapsed % 60))

    divider "CLEANUP SUMMARY"

    if $DRY_RUN; then
        echo -e "  ${YELLOW}${BOLD}*** DRY RUN — No files were removed ***${NC}"
        echo ""
    fi

    if $AGGRESSIVE && ! $DRY_RUN; then
        echo -e "  ${CYAN}${BOLD}(Aggressive mode)${NC}"
        echo ""
    fi

    if [ ${#CLEANED[@]} -gt 0 ]; then
        echo -e "${GREEN}${BOLD}Cleaned:${NC}"
        for item in "${CLEANED[@]}"; do
            echo -e "  ${GREEN}✔ ${item}${NC}"
        done
        echo ""
    fi

    if [ ${#SKIPPED[@]} -gt 0 ]; then
        echo -e "${YELLOW}${BOLD}Skipped:${NC}"
        for item in "${SKIPPED[@]}"; do
            echo -e "  ${YELLOW}– ${item}${NC}"
        done
        echo ""
    fi

    if [ ${#FAILED[@]} -gt 0 ]; then
        echo -e "${RED}${BOLD}Failed:${NC}"
        for item in "${FAILED[@]}"; do
            echo -e "  ${RED}✘ ${item}${NC}"
        done
        echo ""
    fi

    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo -e "${YELLOW}${BOLD}Warnings:${NC}"
        for item in "${WARNINGS[@]}"; do
            echo -e "  ${YELLOW}⚠ ${item}${NC}"
        done
        echo ""
    fi

    echo -e "${CYAN}Time elapsed: ${mins}m ${secs}s${NC}"

    if [ -n "$LOG_FILE" ]; then
        echo -e "${CYAN}Full log saved to: ${LOG_FILE}${NC}"
    fi

    echo ""
    echo -e "${GREEN}${BOLD}All done!${NC}"
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    if $DRY_RUN; then
        echo ""
        echo -e "${YELLOW}${BOLD}══════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}${BOLD}  DRY RUN MODE — No files will be removed${NC}"
        echo -e "${YELLOW}${BOLD}══════════════════════════════════════════════════${NC}"
    fi

    if $AGGRESSIVE; then
        echo ""
        echo -e "${RED}${BOLD}══════════════════════════════════════════════════${NC}"
        echo -e "${RED}${BOLD}  AGGRESSIVE MODE — Deeper clean; slower next run${NC}"
        echo -e "${RED}${BOLD}══════════════════════════════════════════════════${NC}"
    fi

    if [ -n "$LOG_FILE" ]; then
        echo "Cleanup started at $(date)" > "$LOG_FILE"
        info "Logging to: $LOG_FILE"
    fi

    clean_apt
    clean_brew
    clean_pip
    clean_conda
    clean_npm
    clean_cargo
    clean_snap
    clean_flatpak
    clean_firmware

    print_summary
}

main
