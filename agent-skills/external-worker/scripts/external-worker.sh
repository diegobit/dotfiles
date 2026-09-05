#!/usr/bin/env bash
# external-worker — unified launcher for external AI coding workers.
#
# Usage:
#   external-worker [--executor gemini|claude|cursor] [-r] [-d DIR] [--spill N] "task"
#   external-worker [--executor gemini|claude|cursor] -c [-d DIR] [--spill N] "correction"
#   external-worker [--executor gemini|claude|cursor] -p [-d DIR]
#   external-worker [--executor gemini|claude|cursor] -k [-d DIR]
#   external-worker [--executor gemini|claude|cursor] --selftest
#
#   -e, --executor  worker backend (gemini | claude | cursor; default: gemini)
#   -r, --read-only read-only mode (provider permission mode)
#   -d, --dir       workspace directory (default: $PWD)
#   -c, --continue  resume last session for this workspace and executor
#   -p, --peek      peek at live or last progress
#   -k, --kill      terminate a running worker
#   --spill N       cap report at N lines plus a file notice; 0 means unlimited
#   --selftest      verify wrapper operations against installed CLI
#   -h, --help      display this help
#
# stdout is the worker report (and path notice if capped).
# Exit: 0 ok · 1 worker error / cancellation / nonzero CLI exit with result
#       2 empty response · 3 no result / crash · 64 usage / invalid arguments.

set -eu

SCRIPT_PATH=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")

die() {
    printf 'external-worker: %s\n' "$1" >&2
    exit "${2:-64}"
}

# --- Default configuration ---
executor="gemini"
action="run"
read_only=0
read_only_flag_passed=0
dir=$PWD
spill_lines=${EW_SPILL_LINES-0}

STATE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/external-worker"

# Models and timeouts
EW_GEMINI_MODEL="gemini-3.8-flash"
EW_GEMINI_EFFORT="high"
EW_GEMINI_TIMEOUT="${EW_GEMINI_TIMEOUT:-10h}"

EW_CLAUDE_MODEL="claude-opus-5"
EW_CLAUDE_EFFORT="high"
EW_CLAUDE_BUDGET="${EW_CLAUDE_BUDGET:-}"

EW_CURSOR_MODEL="cursor-grok-4.6-high"

# --- Argument parsing ---
while [ $# -gt 0 ]; do
    case $1 in
        -e|--executor)
            [ $# -ge 2 ] || die "option $1 requires an argument" 64
            executor="$2"
            shift 2
            ;;
        -r|--read-only)
            read_only=1
            read_only_flag_passed=1
            shift
            ;;
        -d|--dir)
            [ $# -ge 2 ] || die "option $1 requires a path" 64
            dir="$2"
            shift 2
            ;;
        --spill)
            [ $# -ge 2 ] || die "option $1 requires a line count" 64
            spill_lines="$2"
            shift 2
            ;;
        -c|--continue)
            [ "$action" = "run" ] || die "cannot combine contradictory actions" 64
            action="continue"
            shift
            ;;
        -p|--peek)
            [ "$action" = "run" ] || die "cannot combine contradictory actions" 64
            action="peek"
            shift
            ;;
        -k|--kill)
            [ "$action" = "run" ] || die "cannot combine contradictory actions" 64
            action="kill"
            shift
            ;;
        --selftest)
            [ "$action" = "run" ] || die "cannot combine contradictory actions" 64
            action="selftest"
            shift
            ;;
        -n|--lane)
            die "lanes are not supported in external-worker" 64
            ;;
        -h|--help)
            sed -n '4,22p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            die "unknown option: $1" 64
            ;;
        *)
            break
            ;;
    esac
done

case "$executor" in
    gemini|claude|cursor) ;;
    *) die "unknown executor '$executor' (expected gemini, claude, or cursor)" 64 ;;
esac

case "$spill_lines" in
    ''|*[!0-9]*) die "--spill / EW_SPILL_LINES must be a nonnegative integer (0 means unlimited)" 64 ;;
esac
[ "$spill_lines" -ge 0 ] 2>/dev/null || die "spill line count is too large" 64

[ -d "$dir" ] || die "not a directory: $dir" 64
dir=$(cd "$dir" && pwd -P)

command -v jq >/dev/null 2>&1 || die "jq not found in PATH" 64

# --- State paths and identity ---
key=$(printf '%s' "$dir" | shasum | cut -c1-12)
state="$STATE_ROOT/$key/$executor"
mkdir -p "$state"

raw="$state/stream"
err="$state/err"
out="$state/report.out"
idf="$state/id"
modef="$state/mode"
lockdir="$state/lock"

# --- Locking and lifecycle helpers ---
is_running() {
    wpid=$(cat "$lockdir/wrapper.pid" 2>/dev/null || true)
    local stored_start current_start
    case "$wpid" in ''|*[!0-9]*) return 1 ;; esac
    [ "$wpid" -gt 1 ] || return 1
    stored_start=$(cat "$lockdir/wrapper.lstart" 2>/dev/null || true)
    [ -n "$stored_start" ] || return 1
    current_start=$(ps -p "$wpid" -o lstart= 2>/dev/null || true)
    [ "$stored_start" = "$current_start" ] && kill -0 "$wpid" 2>/dev/null
}

acquire_lock() {
    # Never steal a lock: missing metadata can mean its owner is still starting.
    # Automatic stale deletion races with other claimants and can permit two runs.
    mkdir "$lockdir" 2>/dev/null || return 1
    printf '%s\n' "$$" > "$lockdir/wrapper.pid"
    ps -p $$ -o lstart= > "$lockdir/wrapper.lstart"
}

release_my_lock() {
    if [ -f "$lockdir/wrapper.pid" ]; then
        local owner
        owner=$(cat "$lockdir/wrapper.pid" 2>/dev/null || true)
        if [ "$owner" = "$$" ]; then
            rm -rf "$lockdir"
        fi
    fi
}

# --- Provider-specific stream helpers ---
provider_partial() {
    case "$executor" in
        gemini)
            jq -j 'select(.event=="step_update").step_update.text_delta // ""' "$raw" 2>/dev/null || true
            ;;
        claude|cursor)
            jq -j 'select(.type=="assistant").message.content[]?
                   | select(.type=="text") | .text + "\n"' "$raw" 2>/dev/null || true
            ;;
    esac
}

provider_steps() {
    case "$executor" in
        gemini)
            jq -r 'select(.event=="step_update").step_update
                   | "  \(if .state=="ACTIVE" then "…" else "✓" end) \(.step_type)\(if .tool_name then " " + .tool_name else "" end)"' \
               "$raw" 2>/dev/null | awk '!seen[$0]++ || /…/' | tail -40
            ;;
        claude)
            jq -r 'select(.type=="assistant").message.content[]?
                   | select(.type=="tool_use")
                   | "  \(.name)\(if .input.command then ": " + (.input.command|tostring) elif .input.file_path then ": " + (.input.file_path|tostring) else "" end)"' \
               "$raw" 2>/dev/null | cut -c1-120 | tail -40
            ;;
        cursor)
            jq -r 'select(.type=="tool_call" and .subtype=="started") | .tool_call
                   | if .readToolCall then "  read: " + (.readToolCall.args.path // "")
                     elif .writeToolCall then "  write: " + (.writeToolCall.args.path // "")
                     elif .editToolCall then "  edit: " + (.editToolCall.args.path // "")
                     elif .shellToolCall then "  shell: " + (.shellToolCall.args.command // "")
                     elif .grepToolCall then "  grep: " + (.grepToolCall.args.pattern // "")
                     elif .globToolCall then "  glob: " + (.globToolCall.args.globPattern // .globToolCall.args.glob_pattern // "")
                     else "  " + ((keys - ["hookAdditionalContexts","startedAtMs","toolCallId"]) | join(","))
                     end' "$raw" 2>/dev/null | cut -c1-120 | tail -40
            ;;
    esac
}

save_report() {
    printf '%s\n' "$body" > "$out"
    if [ "$spill_lines" -gt 0 ] && [ "$(wc -l < "$out")" -gt "$spill_lines" ]; then
        head -n "$spill_lines" "$out"
        printf '\n[external-worker: report capped at %s lines. Full report: %s]\n' "$spill_lines" "$out"
    else
        cat "$out"
    fi
}

# --- Action: PEEK ---
if [ "$action" = "peek" ]; then
    [ $# -eq 0 ] || die "unexpected arguments for peek" 64
    [ -f "$raw" ] || die "no run recorded for executor '$executor' in $dir" 3
    if is_running; then
        worker_p=$(cat "$lockdir/worker.pid" 2>/dev/null || cat "$lockdir/wrapper.pid" 2>/dev/null || echo "unknown")
        printf 'status: RUNNING (pid %s)\n' "$worker_p"
        [ -f "$out" ] && printf 'previous report: %s\n' "$out"
    else
        printf 'status: finished\n'
        [ -f "$out" ] && printf 'last report: %s\n' "$out"
    fi
    if [ -f "$idf" ]; then
        case "$executor" in
            gemini) printf 'conversation: %s\n' "$(cat "$idf")" ;;
            claude|cursor) printf 'session: %s\n' "$(cat "$idf")" ;;
        esac
    fi
    printf 'workspace: %s\nsteps:\n' "$dir"
    provider_steps
    p=$(provider_partial)
    if [ -n "$p" ]; then
        printf 'output so far:\n'
        printf '%s\n' "$p" | sed 's/^/  /' | tail -30
    fi
    printf 'raw stream: %s\n' "$raw"
    exit 0
fi

# --- Action: KILL ---
if [ "$action" = "kill" ]; then
    [ $# -eq 0 ] || die "unexpected arguments for kill" 64
    if ! is_running; then
        die "no running worker for executor '$executor' in $dir" 1
    fi
    # is_running validates the wrapper PID and start time from the same snapshot.
    # The wrapper owns its child and saves partial output before releasing its lock.
    kill -TERM "$wpid" 2>/dev/null || die "worker already finished" 1
    printf 'external-worker: killed %s (wrapper pid %s); partial edits remain in %s\n' "$executor" "$wpid" "$dir" >&2
    exit 0
fi

# Local peek/kill above do not require a provider executable.
case "$executor" in
    gemini) bin=${EW_GEMINI_BIN:-agy} ;;
    claude) bin=${EW_CLAUDE_BIN:-claude} ;;
    cursor) bin=${EW_CURSOR_BIN:-agent} ;;
esac
command -v "$bin" >/dev/null 2>&1 || die "$executor binary not found in PATH: $bin" 64

# --- Action: SELFTEST ---
if [ "$action" = "selftest" ]; then
    [ $# -eq 0 ] || die "unexpected arguments for selftest" 64

    t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
    printf 'def add(a, b):\n    return a - b\n' > "$t/calc.py"
    before=$(shasum "$t/calc.py" | cut -d' ' -f1)
    printf 'MARKER-ZXQ97\n' > "$t/probe.txt"

    memory_token=$(uuidgen)
    printf 'selftest[%s]: workspace reachability and probe read... ' "$executor"
    probe=$("$SCRIPT_PATH" -e "$executor" -r -d "$t" --spill 0 \
        "Remember the token $memory_token for this conversation. Read probe.txt in your workspace and reply with its exact contents. If missing, reply NOTFOUND.")
    case "$probe" in
        *MARKER-ZXQ97*) printf 'PASS\n' ;;
        *) printf 'FAIL (probe unreadable: %s)\n' "$probe"; exit 1 ;;
    esac

    printf 'selftest[%s]: resumed read-only mode blocks writes and retains context... ' "$executor"
    readonly_report=$("$SCRIPT_PATH" -e "$executor" -c -d "$t" --spill 0 \
        "Fix calc.py so add adds instead of subtracting. Attempt the edit. Report the token I asked you to remember in the previous turn.")
    after=$(shasum "$t/calc.py" | cut -d' ' -f1)
    [ "$before" = "$after" ] || { printf 'FAIL (read-only mode modified calc.py)\n'; exit 1; }
    case "$readonly_report" in
        *"$memory_token"*) printf 'PASS\n' ;;
        *) printf 'FAIL (resume lost context: %s)\n' "$readonly_report"; exit 1 ;;
    esac

    printf 'selftest[%s]: write mode edits file, exits 0... ' "$executor"
    memory_token=$(uuidgen)
    "$SCRIPT_PATH" -e "$executor" -d "$t" --spill 0 \
        "Remember token $memory_token. Fix calc.py: add subtracts instead of adding. Edit it to return a + b." >/dev/null
    if grep -q 'a + b' "$t/calc.py"; then
        printf 'PASS\n'
    else
        printf 'FAIL (write mode did not fix calc.py)\n'; exit 1
    fi

    printf 'selftest[%s]: write session resume retains identity and context... ' "$executor"
    tstate=$STATE_ROOT/$(printf '%s' "$(cd "$t" && pwd -P)" | shasum | cut -c1-12)/$executor
    before_sid=$(cat "$tstate/id")
    resume_report=$("$SCRIPT_PATH" -e "$executor" -c -d "$t" --spill 0 \
        "Reply with only the token I asked you to remember in the previous turn.")
    [ "$before_sid" = "$(cat "$tstate/id")" ] || die "selftest session ID changed" 1
    case "$resume_report" in
        *"$memory_token"*) printf 'PASS\n' ;;
        *) printf 'FAIL (resume lost context: %s)\n' "$resume_report"; exit 1 ;;
    esac
    printf 'selftest[%s]: all checks passed against %s (production model)\n' "$executor" "$("$bin" --version)"

    exit 0
fi

# --- Actions: RUN / CONTINUE ---
# Obtain task text
if [ $# -gt 0 ]; then
    task="$*"
elif [ ! -t 0 ]; then
    task=$(cat)
else
    die "no task given (pass as arguments or on stdin)" 64
fi

task_trimmed="${task#"${task%%[![:space:]]*}"}"
[ -n "$task_trimmed" ] || die "task is empty" 64

# Atomic lock acquisition before touching session or output files
if ! acquire_lock; then
    die "executor '$executor' is already running or has an unresolved lock in $dir (peek with -p; inspect $lockdir before stale-lock recovery)" 1
fi

worker_pid=""

on_signal() {
    trap '' INT TERM
    if [ -n "${worker_pid:-}" ]; then
        kill -TERM "$worker_pid" 2>/dev/null || true
        wait "$worker_pid" 2>/dev/null || true
    fi
    body=$(provider_partial)
    save_report
    printf 'external-worker: %s was cancelled (partial output above, if any; peek: external-worker -e %s -p -d %s)\n' "$executor" "$executor" "$dir" >&2
    release_my_lock
    exit 1
}

trap 'release_my_lock' EXIT
trap 'on_signal INT' INT
trap 'on_signal TERM' TERM

# Continuation checks and mode inheritance
if [ "$action" = "continue" ]; then
    [ -f "$idf" ] || die "no previous worker for executor '$executor' in $dir" 1

    [ -s "$modef" ] || die "session mode is missing; start a fresh run" 1
    stored_mode=$(cat "$modef")
    case "$stored_mode" in read-only|write) ;; *) die "invalid saved session mode; start a fresh run" 1 ;; esac

    if [ "$stored_mode" = "read-only" ]; then
        read_only=1
    else
        if [ "$read_only_flag_passed" -eq 1 ]; then
            die "cannot continue a write session in read-only mode (mode changes require a fresh run)" 64
        fi
        read_only=0
    fi
else
    if [ "$read_only" -eq 1 ]; then
        target_mode="read-only"
    else
        target_mode="write"
    fi
fi

# Prepare state files for this run
if [ "$action" = "run" ]; then
    rm -f "$idf"
    printf '%s\n' "$target_mode" > "$modef"
fi

# Build provider argv
cmd=()
sid=""

case "$executor" in
    gemini)
        cmd=(-p "$task" --add-dir "$dir" --dangerously-skip-permissions --output-format stream-json --print-timeout "$EW_GEMINI_TIMEOUT")
        if [ "$action" = "continue" ]; then
            sid=$(cat "$idf")
            cmd+=(--conversation "$sid")
        else
            cmd+=(--model "$EW_GEMINI_MODEL" --effort "$EW_GEMINI_EFFORT")
        fi
        if [ "$read_only" -eq 1 ]; then
            cmd+=(--mode plan)
        fi
        ;;

    claude)
        cmd=(-p "$task" --output-format stream-json --verbose)
        if [ "$action" = "continue" ]; then
            sid=$(cat "$idf")
            cmd+=(--resume "$sid")
        else
            command -v uuidgen >/dev/null 2>&1 || die "uuidgen not found in PATH" 64
            sid=$(uuidgen | tr '[:upper:]' '[:lower:]')
            cmd+=(--session-id "$sid" --model "$EW_CLAUDE_MODEL" --effort "$EW_CLAUDE_EFFORT")
            printf '%s\n' "$sid" > "$idf"
        fi
        if [ "$read_only" -eq 1 ]; then
            cmd+=(--permission-mode plan)
        else
            cmd+=(--dangerously-skip-permissions)
        fi
        if [ -n "$EW_CLAUDE_BUDGET" ]; then
            cmd+=(--max-budget-usd "$EW_CLAUDE_BUDGET")
        fi
        ;;

    cursor)
        cmd=(-p "$task" --workspace "$dir" --force --trust --sandbox disabled --approve-mcps --output-format stream-json)
        if [ "$action" = "continue" ]; then
            sid=$(cat "$idf")
            cmd+=(--resume "$sid")
        else
            cmd+=(--model "$EW_CURSOR_MODEL")
        fi
        if [ "$read_only" -eq 1 ]; then
            cmd+=(--mode ask)
        fi
        ;;
esac

: > "$raw"
: > "$err"

# Launch worker CLI
( cd "$dir" && exec "$bin" "${cmd[@]}" ) > "$raw" 2>"$err" &
worker_pid=$!
printf '%s\n' "$worker_pid" > "$lockdir/worker.pid"
wls=$(ps -p "$worker_pid" -o lstart= 2>/dev/null || true)
printf '%s\n' "$wls" > "$lockdir/worker.lstart"

# Gemini and Cursor discover their session IDs from the initial stream event.
if [ -z "$sid" ]; then
    case "$executor" in
        gemini) session_field=conversation_id ;;
        cursor) session_field=session_id ;;
    esac
    n=0
    while [ "$n" -lt 200 ]; do
        sid=$(head -n5 "$raw" | jq -r --arg field "$session_field" '.[$field] // empty' 2>/dev/null | head -n1 || true)
        [ -n "$sid" ] && break
        kill -0 "$worker_pid" 2>/dev/null || break
        sleep 0.1
        n=$((n + 1))
    done
    [ -z "$sid" ] || printf '%s\n' "$sid" > "$idf"
fi
if [ -n "$sid" ]; then
    printf 'external-worker[%s]: session %s · peek: external-worker -e %s -p -d %s\n' "$executor" "$sid" "$executor" "$dir" >&2
fi

rc=0
wait "$worker_pid" || rc=$?

# Parse stream result event
result_present=0
is_error=0
body=""
error_detail=""
subtype=""

case "$executor" in
    gemini)
        res=$(jq -c 'select(.event=="result").result' "$raw" 2>/dev/null | tail -n1)
        if [ -n "$res" ]; then
            result_present=1
            st=$(printf '%s' "$res" | jq -r '.status // "UNKNOWN"')
            if [ "$st" = "SUCCESS" ]; then
                is_error=0
            else
                is_error=1
            fi
            body=$(printf '%s' "$res" | jq -r '.response // ""')
            error_detail=$(printf '%s' "$res" | jq -r '.error // "no detail"')
            subtype="$st"
        fi
        ;;

    claude|cursor)
        res=$(jq -c 'select(.type=="result")' "$raw" 2>/dev/null | tail -n1)
        if [ -n "$res" ]; then
            result_present=1
            subtype=$(printf '%s' "$res" | jq -r '.subtype // "unknown"')
            err_flag=$(printf '%s' "$res" | jq -r '.is_error // false')
            if [ "$err_flag" = "true" ] || [ "$subtype" != "success" ]; then
                is_error=1
            else
                is_error=0
            fi
            body=$(printf '%s' "$res" | jq -r '.result // ""')
            error_detail="$subtype"
        fi
        ;;
esac

if [ "$result_present" -eq 0 ]; then
    body=$(provider_partial)
    save_report
    [ -s "$err" ] && cut -c1-500 "$err" >&2
    die "no result event (crash, or $bin exited $rc) — see $raw" 3
fi

# A killed or errored run may report empty body in result; fall back to stream
[ -n "$body" ] || body=$(provider_partial)
save_report

if [ "$is_error" -eq 1 ] || [ "$rc" -ne 0 ]; then
    printf 'external-worker: %s error (status %s, exit %s) — %s (partial output above, if any; peek: external-worker -e %s -p -d %s)\n' \
        "$executor" "${subtype:-unknown}" "$rc" "$error_detail" "$executor" "$dir" >&2
    exit 1
fi

[ -n "$(printf '%s' "$body" | tr -d '[:space:]')" ] \
    || die "status success but empty response (see $raw)" 2

exit 0
