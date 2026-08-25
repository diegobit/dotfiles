#!/bin/sh
# cursor-worker — spawn a Cursor Grok 4.6 (High) worker via the Cursor Agent CLI.
#
# Usage:
#   cursor-worker [-r] [-d DIR] [-n LANE] "task text"   spawn a worker (task may also come from stdin)
#   cursor-worker -c [-n LANE] "correction"             resume this lane's last worker
#   cursor-worker -p [-n LANE]                          peek at live/last progress
#   cursor-worker -k [-n LANE]                          kill a running worker
#   cursor-worker --selftest                            verify this wrapper against the real agent CLI
#
#   -r  read-only (plan mode; writes blocked by the harness, not by the prompt)
#   -d  workspace directory (default: $PWD)
#   -n  lane name (default: "default") — one concurrent worker per lane
#
# stdout is the worker's report and nothing else, so it is safe to pipe.
# Exit: 0 ok · 1 the CLI reported an error (includes a killed run) · 2 empty response
#       3 no result event at all (crash) · 64 usage.
# On any failure, whatever the worker had already produced is still printed to
# stdout, reconstructed from the stream — partial work is never thrown away.
#
# ---------------------------------------------------------------------------
# IF YOU ARE AN AGENT AND THIS SCRIPT IS MISBEHAVING, READ THIS
# ---------------------------------------------------------------------------
# This wrapper hides six quirks of `agent -p`, several of which fail SILENTLY.
# Each was verified empirically against CLI 2026.08.11-e8db854 (`agent models`
# lists `cursor-grok-4.6-high` as "Cursor Grok 4.6"). If the CLI
# changes, re-verify the relevant fact, patch the one marked line, and update
# ../SKILL.md in the same commit so the two never drift.
#
# 1. --workspace scopes file tools AND shell cwd. The process cwd is inherited
#    but is not what the agent uses: started from /tmp with --workspace $t,
#    init.cwd, `pwd`, and a read of ./probe.txt all resolved to $t. We also
#    `cd` so the two cannot diverge. Do not replace --workspace with --add-dir
#    (that flag adds a *second* root) and do not drop --workspace in favour of
#    cwd alone — cwd is only the default when --workspace is omitted.
#
# 2. --force does NOT override --plan. `--plan --force` still left calc.py
#    untouched while `wc -l probe.txt` ran and probe.txt was readable. This is
#    the inverse of claude-worker, where --dangerously-skip-permissions undoes
#    --permission-mode plan. Read-only mode here must pass BOTH --plan (blocks
#    writes) and --force (print mode otherwise only proposes, and may prompt).
#    Write mode is --force with no --plan. Verified:
#      --plan --force "fix calc.py"  -> file unchanged, shell still worked
#      --force        "fix calc.py"  -> file edited to `return x + y`
#
# 3. High is a model id, not an --effort flag. The CLI has no --effort;
#    `agent models` lists cursor-grok-4.6-high as "Cursor Grok 4.6" and
#    rejects a bare cursor-grok-4.6. Passing a parameterized override is
#    unnecessary. On resume the model is inherited, so --model must NOT be
#    re-sent.
#
# 4. `agent --continue` continues the globally most recent session, so it
#    targets the wrong worker whenever lanes share a machine. Resume with
#    --resume <session_id> stored per (workspace, lane). Never reintroduce
#    --continue. The session id is on the FIRST stream line (type=system,
#    subtype=init), before any work happens. Verified: --resume kept the same
#    session_id and remembered prior turn context.
#
# 5. --trust skips the workspace-trust prompt; --sandbox disabled lets
#    verification commands (pytest, git, python) actually run. Without them a
#    non-interactive worker can hang on a prompt or jail its own checks.
#    --approve-mcps is the same idea for MCP consent.
#
# 6. subtype == "success" does NOT mean the task succeeded — only that the CLI
#    ran. An empty .result is a failure (exit 2). The worker's own STATUS: /
#    EVIDENCE: lines are the real signal; the caller must still read them.
#
# Also: the stream is line-delimited JSON with escaped \n. Never `echo` a
# captured line — echo expands those escapes. Use printf '%s' or a file.
#
# Run `cursor-worker --selftest` to check quirks 1, 2, 4 and 6 against the
# installed CLI. Selftest overrides the model to composer-2.5-fast so it stays
# cheap; the default High id is not what those checks exercise.
# ---------------------------------------------------------------------------

set -eu

AGENT=${CRW_AGENT:-agent}
MODEL=${CRW_MODEL:-cursor-grok-4.6-high}
STATE_ROOT=${XDG_CACHE_HOME:-$HOME/.cache}/cursor-worker

die() { printf 'cursor-worker: %s\n' "$1" >&2; exit "${2:-64}"; }

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

command -v "$AGENT" >/dev/null 2>&1 || die "agent not found in PATH (Cursor CLI)"
command -v jq       >/dev/null 2>&1 || die "jq not found in PATH"

[ -d "$dir" ] || die "not a directory: $dir"
dir=$(cd "$dir" && pwd)                              # quirk 1: must be absolute

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

tool_line() {
    jq -r 'select(.type=="tool_call" and .subtype=="started") | .tool_call
           | if .readToolCall then "  read: " + (.readToolCall.args.path // "")
             elif .writeToolCall then "  write: " + (.writeToolCall.args.path // "")
             elif .editToolCall then "  edit: " + (.editToolCall.args.path // "")
             elif .shellToolCall then "  shell: " + (.shellToolCall.args.command // "")
             elif .grepToolCall then "  grep: " + (.grepToolCall.args.pattern // "")
             elif .globToolCall then "  glob: " + (.globToolCall.args.globPattern // .globToolCall.args.glob_pattern // "")
             else "  " + ((keys - ["hookAdditionalContexts","startedAtMs","toolCallId"]) | join(","))
             end' "$raw" 2>/dev/null
}

render() {
    [ -f "$raw" ] || die "no run recorded for lane '$lane' in $dir" 3
    if alive; then printf 'status: RUNNING (pid %s)\n' "$(lane_pid)"
    else           printf 'status: finished\n'; fi
    [ -f "$idf" ] && printf 'session: %s\n' "$(cat "$idf")"
    printf 'workspace: %s\nsteps:\n' "$dir"
    tool_line | cut -c1-120 | tail -40
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
    printf 'cursor-worker: killed lane %s (pid %s); partial edits remain in %s\n' "$lane" "$p" "$dir" >&2
    exit 0 ;;
selftest)
    t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
    printf 'def add(a, b):\n    return a - b\n' > "$t/calc.py"
    before=$(shasum "$t/calc.py" | cut -d' ' -f1)
    printf 'MARKER-ZXQ97\n' > "$t/probe.txt"
    # High is the production default; selftest uses a cheap model so the
    # checks exercise the wrapper, not the bill.
    printf 'selftest: quirk 1 (workspace reachable via --workspace)... '
    probe=$(CRW_MODEL=composer-2.5-fast "$0" -r -d "$t" -n selftest \
        "Read the file probe.txt in your workspace and reply with its exact contents. If you cannot find it, reply NOTFOUND." || true)
    case $probe in
        *MARKER-ZXQ97*) printf 'PASS\n' ;;
        *) printf 'FAIL (worker could not read probe.txt: %s)\n' "$(printf '%s' "$probe" | head -n1)"; exit 1 ;;
    esac
    printf 'selftest: quirk 2 (plan+force blocks writes, reads/shell still work)... '
    out=$(CRW_MODEL=composer-2.5-fast "$0" -r -d "$t" -n selftest "Fix the bug in calc.py: add() subtracts. Edit the file." || true)
    after=$(shasum "$t/calc.py" | cut -d' ' -f1)
    [ "$before" = "$after" ] || { printf 'FAIL (plan mode wrote to calc.py — --plan dropped?)\n'; exit 1; }
    [ -n "$out" ] && printf 'PASS\n' || { printf 'FAIL (quirk 6: empty response)\n'; exit 1; }
    printf 'selftest: quirk 6 (write mode edits, exit 0, non-empty report)... '
    CRW_MODEL=composer-2.5-fast "$0" -d "$t" -n selftest "Fix the bug in calc.py: add() subtracts instead of adding. Edit the file." >/dev/null
    grep -q 'a + b' "$t/calc.py" && printf 'PASS\n' || { printf 'FAIL (write mode did not fix calc.py)\n'; exit 1; }
    printf 'selftest: quirk 4 (resume targets this lane, keeps its session)... '
    tstate=$STATE_ROOT/$(printf '%s' "$(cd "$t" && pwd)" | shasum | cut -c1-12)
    sid=$(cat "$tstate/selftest.id" 2>/dev/null || printf '')
    CRW_MODEL=composer-2.5-fast "$0" -c -d "$t" -n selftest "Reply with exactly: RESUMED-OK" | grep -q 'RESUMED-OK' \
        || { printf 'FAIL (resume did not reach the same worker)\n'; exit 1; }
    [ -n "$sid" ] && [ "$sid" = "$(cat "$tstate/selftest.id" 2>/dev/null || printf '')" ] \
        && printf 'PASS\n' || { printf 'FAIL (session id changed on resume — --continue leaked in?)\n'; exit 1; }
    printf 'selftest: all checks passed against %s\n' "$("$AGENT" --version 2>/dev/null || echo agent)"
    exit 0 ;;
esac

# --- task text: arguments, else stdin (heredoc worker packets) ---------------
if [ $# -gt 0 ]; then task=$*
elif [ ! -t 0 ];  then task=$(cat)
else die "no task given (pass as arguments or on stdin)"; fi
[ -n "${task#"${task%%[![:space:]]*}"}" ] || die "task is empty"

# quirk 5: unattended print-mode always needs force/trust/sandbox/mcp consent
set -- -p "$task" \
    --workspace "$dir" \
    --force \
    --trust \
    --sandbox disabled \
    --approve-mcps \
    --output-format stream-json

if [ "$action" = continue ]; then
    [ -f "$idf" ] || die "no previous worker in lane '$lane' for $dir" 1
    alive && die "lane '$lane' is still running (use -p to peek, -k to kill)" 1
    # quirk 4: resume by explicit id, never --continue. Model is inherited (quirk 3).
    sid=$(cat "$idf")
    set -- "$@" --resume "$sid"
else
    sid=
    set -- "$@" --model "$MODEL"
fi

# quirk 2: plan mode ALONGSIDE --force is what blocks writes; force does not undo it
[ "$plan" = 1 ] && set -- "$@" --plan

: > "$raw"; : > "$err"
# quirk 1: --workspace is the scope; cd so process cwd matches
( cd "$dir" && exec "$AGENT" "$@" ) > "$raw" 2>"$err" &
apid=$!
printf '%s\n' "$apid" > "$pidf"

# The init event carries the session id on the FIRST line, before any work
# happens — surface it immediately so a long run stays peekable and resumable.
n=0
while [ "$n" -lt 200 ]; do
    id=$(head -n1 "$raw" 2>/dev/null | jq -r '.session_id // empty' 2>/dev/null || true)
    [ -n "${id:-}" ] && break
    kill -0 "$apid" 2>/dev/null || break
    sleep 0.1; n=$((n + 1))
done
if [ -n "${id:-}" ]; then
    sid=$id
    printf '%s\n' "$sid" > "$idf"
    printf 'cursor-worker[%s]: session %s · peek: cursor-worker -p -n %s -d %s\n' "$lane" "$sid" "$lane" "$dir" >&2
elif [ -n "$sid" ]; then
    printf '%s\n' "$sid" > "$idf"
    printf 'cursor-worker[%s]: session %s · peek: cursor-worker -p -n %s -d %s\n' "$lane" "$sid" "$lane" "$dir" >&2
fi

rc=0; wait "$apid" || rc=$?
rm -f "$pidf"

result=$(jq -c 'select(.type=="result")' "$raw" 2>/dev/null | tail -n1)
if [ -z "$result" ]; then
    partial                                    # salvage whatever was produced
    [ -s "$err" ] && cut -c1-500 "$err" >&2
    die "no result event (crash, or agent exited $rc) — see $raw" 3
fi

subtype=$(printf '%s' "$result" | jq -r '.subtype // "unknown"')
is_error=$(printf '%s' "$result" | jq -r '.is_error // false')
body=$(printf '%s' "$result" | jq -r '.result // ""')
# A killed or errored run reports an empty result even though the worker may
# have done real work; fall back to its assistant messages rather than lose it.
[ -n "$body" ] || body=$(partial)
printf '%s\n' "$body"

if [ "$is_error" = true ] || [ "$subtype" != success ] || [ "$rc" -ne 0 ]; then
    printf 'cursor-worker: %s (exit %s) — partial output above, if any; peek: cursor-worker -p -n %s -d %s\n' \
        "$subtype" "$rc" "$lane" "$dir" >&2
    exit 1
fi
# quirk 6: success with an empty body is a failure, not a pass.
[ -n "$(printf '%s' "$body" | tr -d '[:space:]')" ] \
    || die "subtype success but empty response (see $raw)" 2
exit 0
