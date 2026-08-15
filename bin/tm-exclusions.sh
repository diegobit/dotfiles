#!/usr/bin/env bash
# ==============================================================================
# tm-exclusions.sh - Sync Time Machine exclusions (caches, node_modules, venvs)
# ==============================================================================

set -euo pipefail

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

echo "✔ Done."
