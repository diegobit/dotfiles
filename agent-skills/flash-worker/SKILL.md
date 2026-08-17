---
name: flash-worker
description: Delegate bounded implementation, refactors, test-writing, codebase audits, or parallel multi-file work to an autonomous Gemini 3.7 Flash subagent via the Antigravity CLI (`agy`). Runs either in write mode, returning an ownership-scoped diff to review, or in enforced read-only mode for investigations and second opinions — both keep verbose execution and build logs out of the main context.
---

# Flash Worker Subagent

Delegate implementation or investigation tasks to **Gemini 3.7 Flash** (High reasoning) through
`scripts/flash.sh`, a wrapper around the Antigravity CLI (`agy`).

Always use the wrapper. `agy` has six quirks that fail *silently* — wrong workspace, wrong resume
target, truncated timeouts, empty-but-"successful" runs — and the wrapper makes each one impossible
to express. They are documented in the script's header comment if you need to debug or re-verify them.

---

## Why & When to Use

- **Save Context Tokens:** Offload verbose multi-file edits, build logs, and repetitive coding to keep your primary context clean.
- **Bounded Execution:** Fast implementation of settled designs, functions, migrations, or tests.
- **Read-Only Investigations:** Codebase audits, debugging, or second opinions with writes blocked by the harness.
- **Parallel Work:** Independent workers in named lanes, each separately peekable, resumable, and killable.

---

## Interface

```
flash [-r] [-d DIR] [-n LANE] "task text"     spawn a worker (task may also come from stdin)
flash -c [-n LANE] "correction"               resume this lane's last worker
flash -p [-n LANE]                            peek at live progress and partial output
flash -k [-n LANE]                            kill a running worker
flash --selftest                              verify the wrapper against the installed agy
```

`-r` read-only · `-d` workspace (default `$PWD`) · `-n` lane name (default `default`).

stdout is the worker's report and nothing else, so it is safe to pipe or capture.
Model (`gemini-3.7-flash`), effort (`high`) and timeout (`10h`) are fixed in the script — the long
timeout is deliberate, so *you* decide when a worker has run too long and kill it.

**Exit codes:** `0` ok · `1` agy error (including `-k`) · `2` empty response · `3` crash · `64` usage.
This is your first acceptance gate — `flash … || handle`. On any failure the wrapper still prints
whatever the worker produced, rebuilt from the stream, so partial work is never lost.

---

## Usage

This skill is shared by several harnesses, so do not assume a harness-specific skills root.
Use `scripts/flash.sh` relative to this skill's base directory, or the path all of them resolve to:

```bash
FLASH=~/dotfiles/agent-skills/flash-worker/scripts/flash.sh
```

Since `-d` defaults to `$PWD`, `cd` to the workspace first (or pass `-d`).

### Implementation task

```bash
cd "$REPO" && "$FLASH" -n api <<'EOF'
ROLE
Implement the specified task. Do not change architecture, APIs, or out-of-scope files.

OBJECTIVE
<goal and concrete acceptance criteria>

OWNERSHIP
Allowed to change:
- <absolute paths>
Must NOT touch:
- <protected/out-of-scope paths>
Preserve all unrelated changes.

INTERFACES & CONSTRAINTS
- <APIs, contracts, schemas to preserve>

VERIFICATION
- Command: <pytest | npm test | cargo check>
  Expected: <expected outcome>

RETURN
STATUS: complete | partial | blocked
CHANGES: <summary of edits>
VERIFIED: <test output>
GAPS / BLOCKERS: <issues or none>
EOF
```

Heredocs are the natural way to pass a packet — no shell-quoting of multi-line text.

### Read-only investigation

```bash
cd "$REPO" && "$FLASH" -r -n audit "Audit src/auth.ts for concurrency bugs. Report findings only."
```

`-r` blocks writes at the harness level, so `Allowed to change: NONE` is enforced rather than merely
requested. Verified: the worker still reads and runs commands, but the workspace stays untouched.

### Long or parallel runs

Background each lane, then poll:

```bash
cd "$REPO" && "$FLASH" -n api  "…" > /tmp/api.out  2>/tmp/api.err  &
cd "$REPO" && "$FLASH" -n web  "…" > /tmp/web.out  2>/tmp/web.err  &

"$FLASH" -p -n api        # RUNNING/finished, step feed, output so far
"$FLASH" -k -n api        # give up on a worker; partial edits stay on disk
```

### Iterating

```bash
"$FLASH" -c -n api "Test test_login failed: <error>. Fix and re-run verification."
```

Resume targets that lane's conversation by id, so it stays correct with many workers in flight.
Model and effort are inherited from the original run.

---

## Parallelism Guardrails

- **One worker per lane.** Resuming a busy lane is refused; use distinct `-n` names for concurrent work.
- **File Disjointness:** Concurrent workers MUST have strictly non-overlapping `Allowed to change` lists.
- **Worktree Isolation:** For overlapping or multi-branch work, give each worker its own `git worktree`
  and point that lane's `-d` at it. `-d` is the *only* thing that scopes a worker.

---

## Review & Acceptance Gate

1. **Exit code** — non-zero means don't trust the output. Covers transport errors and empty responses.
2. **Worker self-report** — the `STATUS:` / `VERIFIED:` lines. The exit code says the CLI ran; only
   these say the task succeeded.
3. **Inspect diff** — `git diff` to confirm changes stayed strictly within `OWNERSHIP`.
4. **Iterate** — `flash -c -n <lane>` to correct in place rather than restarting.

---

## If Something Looks Wrong

Run `flash --selftest`. It spins up a throwaway workspace and checks, against the live `agy`, that the
worker can reach the workspace, that read-only mode really blocks writes, and that write mode really
edits files. If it fails, the script's header comment explains each quirk, how to re-verify it by hand,
and which line to patch — keep this file and that script in sync in the same commit.
