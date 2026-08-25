#!/usr/bin/env bash
# ==============================================================================
# link-agent-skills.sh - Symlink agent-skills/ to AI harnesses
# ==============================================================================
# Locations:
#   .agents/skills/          -> ../../agent-skills/<name>
#   .claude/skills/          -> ../../agent-skills/<name>
#   .config/opencode/skills/ -> ../../../agent-skills/<name>
#   .gemini/config/skills/   -> ../../../agent-skills/<name>
#   ~/.claude/skills/        -> <relative path to>/.claude/skills/<name>
#   ~/.codex/skills/         -> <relative path to>/agent-skills/<name>
#   ~/.cursor/skills/        -> <relative path to>/agent-skills/<name>
#
# Usage:
#   link-agent-skills.sh         # Create/update all symlinks
#   link-agent-skills.sh --check # Verify existing symlinks without modifying
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENT_SKILLS_DIR="$DOTFILES_DIR/agent-skills"

CHECK_MODE=0
case "${1:-}" in
    --check)
        CHECK_MODE=1
        ;;
    -h|--help)
        echo "Usage: $(basename "$0") [--check]"
        exit 0
        ;;
    "")
        CHECK_MODE=0
        ;;
    *)
        echo "Unknown option: $1" >&2
        echo "Usage: $(basename "$0") [--check]" >&2
        exit 1
        ;;
esac

if [ ! -d "$AGENT_SKILLS_DIR" ]; then
    echo "Error: agent-skills directory not found at $AGENT_SKILLS_DIR" >&2
    exit 1
fi

# Find all skill directories in agent-skills/
skills=()
for skill_path in "$AGENT_SKILLS_DIR"/*; do
    if [ -d "$skill_path" ]; then
        skills+=("$(basename "$skill_path")")
    fi
done

if [ ${#skills[@]} -eq 0 ]; then
    echo "Error: no skill directories found in $AGENT_SKILLS_DIR" >&2
    exit 1
fi

# Locations configuration: array of "parent_dir|relative_target_prefix"
# For each skill: target is "${relative_target_prefix}${skill}"
# The four in-repo locations use fixed relative depths. The locations under $HOME must be
# computed because the repo is not necessarily at ~/dotfiles; hardcoding that produces
# broken links when the clone lives elsewhere.
relpath() {  # relpath <target> <start-dir>
    python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$1" "$2"
}
HOME_SKILLS="$HOME/.claude/skills"
HOME_PREFIX="$(relpath "$DOTFILES_DIR/.claude/skills" "$HOME_SKILLS")/"
CODEX_SKILLS="$HOME/.codex/skills"
CODEX_PREFIX="$(relpath "$AGENT_SKILLS_DIR" "$CODEX_SKILLS")/"
CURSOR_SKILLS="$HOME/.cursor/skills"
CURSOR_PREFIX="$(relpath "$AGENT_SKILLS_DIR" "$CURSOR_SKILLS")/"

locations=(
    "$DOTFILES_DIR/.agents/skills|../../agent-skills/"
    "$DOTFILES_DIR/.claude/skills|../../agent-skills/"
    "$DOTFILES_DIR/.config/opencode/skills|../../../agent-skills/"
    "$DOTFILES_DIR/.gemini/config/skills|../../../agent-skills/"
    "$HOME_SKILLS|$HOME_PREFIX"
    "$CODEX_SKILLS|$CODEX_PREFIX"
    "$CURSOR_SKILLS|$CURSOR_PREFIX"
)

errors=0
total=0

for loc in "${locations[@]}"; do
    dest_dir="${loc%%|*}"
    rel_prefix="${loc##*|}"

    for skill in "${skills[@]}"; do
        total=$((total + 1))
        link_path="$dest_dir/$skill"
        expected_target="${rel_prefix}${skill}"

        if [ "$CHECK_MODE" -eq 1 ]; then
            if [ ! -e "$link_path" ] && [ ! -L "$link_path" ]; then
                echo "MISSING: $link_path (expected -> $expected_target)"
                errors=$((errors + 1))
            elif [ ! -L "$link_path" ]; then
                echo "NOT_A_SYMLINK: $link_path is a regular file/directory"
                errors=$((errors + 1))
            else
                current_target="$(readlink "$link_path")"
                if [ "$current_target" != "$expected_target" ]; then
                    echo "MISMATCH: $link_path -> $current_target (expected -> $expected_target)"
                    errors=$((errors + 1))
                elif [ ! -e "$link_path" ]; then
                    echo "BROKEN: $link_path -> $current_target (target does not exist)"
                    errors=$((errors + 1))
                else
                    echo "OK: $link_path -> $current_target"
                fi
            fi
        else
            mkdir -p "$dest_dir"
            ln -sfn "$expected_target" "$link_path"
            echo "Linked: $link_path -> $expected_target"
        fi
    done
done

if [ "$CHECK_MODE" -eq 1 ]; then
    if [ "$errors" -gt 0 ]; then
        echo "Check failed: $errors of $total symlinks are missing or invalid." >&2
        exit 1
    else
        echo "Check passed: all $total skill symlinks are valid."
    fi
fi
