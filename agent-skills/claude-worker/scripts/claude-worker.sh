#!/bin/sh
# claude-worker — spawn a Claude Opus 5 worker via the Claude Code CLI.
#
# Usage:
#   claude-worker [-r] [-d DIR] [-n LANE] "task text"   spawn a worker (task may also come from stdin)
#   claude-worker -c [-n LANE] "correction"             resume this lane's last worker
#   claude-worker -p [-n LANE]                          peek at live/last progress
#   claude-worker -k [-n LANE]                          kill a running worker
#   claude-worker --selftest                            verify this wrapper against the real claude CLI
#
#   -r  read-only (plan mode; writes blocked by the harness, not by the prompt)
#   -d  workspace directory (default: $PWD)
#   -n  lane name (default: "default") — one concurrent worker per lane
#
# stdout is the worker's report and nothing else, so it is safe to pipe.
# Exit: 0 ok · 1 the CLI reported an error (includes -k kill) · 2 empty response
#       3 no result event at all (crash) · 64 usage.
# On any failure, whatever the worker had already produced is still printed to
# stdout, reconstructed from the stream — partial work is never thrown away.
#
# ---------------------------------------------------------------------------
# IF YOU ARE AN AGENT AND THIS SCRIPT IS MISBEHAVING, READ THIS
# ---------------------------------------------------------------------------
# This wrapper hides six quirks of `claude -p`, several of which fail SILENTLY
# (quirk 2 is the dangerous one). Each was verified empirically against the
# version below. If the CLI changes, re-verify the relevant fact, patch the one
# marked line, and update ../SKILL.md in the same commit so the two never drift.
#
# 1. The workspace is the PROCESS CWD, not a flag. Unlike agy (see flash-worker),
#    `claude` resolves the agent's file tools against the directory it was
#    started in, so this script `cd`s into -d and does not pass --add-dir.
#    Verified: a worker started in a temp dir read ./probe.txt with no --add-dir.
#
# 2. --dangerously-skip-permissions OVERRIDES --permission-mode plan. Passing
#    both silently re-enables writes, so a "read-only" run edits the workspace.
#    This is the exact INVERSE of flash-worker, where plan mode needs the skip
#    flag. Read-only mode here must pass --permission-mode plan ALONE.
#    Verified, in a temp dir containing a buggy calc.py:
#      claude -p "fix the bug in calc.py, edit the file" --permission-mode plan \
#             --dangerously-skip-permissions ...      -> file WAS modified
#      claude -p "…same…" --permission-mode plan ...  -> file unchanged, while
#             Read and Bash still worked (it reported probe.txt and `ls|wc -l`)
#    So plan mode alone does NOT auto-deny its own read tools; do not "fix" this
#    by adding the skip flag back.
#
# 3. --output-format stream-json REQUIRES --verbose under --print, or the CLI
#    exits immediately with "requires --verbose" and produces no stream at all.
#
# 4. `claude -c` continues the most recent conversation in the current directory,
#    so it targets the wrong worker whenever lanes share a workspace. We generate
#    the session id ourselves, pass --session-id on spawn, and resume by explicit
#    --resume <id>. Never reintroduce -c, and never add --fork-session (it would
#    change the id out from under the lane). Verified: --resume keeps the same
#    session_id and inherits the model, so --model/--effort must NOT be re-sent.
#
# 5. Read-only workers cannot call ExitPlanMode (the tool is absent under -p).
#    They say so and then report normally — harmless. They may also leave a plan
#    file under ~/.claude/plans/, which is outside the workspace, so a read-only
#    run still leaves `git diff` clean.
#
# 6. subtype == "success" does NOT mean the task succeeded — only that the CLI
#    ran. An empty .result is a failure (exit 2). The worker's own STATUS: /
#    EVIDENCE: lines are the real signal; the caller must still read them.
#
# Also: the stream is line-delimited JSON with escaped \n. Never `echo` a
# captured line — echo expands those escapes. Use printf '%s' or a file.
#
# Run `claude-worker --selftest` to check quirks 1, 2, 3 and 6 against the
# installed CLI.
# ---------------------------------------------------------------------------

set -eu

CLAUDE=${CW_CLAUDE:-claude}
MODEL=${CW_MODEL:-claude-opus-5}
EFFORT=${CW_EFFORT:-high}             # low | medium | high | xhigh | max
BUDGET=${CW_BUDGET:-}                 # optional USD cap, e.g. CW_BUDGET=5
STATE_ROOT=${XDG_CACHE_HOME:-$HOME/.cache}/claude-worker

die() { printf 'claude-worker: %s\n' "$1" >&2; exit "${2:-64}"; }

lane=default
dir=$PWD
plan=0
action=run

while [ $# -gt 0 ]; do
    case $1 in
        -r|--read-only) plan=1; shift ;;
        -d|--dir)       [ $# -ge 2 ] || die "-d needs a path"; dir=$2; shift 2 ;;
        -n|--lane)      [ $# -ge 2 ] || die "-n needs a name"; lane=$2; shift 2 ;;
        -c|--continue)  action=continue; shift ;;
        -p|--peek)      action=peek; shift ;;
        -k|--kill)      action=kill; shift ;;
        --selftest)     action=selftest; shift ;;
        -h|--help)      sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        --)             shift; break ;;
        -*)             die "unknown option: $1" ;;
        *)              break ;;
    esac
done

command -v "$CLAUDE" >/dev/null 2>&1 || die "claude not found in PATH"
command -v jq        >/dev/null 2>&1 || die "jq not found in PATH"

[ -d "$dir" ] || die "not a directory: $dir"
dir=$(cd "$dir" && pwd)

key=$(printf '%s' "$dir" | shasum | cut -c1-12)
state=$STATE_ROOT/$key
mkdir -p "$state"
raw=$state/$lane.stream
err=$state/$lane.err
idf=$state/$lane.id
pidf=$state/$lane.pid

lane_pid() { [ -f "$pidf" ] && cat "$pidf" || printf ''; }
alive()    { p=$(lane_pid); [ -n "$p" ] && kill -0 "$p" 2>/dev/null; }

# Text the worker has emitted so far, rebuilt from its assistant messages. This
# is the only way to recover work from a run that was killed or errored midway.
partial() {
    jq -j 'select(.type=="assistant").message.content[]?
           | select(.type=="text") | .text + "\n"' "$raw" 2>/dev/null || true
}

render() {
    [ -f "$raw" ] || die "no run recorded for lane '$lane' in $dir" 3
    if alive; then printf 'status: RUNNING (pid %s)\n' "$(lane_pid)"
    else           printf 'status: finished\n'; fi
    [ -f "$idf" ] && printf 'session: %s\n' "$(cat "$idf")"
    printf 'workspace: %s\nsteps:\n' "$dir"
    jq -r 'select(.type=="assistant").message.content[]?
           | select(.type=="tool_use")
           | "  \(.name)\(if .input.command then ": " + (.input.command|tostring) elif .input.file_path then ": " + (.input.file_path|tostring) else "" end)"' \
       "$raw" 2>/dev/null | cut -c1-120 | tail -40
    p=$(partial)
    if [ -n "$p" ]; then
        printf 'output so far:\n'
        printf '%s\n' "$p" | sed 's/^/  /' | tail -30
    fi
    printf 'raw stream: %s\n' "$raw"
}

case $action in
peek) render; exit 0 ;;
kill)
    alive || die "no running worker in lane '$lane'" 1
    p=$(lane_pid); kill "$p" 2>/dev/null || true
    printf 'claude-worker: killed lane %s (pid %s); partial edits remain in %s\n' "$lane" "$p" "$dir" >&2
    exit 0 ;;
selftest)
    t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
    printf 'def add(a, b):\n    return a - b\n' > "$t/calc.py"
    before=$(shasum "$t/calc.py" | cut -d' ' -f1)
    printf 'MARKER-ZXQ97\n' > "$t/probe.txt"
    printf 'selftest: quirk 1+3 (workspace is cwd, stream-json usable)... '
    probe=$(CW_EFFORT=low "$0" -r -d "$t" -n selftest \
        "Read the file probe.txt in your workspace and reply with its exact contents. If you cannot find it, reply NOTFOUND." || true)
    case $probe in
        *MARKER-ZXQ97*) printf 'PASS\n' ;;
        *) printf 'FAIL (worker could not read probe.txt: %s)\n' "$(printf '%s' "$probe" | head -n1)"; exit 1 ;;
    esac
    printf 'selftest: quirk 2 (plan mode blocks writes, reads still work)... '
    out=$(CW_EFFORT=low "$0" -r -d "$t" -n selftest "Fix the bug in calc.py: add() subtracts. Edit the file." || true)
    after=$(shasum "$t/calc.py" | cut -d' ' -f1)
    [ "$before" = "$after" ] || { printf 'FAIL (plan mode wrote to calc.py — skip-permissions leaked in?)\n'; exit 1; }
    [ -n "$out" ] && printf 'PASS\n' || { printf 'FAIL (quirk 6: empty response)\n'; exit 1; }
    printf 'selftest: quirk 6 (write mode edits, exit 0, non-empty report)... '
    CW_EFFORT=low "$0" -d "$t" -n selftest "Fix the bug in calc.py: add() subtracts instead of adding. Edit the file." >/dev/null
    grep -q 'a + b' "$t/calc.py" && printf 'PASS\n' || { printf 'FAIL (write mode did not fix calc.py)\n'; exit 1; }
    printf 'selftest: quirk 4 (resume targets this lane, keeps its session)... '
    # state is keyed by workspace, and the selftest workspace is $t, not $dir
    tstate=$STATE_ROOT/$(printf '%s' "$(cd "$t" && pwd)" | shasum | cut -c1-12)
    sid=$(cat "$tstate/selftest.id" 2>/dev/null || printf '')
    CW_EFFORT=low "$0" -c -d "$t" -n selftest "Reply with exactly: RESUMED-OK" | grep -q 'RESUMED-OK' \
        || { printf 'FAIL (resume did not reach the same worker)\n'; exit 1; }
    [ -n "$sid" ] && [ "$sid" = "$(cat "$tstate/selftest.id" 2>/dev/null || printf '')" ] \
        && printf 'PASS\n' || { printf 'FAIL (session id changed on resume — --fork-session leaked in?)\n'; exit 1; }
    printf 'selftest: all checks passed against %s\n' "$("$CLAUDE" --version 2>/dev/null || echo claude)"
    exit 0 ;;
esac

# --- task text: arguments, else stdin (heredoc worker packets) ---------------
if [ $# -gt 0 ]; then task=$*
elif [ ! -t 0 ];  then task=$(cat)
else die "no task given (pass as arguments or on stdin)"; fi
[ -n "${task#"${task%%[![:space:]]*}"}" ] || die "task is empty"

# quirk 3: stream-json is unusable without --verbose
set -- -p "$task" --output-format stream-json --verbose

if [ "$action" = continue ]; then
    [ -f "$idf" ] || die "no previous worker in lane '$lane' for $dir" 1
    alive && die "lane '$lane' is still running (use -p to peek, -k to kill)" 1
    # quirk 4: resume by explicit id, never -c. Model/effort are inherited.
    sid=$(cat "$idf")
    set -- "$@" --resume "$sid"
else
    command -v uuidgen >/dev/null 2>&1 || die "uuidgen not found in PATH"
    sid=$(uuidgen | tr 'A-Z' 'a-z')
    set -- "$@" --session-id "$sid" --model "$MODEL" --effort "$EFFORT"
fi

# quirk 2: plan mode ALONE is what blocks writes; the skip flag would undo it
if [ "$plan" = 1 ]; then
    set -- "$@" --permission-mode plan
else
    set -- "$@" --dangerously-skip-permissions
fi

[ -n "$BUDGET" ] && set -- "$@" --max-budget-usd "$BUDGET"

: > "$raw"; : > "$err"
# quirk 1: the workspace is the cwd, so cd rather than pass a flag
( cd "$dir" && exec "$CLAUDE" "$@" ) > "$raw" 2>"$err" &
cpid=$!
printf '%s\n' "$cpid" > "$pidf"

# The session id is known before any work happens (we chose it, or we are
# resuming one), so a long run is peekable and resumable immediately.
printf '%s\n' "$sid" > "$idf"
printf 'claude-worker[%s]: session %s · peek: claude-worker -p -n %s -d %s\n' "$lane" "$sid" "$lane" "$dir" >&2

rc=0; wait "$cpid" || rc=$?
rm -f "$pidf"

result=$(jq -c 'select(.type=="result")' "$raw" 2>/dev/null | tail -n1)
if [ -z "$result" ]; then
    partial                                    # salvage whatever was produced
    [ -s "$err" ] && cut -c1-500 "$err" >&2
    die "no result event (crash, or claude exited $rc) — see $raw" 3
fi

subtype=$(printf '%s' "$result" | jq -r '.subtype // "unknown"')
is_error=$(printf '%s' "$result" | jq -r '.is_error // false')
body=$(printf '%s' "$result" | jq -r '.result // ""')
# A killed or errored run reports an empty result even though the worker may
# have done real work; fall back to its assistant messages rather than lose it.
[ -n "$body" ] || body=$(partial)
printf '%s\n' "$body"

if [ "$is_error" = true ] || [ "$subtype" != success ] || [ "$rc" -ne 0 ]; then
    printf 'claude-worker: %s (exit %s) — partial output above, if any; peek: claude-worker -p -n %s -d %s\n' \
        "$subtype" "$rc" "$lane" "$dir" >&2
    exit 1
fi
# quirk 6: success with an empty body is a failure, not a pass.
[ -n "$(printf '%s' "$body" | tr -d '[:space:]')" ] \
    || die "subtype success but empty response (see $raw)" 2
exit 0
