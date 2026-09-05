#!/bin/sh
# flash — spawn a Gemini 3.8 Flash worker via the Antigravity CLI (agy).
#
# Usage:
#   flash [-r] [-d DIR] [-n LANE] "task text"     spawn a worker (task may also come from stdin)
#   flash -c [-n LANE] "correction"               resume this lane's last worker
#   flash -p [-n LANE]                            peek at live/last progress
#   flash -k [-n LANE]                            kill a running worker
#   flash --selftest                              verify this wrapper against the real agy
#
#   -r        read-only (plan mode; writes blocked by the harness, not by the prompt)
#   -d        workspace directory (default: $PWD)
#   -n        lane name (default: "default") — one concurrent worker per lane
#   --spill N cap stdout at N lines; full report saved to file
#
# stdout is the worker's report and nothing else, so it is safe to pipe.
# Exit: 0 ok · 1 agy reported ERROR (includes -k kill) · 2 empty response
#       3 no result event at all (crash) · 64 usage.
# On any failure, whatever the worker had already produced is still printed to
# stdout, reconstructed from the stream — partial work is never thrown away.
#
# ---------------------------------------------------------------------------
# IF YOU ARE AN AGENT AND THIS SCRIPT IS MISBEHAVING, READ THIS
# ---------------------------------------------------------------------------
# This wrapper exists to hide six quirks of `agy` that otherwise fail SILENTLY.
# Each was verified empirically. If `agy` is updated and something breaks,
# re-verify the relevant fact below, then patch the one marked line and update
# ../SKILL.md in the same commit so the two never drift.
#
# 1. The worker's FILE TOOLS ignore the shell cwd. The agy process does inherit
#    it (stream-json's init event echoes it back), but the agent's workspace
#    defaults to ~/.gemini/antigravity-cli, so relative paths resolve to
#    Antigravity's own internals. --add-dir is what registers a real workspace.
#    Do NOT verify this by asking for init.cwd — that reports the inherited
#    process cwd and looks correct even when the workspace is wrong.
#    Verify behaviourally instead (this is what --selftest does):
#      mkdir /tmp/p && printf 'MARKER\n' > /tmp/p/probe.txt && cd /tmp/p
#      agy -p "read probe.txt, else reply NOTFOUND" --model gemini-3.8-flash \
#          --effort low --dangerously-skip-permissions --output-format json
#    Without --add-dir that returns NOTFOUND; with it, MARKER.
#
# 2. `agy -c` continues the globally most recent conversation, so it targets the
#    wrong worker whenever lanes run in parallel. We always resume by explicit
#    --conversation <id>, stored per (workspace, lane). Never reintroduce -c.
#
# 3. --model <alias> REQUIRES --effort, or agy exits immediately with
#    'invalid model selection'. Canonical ids from `agy models` are
#    gemini-3.8-flash-high|-medium|-low. Effort is fixed at high below.
#
# 4. On resume, --print-timeout silently reverts to 5m. We always pass it.
#
# 5. --mode plan blocks writes, but WITHOUT --dangerously-skip-permissions the
#    run auto-denies its own read tools and returns status SUCCESS with an empty
#    response. The two flags are complementary; read-only mode needs BOTH.
#
# 6. status == SUCCESS does NOT mean the task succeeded — only that the CLI ran.
#    An empty response is a failure (exit 2). The worker's own STATUS:/EVIDENCE:
#    lines in its report are the real signal; the caller must still read them.
#
# Also: agy prints single-line JSON with escaped \n. Never `echo "$captured"` —
# echo expands those escapes and splits the object. Use printf '%s' or a file.
#
# Run `flash --selftest` to check facts 1, 3, 5 and 6 against the installed agy.
# ---------------------------------------------------------------------------

set -eu

AGY=${FLASH_AGY:-agy}
MODEL=${FLASH_MODEL:-gemini-3.8-flash}
EFFORT=${FLASH_EFFORT:-high}          # quirk 3: must always be passed
TIMEOUT=${FLASH_TIMEOUT:-10h}         # quirk 4: long by design; caller kills via -k
STATE_ROOT=${XDG_CACHE_HOME:-$HOME/.cache}/flash

die() { printf 'flash: %s\n' "$1" >&2; exit "${2:-64}"; }

lane=default
dir=$PWD
plan=0
action=run
spill_lines=${FLASH_SPILL_LINES:-}

while [ $# -gt 0 ]; do
    case $1 in
        -r|--read-only) plan=1; shift ;;
        -d|--dir)       [ $# -ge 2 ] || die "-d needs a path"; dir=$2; shift 2 ;;
        -n|--lane)      [ $# -ge 2 ] || die "-n needs a name"; lane=$2; shift 2 ;;
        --spill)        [ $# -ge 2 ] || die "--spill needs a line count"; spill_lines=$2; shift 2 ;;
        -c|--continue)  action=continue; shift ;;
        -p|--peek)      action=peek; shift ;;
        -k|--kill)      action=kill; shift ;;
        --selftest)     action=selftest; shift ;;
        -h|--help)      sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        --)             shift; break ;;
        -*)             die "unknown option: $1" ;;
        *)              break ;;
    esac
done

command -v "$AGY" >/dev/null 2>&1 || die "agy not found in PATH"
command -v jq    >/dev/null 2>&1 || die "jq not found in PATH"

[ -d "$dir" ] || die "not a directory: $dir"
dir=$(cd "$dir" && pwd)                              # quirk 1: must be absolute

key=$(printf '%s' "$dir" | shasum | cut -c1-12)
state=$STATE_ROOT/$key
mkdir -p "$state" /tmp/flash
raw=$state/$lane.stream
err=$state/$lane.err
out=$state/$lane.out
idf=$state/$lane.id
pidf=$state/$lane.pid

lane_pid() { [ -f "$pidf" ] && cat "$pidf" || printf ''; }
alive()    { p=$(lane_pid); [ -n "$p" ] && kill -0 "$p" 2>/dev/null; }

# Text the worker has emitted so far, rebuilt from streamed deltas. This is the
# only way to recover work from a run that was killed or errored mid-flight.
partial() { jq -j 'select(.event=="step_update").step_update.text_delta // ""' "$raw" 2>/dev/null || true; }

render() {
    [ -f "$raw" ] || die "no run recorded for lane '$lane' in $dir" 3
    if alive; then printf 'status: RUNNING (pid %s)\n' "$(lane_pid)"
    else           printf 'status: finished\n'; fi
    [ -f "$idf" ] && printf 'conversation: %s\n' "$(cat "$idf")"
    printf 'workspace: %s\nsteps:\n' "$dir"
    jq -r 'select(.event=="step_update").step_update
           | "  \(if .state=="ACTIVE" then "…" else "✓" end) \(.step_type)\(if .tool_name then " " + .tool_name else "" end)"' \
       "$raw" 2>/dev/null | awk '!seen[$0]++ || /…/' | tail -40
    p=$(partial)
    if [ -n "$p" ]; then
        printf 'output so far:\n'
        printf '%s\n' "$p" | sed 's/^/  /' | tail -30
    fi
    [ -f "$out" ] && printf 'last report: %s\n' "$out"
    printf 'raw stream: %s\n' "$raw"
}

case $action in
peek) render; exit 0 ;;
kill)
    alive || die "no running worker in lane '$lane'" 1
    p=$(lane_pid); kill "$p" 2>/dev/null || true
    printf 'flash: killed lane %s (pid %s); partial edits remain in %s\n' "$lane" "$p" "$dir" >&2
    exit 0 ;;
selftest)
    t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
    printf 'def add(a, b):\n    return a - b\n' > "$t/calc.py"
    before=$(shasum "$t/calc.py" | cut -d' ' -f1)
    printf 'MARKER-ZXQ97\n' > "$t/probe.txt"
    printf 'selftest: quirk 1+3 (workspace reachable via --add-dir)... '
    probe=$("$0" -r -d "$t" -n selftest \
        "Read the file probe.txt in your workspace and reply with its exact contents. If you cannot find it, reply NOTFOUND." || true)
    case $probe in
        *MARKER-ZXQ97*) printf 'PASS\n' ;;
        *) printf 'FAIL (worker could not read probe.txt: %s)\n' "$(printf '%s' "$probe" | head -n1)"; exit 1 ;;
    esac
    printf 'selftest: quirk 5 (plan mode blocks writes, reads still work)... '
    out=$("$0" -r -d "$t" -n selftest "Fix the bug in calc.py: add() subtracts. Edit the file." || true)
    after=$(shasum "$t/calc.py" | cut -d' ' -f1)
    [ "$before" = "$after" ] || { printf 'FAIL (plan mode wrote to calc.py)\n'; exit 1; }
    [ -n "$out" ] && printf 'PASS\n' || { printf 'FAIL (quirk 5/6: empty response)\n'; exit 1; }
    printf 'selftest: quirk 6 (write mode edits, exit 0, non-empty report)... '
    "$0" -d "$t" -n selftest "Fix the bug in calc.py: add() subtracts instead of adding. Edit the file." >/dev/null
    grep -q 'a + b' "$t/calc.py" && printf 'PASS\n' || { printf 'FAIL (write mode did not fix calc.py)\n'; exit 1; }
    printf 'selftest: all checks passed against %s\n' "$("$AGY" --version 2>/dev/null || echo agy)"
    exit 0 ;;
esac

# --- task text: arguments, else stdin (heredoc worker packets) ---------------
if [ $# -gt 0 ]; then task=$*
elif [ ! -t 0 ];  then task=$(cat)
else die "no task given (pass as arguments or on stdin)"; fi
[ -n "${task#"${task%%[![:space:]]*}"}" ] || die "task is empty"

set -- -p "$task" --add-dir "$dir" \
       --dangerously-skip-permissions \
       --output-format stream-json \
       --print-timeout "$TIMEOUT"

if [ "$action" = continue ]; then
    [ -f "$idf" ] || die "no previous worker in lane '$lane' for $dir" 1
    alive && die "lane '$lane' is still running (use -p to peek, -k to kill)" 1
    # quirk 2: resume by explicit id, never -c. Model/effort are inherited.
    set -- "$@" --conversation "$(cat "$idf")"
else
    set -- "$@" --model "$MODEL" --effort "$EFFORT"      # quirk 3
fi

# quirk 5: plan mode still needs skip-permissions (already set above)
[ "$plan" = 1 ] && set -- "$@" --mode plan

: > "$raw"; : > "$err"
"$AGY" "$@" > "$raw" 2>"$err" &
agypid=$!
printf '%s\n' "$agypid" > "$pidf"

# The init event carries the conversation id on the FIRST line, before any work
# happens — surface it immediately so a long run stays peekable and resumable.
n=0
while [ "$n" -lt 200 ]; do
    id=$(head -n1 "$raw" 2>/dev/null | jq -r '.conversation_id // empty' 2>/dev/null || true)
    [ -n "${id:-}" ] && break
    kill -0 "$agypid" 2>/dev/null || break
    sleep 0.1; n=$((n + 1))
done
if [ -n "${id:-}" ]; then
    printf '%s\n' "$id" > "$idf"
    printf 'flash[%s]: conversation %s · peek: flash -p -n %s -d %s\n' "$lane" "$id" "$lane" "$dir" >&2
fi

rc=0; wait "$agypid" || rc=$?
rm -f "$pidf"

result=$(jq -c 'select(.event=="result").result' "$raw" 2>/dev/null | tail -n1)
if [ -z "$result" ]; then
    partial                                    # salvage whatever was produced
    [ -s "$err" ] && cut -c1-500 "$err" >&2
    die "no result event (crash, or agy exited $rc) — see $raw" 3
fi

status=$(printf '%s' "$result" | jq -r '.status // "UNKNOWN"')
body=$(printf '%s' "$result" | jq -r '.response // ""')
# A killed or errored run reports an empty response even though the worker may
# have done real work; fall back to the streamed deltas rather than lose it.
[ -n "$body" ] || body=$(partial)
printf '%s\n' "$body" > "$out"
cp -f "$out" "/tmp/flash/$lane.out" 2>/dev/null || true

if [ -n "$spill_lines" ] && [ "$spill_lines" -gt 0 ] 2>/dev/null; then
    lines=$(printf '%s\n' "$body" | wc -l | tr -d ' ')
    if [ "$lines" -gt "$spill_lines" ]; then
        printf '%s\n' "$body" | head -n "$spill_lines"
        printf '\n[flash: output capped at %s lines (total %s). Full report saved to %s (and /tmp/flash/%s.out) — leggi qui]\n' \
            "$spill_lines" "$lines" "$out" "$lane"
    else
        printf '%s\n' "$body"
    fi
else
    printf '%s\n' "$body"
fi

if [ "$status" != SUCCESS ]; then
    printf 'flash: agy status %s — %s (partial output above, if any; peek: flash -p -n %s -d %s)\n' \
        "$status" "$(printf '%s' "$result" | jq -r '.error // "no detail"')" "$lane" "$dir" >&2
    exit 1
fi
# quirk 6: SUCCESS with an empty body is a failure, not a pass.
[ -n "$(printf '%s' "$body" | tr -d '[:space:]')" ] \
    || die "status SUCCESS but empty response (auto-denied tools? see $raw)" 2
exit 0
