#!/usr/bin/env bash
# ==============================================================================
# tm-exclusions.sh - Sync Time Machine exclusions (caches, node_modules, venvs)
# ==============================================================================
# Usage:
#   tm-exclusions.sh                   # Run and sync all exclusions (manual/forced)
#   tm-exclusions.sh --dry-run         # Preview changes without modifying
#   tm-exclusions.sh --scheduled       # Periodic run (skips if run in last 7 days)
#   tm-exclusions.sh --install-daemon <schedule>
#                                     # Install background LaunchDaemon. <schedule> is required:
#                                     #   weekly    Sundays at 03:00 (alias for "0 3 * * 0")
#                                     #   daily     RunAtLoad + 24h retry, gated by the 7-day
#                                     #             limiter; catches up after sleep/power-off
#                                     #   "<cron>"  5-field cron spec (min hour dom month dow),
#                                     #             e.g. "30 4 * * 1,4" or "0 */6 * * *".
#                                     #             Supports *, N, A-B, /steps and , lists.
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

# Print a space-separated list of integers for one cron field, or the sentinel
# ANY for "*" (launchd omits the key, which it reads as "every"). ANY rather
# than a literal "*" because callers iterate the list unquoted, where a "*"
# would be glob-expanded to filenames.
# Supports: *, N, A-B, */S, A-B/S, and comma-separated lists of those.
expand_cron_field() {
    local spec="$1" min="$2" max="$3" name="$4"
    if [ "$spec" = "*" ]; then
        echo "ANY"
        return 0
    fi

    local -a items
    local item step start end i out=""
    IFS=, read -ra items <<< "$spec"
    for item in "${items[@]}"; do
        step=1
        case "$item" in
            */*)
                step="${item##*/}"
                item="${item%%/*}"
                ;;
        esac
        if ! [[ "$step" =~ ^[0-9]+$ ]] || [ "$step" -lt 1 ]; then
            echo "Invalid step in $name field: '$spec'" >&2
            exit 1
        fi
        case "$item" in
            '*')  start="$min"; end="$max" ;;
            *-*)  start="${item%%-*}"; end="${item##*-}" ;;
            *)    start="$item"; end="$item" ;;
        esac
        if ! [[ "$start" =~ ^[0-9]+$ ]] || ! [[ "$end" =~ ^[0-9]+$ ]]; then
            echo "Invalid $name field: '$spec' (expected numbers, ranges or *)" >&2
            exit 1
        fi
        if [ "$start" -lt "$min" ] || [ "$end" -gt "$max" ] || [ "$start" -gt "$end" ]; then
            echo "Invalid $name field: '$item' is out of range ($min-$max)" >&2
            exit 1
        fi
        for (( i = start; i <= end; i += step )); do
            out="$out $i"
        done
    done
    printf '%s\n' $out | sort -n -u | tr '\n' ' '
}

# Translate a 5-field cron spec into a StartCalendarInterval array of dicts.
cron_to_calendar_keys() {
    local cron="$1"
    local -a fields
    read -ra fields <<< "$cron"
    if [ "${#fields[@]}" -ne 5 ]; then
        echo "Invalid cron spec '$cron' (expected 5 fields: minute hour day-of-month month day-of-week)." >&2
        exit 1
    fi

    local minutes hours days months weekdays
    minutes=$(expand_cron_field "${fields[0]}" 0 59 minute) || exit 1
    hours=$(expand_cron_field "${fields[1]}" 0 23 hour) || exit 1
    days=$(expand_cron_field "${fields[2]}" 1 31 day-of-month) || exit 1
    months=$(expand_cron_field "${fields[3]}" 1 12 month) || exit 1
    weekdays=$(expand_cron_field "${fields[4]}" 0 7 day-of-week) || exit 1

    if [ "$minutes $hours $days $months $weekdays" = "ANY ANY ANY ANY ANY" ]; then
        echo "Refusing '* * * * *': that would run the sync every minute." >&2
        exit 1
    fi
    set -- $minutes
    if [ $# -gt 1 ]; then
        echo "Warning: '$cron' fires $# times per hour. This sync scans ~/code and is meant to" >&2
        echo "         run at most daily; consider a coarser schedule." >&2
    fi
    if [ "${fields[2]}" != "*" ] && [ "${fields[4]}" != "*" ]; then
        echo "Note: day-of-month and day-of-week are both restricted; launchd requires BOTH to match," >&2
        echo "      whereas cron would match either. Set one of them to '*' if you meant 'or'." >&2
    fi

    # launchd needs every combination enumerated, so guard against explosions
    local total=1 field
    for field in "$minutes" "$hours" "$days" "$months" "$weekdays"; do
        if [ "$field" != "ANY" ]; then
            set -- $field
            total=$(( total * $# ))
        fi
    done
    if [ "$total" -gt 100 ]; then
        echo "Cron spec '$cron' expands to $total launchd calendar entries (limit 100). Use a coarser schedule." >&2
        exit 1
    fi

    local dicts="" body mi ho da mo wd
    for mi in $minutes; do
      for ho in $hours; do
        for da in $days; do
          for mo in $months; do
            for wd in $weekdays; do
                body=""
                if [ "$mi" != "ANY" ]; then body="$body            <key>Minute</key>
            <integer>$mi</integer>
"; fi
                if [ "$ho" != "ANY" ]; then body="$body            <key>Hour</key>
            <integer>$ho</integer>
"; fi
                if [ "$da" != "ANY" ]; then body="$body            <key>Day</key>
            <integer>$da</integer>
"; fi
                if [ "$mo" != "ANY" ]; then body="$body            <key>Month</key>
            <integer>$mo</integer>
"; fi
                if [ "$wd" != "ANY" ]; then body="$body            <key>Weekday</key>
            <integer>$wd</integer>
"; fi
                dicts="$dicts        <dict>
$body        </dict>
"
            done
          done
        done
      done
    done

    printf '    <key>StartCalendarInterval</key>\n    <array>\n%s    </array>' "$dicts"
}

usage_schedule() {
    echo "Usage: $(basename "$0") --install-daemon <weekly|daily|\"<cron>\">" >&2
    echo "  weekly     Sundays at 03:00 (alias for \"0 3 * * 0\")" >&2
    echo "  daily      RunAtLoad + 24h retry, gated by the ${MIN_INTERVAL_DAYS}-day limiter" >&2
    echo "  \"<cron>\"   5-field cron spec, e.g. \"30 4 * * 1,4\" or \"0 */6 * * *\"" >&2
}

# Install background daemon. The schedule must be stated explicitly so the
# installed cadence is never an accident of the default.
install_daemon() {
    local schedule="${1:-}"
    if [ -z "$schedule" ]; then
        echo "Missing schedule for --install-daemon." >&2
        usage_schedule
        exit 1
    fi
    if [ "$EUID" -ne 0 ]; then
        echo "Elevating with sudo to install LaunchDaemon..."
        exec sudo "$0" --install-daemon "$schedule"
    fi

    local schedule_keys scheduled_arg description cron
    case "$schedule" in
        daily)
            # RunAtLoad + 24h retry, with --scheduled's rate limiter as the real
            # gate. Self-correcting: a missed window is retried the next day.
            schedule_keys="    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>86400</integer>"
            scheduled_arg="        <string>--scheduled</string>
"
            description="run-at-load + daily retry with ${MIN_INTERVAL_DAYS}-day limiter (resilient to reboots, sleeps, and power-offs)"
            ;;
        *)
            if [ "$schedule" = "weekly" ]; then
                cron="0 3 * * 0"
                description="Sundays at 03:00"
            else
                cron="$schedule"
                description="cron \"$cron\""
            fi
            schedule_keys=$(cron_to_calendar_keys "$cron") || exit 1
            # Deliberately no --scheduled: the calendar is the gate. Stacking the
            # 7-day limiter on top would skip the following run whenever one fires
            # late (machine asleep at 03:00 -> runs on wake), silently halving the
            # cadence to fortnightly.
            scheduled_arg=""
            ;;
    esac

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
${scheduled_arg}    </array>
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

    echo "✔ Background daemon installed: ${description} (low CPU/IO)."
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
