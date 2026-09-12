---
name: delegate
description: Delegate implementation, refactors, tests, debugging, or codebase investigations to external Gemini, Claude, Cursor, Codex, or OpenCode workers while keeping verbose execution out of the main context. Gemini is the default. Supports scoped writes, read-only investigations, continuation, and file-backed evidence.
---

# Delegate

Delegate with `scripts/delegate.sh`. Choose only the executor: `gemini`
(default), `claude`, `cursor`, `codex`, or `opencode`. The launcher handles model selection, command
flags, sessions, and reports. Keep task scope, user-facing decisions, and acceptance
with the orchestrator; the packet defines which implementation choices the worker
can make.

## Interface

```bash
DELEGATE=~/dotfiles/agent-skills/delegate/scripts/delegate.sh

"$DELEGATE" -d "$REPO" "task"                    # default executor
"$DELEGATE" -e claude -r -d "$REPO" "investigate"
"$DELEGATE" -e cursor -d "$REPO" "task"
"$DELEGATE" -e codex -d "$REPO" "task"
"$DELEGATE" -e opencode -d "$REPO" "task"
"$DELEGATE" -e claude -c -d "$REPO" "correction"
"$DELEGATE" -e claude -p -d "$REPO"               # peek
"$DELEGATE" -e claude -k -d "$REPO"               # kill
```

Use the launcher relative to this skill's directory if the checkout is elsewhere.
`-e`/`--executor` defaults to `gemini` on **every** action. `-d` defaults to `$PWD`;
use the same workspace and executor for continuation, peek, and kill. Options go
before task text; a heredoc supplies a packet via stdin.

`-r` starts a read-only worker. Continuation inherits the original permission mode,
including when `-r` is omitted. Start a fresh worker to change mode.

One worker per `(workspace, executor)` can run at a time. There are no named lanes.
Different executors may run concurrently when their allowed files are disjoint.
For concurrent workers using the same executor, or overlapping changes, use separate
worktrees and pass their directories with `-d`.

## Packet

Use one packet shape for every executor; set the authority and verification needed
for the task. Add `-r` and set allowed changes to NONE for investigations.

```bash
"$DELEGATE" -d "$REPO" <<'EOF'
ROLE
<implement | investigate>

OBJECTIVE
<goal and concrete acceptance criteria>

OWNERSHIP
Allowed to change: <absolute paths, or NONE for -r>
Must NOT touch: <protected paths>
Preserve all unrelated changes.

METHOD & CONSTRAINTS
- <contracts to preserve and decisions the worker may make>
- Enumerate with commands; support measured claims with their output.
- For voluminous output, create a unique directory with:
  mkdir -p /tmp/delegate
  mktemp -d /tmp/delegate/evidence.XXXXXX
  Save each command's stdout and stderr to a distinct log there and record its
  exit code. If log creation is blocked, return essential excerpts and report
  the missing full log in GAPS.

VERIFICATION
- Command: <command>
  Expected: <outcome>

RETURN
STATUS: complete | partial | blocked
EVIDENCE: exact commands and exit codes; paste short output verbatim. For long
  output, cite the absolute full-log path and essential verbatim excerpts.
FINDINGS / CHANGES: <supported by the evidence>
DECISIONS: <judgment calls and reasons, or none>
GAPS / BLOCKERS: <missing evidence, unfinished work, or none>
EOF
```

## Reports and long runs

`--spill N` prints at most N report lines plus a full-report path notice when
truncated. `EW_SPILL_LINES` sets the default; the flag overrides it. N is a
nonnegative decimal integer supported by the shell; zero/unset means unlimited.
The same saving and capping apply to partial reports from errors and crashes.

The canonical report is
`${XDG_CACHE_HOME:-$HOME/.cache}/delegate/<workspace-hash>/<executor>/report.out`.
Peek and capped-output notices give its exact path. It is replaced when the next
invocation finishes; copy it elsewhere to retain it. Read the remainder of a capped
report before accepting its work.

For background execution, create a unique caller-owned capture directory:

```bash
mkdir -p /tmp/delegate
capture=$(mktemp -d /tmp/delegate/capture.XXXXXX)
"$DELEGATE" -d "$REPO" "task packet" >"$capture/stdout" 2>"$capture/stderr" &
worker_pid=$!
"$DELEGATE" -p -d "$REPO"
wait "$worker_pid"  # retain the exit code for acceptance
```

Keep captures separate from the launcher's cache files. Workers have no practical
deadline; peek for progress and kill explicitly when appropriate. Killing preserves
partial edits and available output; it does not roll back the workspace.

## Acceptance

1. Check exit status: `0` means the CLI returned nonempty output, `1` worker error
   or cancellation, `2` empty response, `3` crash/missing result, `64` invalid usage.
   Transport success alone does not establish task completion.
2. Verify claims against the evidence. A log citation points to evidence; inspect
   relevant ranges with `rg -n` or `sed -n 'START,ENDp'`. Reconcile totals and
   request missing evidence with `-c` when needed.
3. Read STATUS, DECISIONS, and GAPS, including portions beyond a stdout cap.
4. Inspect the workspace diff for correctness and ownership. For `-r`, verify
   that the workspace remains unchanged relative to its pre-run state.
5. Correct with `-c` using the same executor and workspace. This preserves the
   worker's context; a fresh invocation starts a new conversation.

## Troubleshooting

For failed launches, permission behavior, session problems, or provider maintenance,
read [backend details](references/backends.md) before changing flags. Each provider
has different read-only semantics.

Run `python3 scripts/test_delegate.py` from this skill's directory for offline
regressions. `scripts/delegate.sh -e <executor> --selftest` exercises the
installed CLI in a throwaway workspace and uses paid model calls.
