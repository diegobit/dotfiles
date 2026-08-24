#!/usr/bin/env bash
# ==============================================================================
# tm-exclusions.sh - Sync Time Machine exclusions (caches, node_modules, venvs)
# ==============================================================================
# Usage:
#   tm-exclusions.sh                   # Run and sync all exclusions (manual/forced)
#   tm-exclusions.sh --dry-run         # Preview changes without modifying
#   tm-exclusions.sh --scheduled       # Periodic run (skips if run in last 7 days)
#   tm-exclusions.sh --install-daemon [daily|weekly]
#                                     # Install background LaunchDaemon
#                                     #   weekly (default): Sundays at 03:00
#                                     #   daily: run-at-load + daily retry (7-day limiter)
#   tm-exclusions.sh --uninstall-daemon# Remove background LaunchDaemon
# ==============================================================================

set -euo pipefail

DAEMON_LABEL="com.diegobit.tm-exclusions"
DAEMON_PLIST="/Library/LaunchDaemons/${DAEMON_LABEL}.plist"
STAMP_FILE="/var/tmp/.tm-exclusions-last-run"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
MIN_INTERVAL_DAYS=7

# If running as root (e.g. via launchd daemon), dynamically resolve the active user's home
if [ "${HOME:-}" = "/var/root" ] || [ -z "${HOME:-}" ]; then
    CONSOLE_USER=$(stat -f "%Su" /dev/console 2>/dev/null || echo "")
    if [ -n "$CONSOLE_USER" ] && [ "$CONSOLE_USER" != "root" ]; then
        HOME=$(eval echo "~$CONSOLE_USER")
        export HOME
    fi
fi

# 1. Standard global caches and heavy disposable directories
EXCLUSIONS=(
    "$HOME/.npm"
    "$HOME/Library/pnpm"
    "$HOME/.rustup"
    "$HOME/.cargo/registry"
    "$HOME/.cargo/git"
    "$HOME/go/pkg"
    "$HOME/.m2/repository"
    "$HOME/.bun"
    "$HOME/.cache"
    "$HOME/.platformio"
    "$HOME/.lmstudio"
    "$HOME/.ollama"
    "$HOME/Library/Application Support/Claude/vm_bundles"
    "$HOME/Library/Application Support/Ferdium/Partitions"
    "$HOME/dotfiles/.config/colima/_lima"
)

# Install background daemon (weekly: Sundays 03:00; daily: RunAtLoad + daily interval with 7-day rate limiter)
install_daemon() {
    local schedule="${1:-weekly}"
    if [ "$schedule" != "daily" ] && [ "$schedule" != "weekly" ]; then
        echo "Unknown schedule '$schedule' (expected 'daily' or 'weekly')."
        exit 1
    fi
    if [ "$EUID" -ne 0 ]; then
        echo "Elevating with sudo to install LaunchDaemon..."
        exec sudo "$0" --install-daemon "$schedule"
    fi

    local schedule_keys
    if [ "$schedule" = "daily" ]; then
        schedule_keys="    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>86400</integer>"
    else
        schedule_keys="    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>7</integer>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>"
    fi

    echo "Creating LaunchDaemon at $DAEMON_PLIST..."
    cat <<EOF > "$DAEMON_PLIST"
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
${schedule_keys}
    <key>LowPriorityIO</key>
    <true/>
    <key>Nice</key>
    <integer>19</integer>
    <key>ProcessType</key>
    <string>Background</string>
    <key>StandardOutPath</key>
    <string>/var/log/tm-exclusions.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/tm-exclusions.log</string>
</dict>
</plist>
EOF

    chmod 644 "$DAEMON_PLIST"
    chown root:wheel "$DAEMON_PLIST"

    # Reload daemon
    launchctl bootout "system/${DAEMON_LABEL}" 2>/dev/null || launchctl unload "$DAEMON_PLIST" 2>/dev/null || true
    launchctl bootstrap system "$DAEMON_PLIST" 2>/dev/null || launchctl load -w "$DAEMON_PLIST" 2>/dev/null || true

    if [ "$schedule" = "weekly" ]; then
        echo "✔ Background daemon installed: Sundays at 03:00 (low CPU/IO)."
    else
        echo "✔ Background daemon installed: run-at-load + daily retry with 7-day limiter (resilient to reboots, sleeps, and power-offs; low CPU/IO)."
    fi
    exit 0
}

# Uninstall background daemon
uninstall_daemon() {
    if [ "$EUID" -ne 0 ]; then
        echo "Elevating with sudo to remove LaunchDaemon..."
        exec sudo "$0" --uninstall-daemon
    fi

    if [ -f "$DAEMON_PLIST" ]; then
        launchctl bootout "system/${DAEMON_LABEL}" 2>/dev/null || launchctl unload "$DAEMON_PLIST" 2>/dev/null || true
        rm -f "$DAEMON_PLIST"
        echo "✔ LaunchDaemon removed."
    else
        echo "LaunchDaemon is not installed."
    fi
    exit 0
}

# Handle daemon install/uninstall flags
case "${1:-}" in
    --install-daemon)
        install_daemon "${2:-}"
        ;;
    --uninstall-daemon)
        uninstall_daemon
        ;;
esac

# Check rate limit if invoked with --scheduled (for launchd background runs)
if [[ "${1:-}" == "--scheduled" ]]; then
    if [ -f "$STAMP_FILE" ]; then
        LAST_RUN=$(stat -f "%m" "$STAMP_FILE" 2>/dev/null || echo 0)
        NOW=$(date +%s)
        DIFF_DAYS=$(( (NOW - LAST_RUN) / 86400 ))
        if [ "$DIFF_DAYS" -lt "$MIN_INTERVAL_DAYS" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Last sync was $DIFF_DAYS day(s) ago (< $MIN_INTERVAL_DAYS). Skipping."
            exit 0
        fi
    fi
fi

# Elevate privileges if not dry-run
if [[ "${1:-}" != "--dry-run" && "${1:-}" != "-n" && "$EUID" -ne 0 ]]; then
    echo "Elevating with sudo for tmutil SkipPaths..."
    exec sudo "$0" "$@"
fi

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]]; then
    DRY_RUN=true
    echo "--- Running in DRY-RUN mode ---"
fi

# Helper: exclude path if not already excluded
add_exclusion() {
    local target="$1"
    [ ! -e "$target" ] && return 0

    local status
    status=$(tmutil isexcluded "$target" 2>/dev/null || true)
    if [[ "$status" != *"[Excluded]"* ]]; then
        echo "+ Exclude: $target"
        if [ "$DRY_RUN" = false ]; then
            tmutil addexclusion -p "$target" 2>/dev/null || echo "  (failed: requires Full Disk Access in Privacy settings)"
        fi
    fi
}

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Time Machine exclusion sync..."
echo "==> Syncing fixed caches..."
for dir in "${EXCLUSIONS[@]}"; do
    add_exclusion "$dir"
done

echo "==> Scanning ~/code for node_modules and .venv..."
if [ -d "$HOME/code" ]; then
    while IFS= read -r dir; do
        [ -n "$dir" ] && add_exclusion "$dir"
    done < <(find "$HOME/code" -maxdepth 6 \( -name "node_modules" -o -name ".venv" -o -name "venv" \) -type d -prune 2>/dev/null)
fi

echo "==> Cleaning stale/dead paths from Time Machine..."
current_skippaths=$(defaults read /Library/Preferences/com.apple.TimeMachine SkipPaths 2>/dev/null | tr -d '",()' | sed 's/^[ \t]*//' | grep -v '^$' || true)
while IFS= read -r item; do
    [ -z "$item" ] && continue
    [[ "$item" == *"colima/_lima"* ]] && continue # Keep colima sticky

    if [ ! -e "$item" ]; then
        echo "- Remove dead path: $item"
        if [ "$DRY_RUN" = false ]; then
            tmutil removeexclusion -p "$item" 2>/dev/null || true
        fi
    fi
done <<< "$current_skippaths"

if [ "$DRY_RUN" = false ]; then
    touch "$STAMP_FILE" 2>/dev/null || true
fi

echo "✔ Done."
