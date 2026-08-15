#!/usr/bin/env bash
# ==============================================================================
# spotlight-exclusions.sh - Exclude caches, dependencies, and datasets from Spotlight
# ==============================================================================
# Usage:
#   spotlight-exclusions.sh                   # Run and sync all exclusions (forced)
#   spotlight-exclusions.sh --dry-run         # Preview changes without modifying
#   spotlight-exclusions.sh --scheduled       # Periodic run (skips if run in last 7 days)
#   spotlight-exclusions.sh --install-daemon  # Install weekly background job (LaunchAgent)
#   spotlight-exclusions.sh --uninstall-daemon# Remove background job
#   spotlight-exclusions.sh --list            # List currently excluded directories
#   spotlight-exclusions.sh --clean           # Remove .metadata_never_index tags
# ==============================================================================

set -euo pipefail

DAEMON_LABEL="com.diegobit.spotlight-exclusions"
MIN_INTERVAL_DAYS=7

# Resolve active user's HOME if running as root
if [ "${HOME:-}" = "/var/root" ] || [ -z "${HOME:-}" ]; then
    CONSOLE_USER=$(stat -f "%Su" /dev/console 2>/dev/null || echo "")
    if [ -n "$CONSOLE_USER" ] && [ "$CONSOLE_USER" != "root" ]; then
        HOME=$(eval echo "~$CONSOLE_USER")
        export HOME
    fi
fi

AGENT_DIR="$HOME/Library/LaunchAgents"
AGENT_PLIST="$AGENT_DIR/${DAEMON_LABEL}.plist"
LOG_FILE="$HOME/Library/Logs/spotlight-exclusions.log"
STAMP_DIR="$HOME/.local/state"
STAMP_FILE="$STAMP_DIR/spotlight-exclusions-last-run"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

CODE_DIR="${CODE_DIR:-$HOME/code}"

# 1. Global caches, runtimes, VM storage, and known heavy datasets
FIXED_EXCLUSIONS=(
    # Package & toolchain caches
    "$HOME/.cache"
    "$HOME/.npm"
    "$HOME/Library/pnpm"
    "$HOME/Library/Caches/pnpm"
    "$HOME/.rustup"
    "$HOME/.cargo/registry"
    "$HOME/.cargo/git"
    "$HOME/go/pkg"
    "$HOME/.m2/repository"
    "$HOME/.bun"
    "$HOME/.platformio"
    "$HOME/Library/Caches/Homebrew"
    "$HOME/Library/Caches/Yarn"
    "$HOME/Library/Caches/pip"
    "$HOME/Library/Caches/pypoetry"

    # AI models & local VMs
    "$HOME/.lmstudio"
    "$HOME/.ollama"
    "$HOME/Library/Application Support/Claude/vm_bundles"
    "$HOME/Library/Application Support/Ferdium/Partitions"
    "$HOME/dotfiles/.config/colima/_lima"
    "$HOME/.config/colima"
    "$HOME/Library/Caches/colima"

    # Heavy local project datasets
    "$HOME/code/next/next-ai-tts/dataset_creation"
    "$HOME/code/next/next-ai-tts/generate-wav"
)

# Dynamic dependency/build patterns to exclude inside $CODE_DIR
PATTERN_NAMES=(
    "node_modules"
    ".venv"
    "venv"
    "__pycache__"
    ".pytest_cache"
    ".mypy_cache"
    ".ruff_cache"
    ".tox"
    ".nox"
    ".next"
    ".turbo"
    ".svelte-kit"
    ".nuxt"
    ".docusaurus"
    "target"
    ".gradle"
    ".build"
    ".parcel-cache"
)

DRY_RUN=false
CLEAN_MODE=false
LIST_MODE=false
QUIET=false

show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Syncs Spotlight indexing exclusions by placing '.metadata_never_index'
files inside heavy caches, VM disks, datasets, and dev dependencies
(node_modules, .venv, build artifacts) under $CODE_DIR.

Options:
  -n, --dry-run          Preview directories that would be tagged without modifying
  -c, --clean            Remove all .metadata_never_index tags from target directories
  -l, --list             List all currently excluded directories
  -q, --quiet            Suppress progress logs (useful for background jobs)
      --scheduled        Periodic run (skips if run in the last $MIN_INTERVAL_DAYS days)
      --install-daemon   Install weekly background job (LaunchAgent, low CPU/IO)
      --uninstall-daemon Remove weekly background job
  -h, --help             Show this help message

Environment Variables:
  CODE_DIR               Root dev directory to scan (default: \$HOME/code)
EOF
}

# ------------------------------------------------------------------------------
# Daemon / LaunchAgent installation
# ------------------------------------------------------------------------------
install_daemon() {
    mkdir -p "$AGENT_DIR" "$STAMP_DIR" "$(dirname "$LOG_FILE")"

    echo "Creating LaunchAgent at $AGENT_PLIST..."
    cat <<EOF > "$AGENT_PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${DAEMON_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${SCRIPT_PATH}</string>
        <string>--scheduled</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>86400</integer>
    <key>LowPriorityIO</key>
    <true/>
    <key>Nice</key>
    <integer>19</integer>
    <key>ProcessType</key>
    <string>Background</string>
    <key>StandardOutPath</key>
    <string>${LOG_FILE}</string>
    <key>StandardErrorPath</key>
    <string>${LOG_FILE}</string>
</dict>
</plist>
EOF

    chmod 644 "$AGENT_PLIST"

    # Register with launchctl for current user session
    local uid
    uid=$(id -u)
    launchctl bootout "gui/${uid}/${DAEMON_LABEL}" 2>/dev/null || launchctl unload "$AGENT_PLIST" 2>/dev/null || true
    launchctl bootstrap "gui/${uid}" "$AGENT_PLIST" 2>/dev/null || launchctl load -w "$AGENT_PLIST" 2>/dev/null || true

    echo "✔ Weekly background Spotlight exclusion job installed (low CPU/IO, runs once a week)."
    exit 0
}

uninstall_daemon() {
    local uid
    uid=$(id -u)

    if [ -f "$AGENT_PLIST" ]; then
        launchctl bootout "gui/${uid}/${DAEMON_LABEL}" 2>/dev/null || launchctl unload "$AGENT_PLIST" 2>/dev/null || true
        rm -f "$AGENT_PLIST"
        echo "✔ LaunchAgent removed."
    else
        echo "LaunchAgent is not installed."
    fi
    exit 0
}

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-daemon|--install-agent)
            install_daemon
            ;;
        --uninstall-daemon|--uninstall-agent)
            uninstall_daemon
            ;;
        --scheduled)
            if [ -f "$STAMP_FILE" ]; then
                LAST_RUN=$(stat -f "%m" "$STAMP_FILE" 2>/dev/null || echo 0)
                NOW=$(date +%s)
                DIFF_DAYS=$(( (NOW - LAST_RUN) / 86400 ))
                if [ "$DIFF_DAYS" -lt "$MIN_INTERVAL_DAYS" ]; then
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Last Spotlight sync was $DIFF_DAYS day(s) ago (< $MIN_INTERVAL_DAYS). Skipping."
                    exit 0
                fi
            fi
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -c|--clean)
            CLEAN_MODE=true
            shift
            ;;
        -l|--list)
            LIST_MODE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

log() {
    if [ "$QUIET" = false ]; then
        echo "$@"
    fi
}

# ------------------------------------------------------------------------------
# Collect all matching target directories
# ------------------------------------------------------------------------------
collect_dynamic_targets() {
    if [ ! -d "$CODE_DIR" ]; then
        return 0
    fi

    if command -v fd >/dev/null 2>&1; then
        # Join PATTERN_NAMES into regex for fd
        local regex
        regex="^($(IFS='|'; echo "${PATTERN_NAMES[*]}"))$"
        fd -H -I -t d "$regex" "$CODE_DIR" --prune --max-depth 6 2>/dev/null || true
    else
        # Fallback to standard BSD find
        local find_args=()
        for pattern in "${PATTERN_NAMES[@]}"; do
            if [ ${#find_args[@]} -gt 0 ]; then
                find_args+=("-o")
            fi
            find_args+=("-name" "$pattern")
        done
        find "$CODE_DIR" -maxdepth 6 \( "${find_args[@]}" \) -type d -prune 2>/dev/null || true
    fi
}

# ------------------------------------------------------------------------------
# List mode: Display all currently excluded directories
# ------------------------------------------------------------------------------
if [ "$LIST_MODE" = true ]; then
    echo "==> Listing existing Spotlight exclusions (.metadata_never_index)..."
    count=0
    
    # Check fixed dirs
    for dir in "${FIXED_EXCLUSIONS[@]}"; do
        if [ -f "$dir/.metadata_never_index" ]; then
            echo "  [excluded] $dir"
            count=$((count + 1))
        fi
    done

    # Check code dir
    if [ -d "$CODE_DIR" ]; then
        if command -v fd >/dev/null 2>&1; then
            while IFS= read -r tag_file; do
                if [ -n "$tag_file" ]; then
                    echo "  [excluded] $(dirname "$tag_file")"
                    count=$((count + 1))
                fi
            done < <(fd -H -I -t f '^\.metadata_never_index$' "$CODE_DIR" 2>/dev/null || true)
        else
            while IFS= read -r tag_file; do
                if [ -n "$tag_file" ]; then
                    echo "  [excluded] $(dirname "$tag_file")"
                    count=$((count + 1))
                fi
            done < <(find "$CODE_DIR" -name ".metadata_never_index" -type f 2>/dev/null || true)
        fi
    fi

    echo ""
    echo "Total excluded locations found: $count"
    exit 0
fi

# ------------------------------------------------------------------------------
# Clean mode: Remove all .metadata_never_index tags
# ------------------------------------------------------------------------------
if [ "$CLEAN_MODE" = true ]; then
    log "==> Removing .metadata_never_index tags..."
    removed=0

    # Fixed paths
    for dir in "${FIXED_EXCLUSIONS[@]}"; do
        target_file="$dir/.metadata_never_index"
        if [ -f "$target_file" ]; then
            log "- Remove: $target_file"
            if [ "$DRY_RUN" = false ]; then
                rm -f "$target_file"
            fi
            removed=$((removed + 1))
        fi
    done

    # Dynamic project paths
    if [ -d "$CODE_DIR" ]; then
        if command -v fd >/dev/null 2>&1; then
            while IFS= read -r target_file; do
                if [ -n "$target_file" ] && [ -f "$target_file" ]; then
                    log "- Remove: $target_file"
                    if [ "$DRY_RUN" = false ]; then
                        rm -f "$target_file"
                    fi
                    removed=$((removed + 1))
                fi
            done < <(fd -H -I -t f '^\.metadata_never_index$' "$CODE_DIR" 2>/dev/null || true)
        else
            while IFS= read -r target_file; do
                if [ -n "$target_file" ] && [ -f "$target_file" ]; then
                    log "- Remove: $target_file"
                    if [ "$DRY_RUN" = false ]; then
                        rm -f "$target_file"
                    fi
                    removed=$((removed + 1))
                fi
            done < <(find "$CODE_DIR" -name ".metadata_never_index" -type f 2>/dev/null || true)
        fi
    fi

    log "✔ Removed $removed tag(s)."
    exit 0
fi

# ------------------------------------------------------------------------------
# Tagging Mode (Default): Add .metadata_never_index
# ------------------------------------------------------------------------------
if [ "$DRY_RUN" = true ]; then
    log "--- Running in DRY-RUN mode ---"
fi

new_tagged=0
already_tagged=0
skipped=0

tag_directory() {
    local target="$1"
    if [ ! -d "$target" ]; then
        skipped=$((skipped + 1))
        return 0
    fi

    local tag_file="$target/.metadata_never_index"
    if [ -f "$tag_file" ]; then
        already_tagged=$((already_tagged + 1))
    else
        log "+ Exclude: $target"
        if [ "$DRY_RUN" = false ]; then
            touch "$tag_file"
        fi
        new_tagged=$((new_tagged + 1))
    fi
}

log "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Spotlight exclusion sync..."
log "==> Tagging fixed caches, runtimes, and datasets..."
for dir in "${FIXED_EXCLUSIONS[@]}"; do
    tag_directory "$dir"
done

log "==> Scanning $CODE_DIR for dependency & build directories..."
while IFS= read -r dir; do
    [ -n "$dir" ] && tag_directory "$dir"
done < <(collect_dynamic_targets)

if [ "$DRY_RUN" = false ]; then
    mkdir -p "$STAMP_DIR"
    touch "$STAMP_FILE" 2>/dev/null || true
fi

log ""
log "✔ Done."
log "  • Newly excluded:   $new_tagged"
log "  • Already excluded: $already_tagged"
if [ "$DRY_RUN" = true ]; then
    log "  (Dry run complete. No files were written.)"
fi
