---
name: flash-worker
description: Delegate implementation, refactors, tests, codebase audits, or parallel multi-file work to autonomous Gemini 3.8 Flash workers, keeping verbose execution out of the main context. Write mode returns an ownership-scoped diff to review; read-only mode is enforced for investigations and second opinions.
---

# Flash Worker Subagent

Delegate implementation or investigation tasks to **Gemini 3.8 Flash** (High reasoning) by running
`scripts/flash.sh`.

---

## Why & When to Use

- **Save Context Tokens:** Offload verbose multi-file edits, build logs, and repetitive coding to keep your primary context clean.
- **Bounded Execution:** Fast implementation of settled designs, functions, migrations, or tests.
- **Read-Only Investigations:** Codebase audits, debugging, or second opinions with writes blocked by the harness.
- **Parallel Work:** Independent workers in named lanes, each separately peekable, resumable, and killable.

---

## Interface

```
flash [-r] [-d DIR] [-n LANE] [--spill N] "task"   spawn a worker (packet normally arrives via stdin — see Usage)
flash -c [-n LANE] "correction"                    resume this lane's last worker
flash -p [-n LANE]                                 peek at live progress and partial output
flash -k [-n LANE]                                 kill a running worker
flash --selftest                                   check the tooling is working end to end
```

`-r` read-only · `-d` workspace (default `$PWD`) · `-n` lane name (default `default`).
`--spill N` prints up to N report lines, followed by a full-report path notice when truncated.
N must be a nonnegative decimal integer supported by the shell; `0` means unlimited.
`FLASH_SPILL_LINES` sets the default (otherwise `0`); `--spill` overrides it.

stdout contains the report and, when capped, its file notice. It is safe to pipe or capture.
Model and reasoning effort are fixed. Workers have no practical deadline, by design — *you* decide
when one has run too long and kill it.

**Exit codes:** `0` ok · `1` worker error (including `-k`) · `2` empty response · `3` crash · `64` usage.
This is your first acceptance gate — `flash … || handle`. On worker errors and crashes, the
wrapper saves available partial output rebuilt from the stream and applies the same stdout cap.

---

## Usage

This skill is shared by several harnesses, so do not assume a harness-specific skills root.
Use `scripts/flash.sh` relative to this skill's base directory, or the path all of them resolve to:

```bash
FLASH=~/dotfiles/agent-skills/flash-worker/scripts/flash.sh
```

`-d` defaults to `$PWD`, but pass it explicitly for anything beyond a one-shot call. A worker is
identified by `(workspace, lane)`, so `-p`, `-c` and `-k` only find it when given the same `-d` it
was spawned with — a mismatched working directory reports the worker as missing, not as running.

### The packet

Provide a packet to every invocation. Implementation and
read-only investigation use the same shape; only `OWNERSHIP` differs.

```bash
"$FLASH" -d "$REPO" -n api <<'EOF'
ROLE
<implement | investigate>. Do not exceed the scope below.

OBJECTIVE
<goal and concrete acceptance criteria>

OWNERSHIP
Allowed to change: <absolute paths>        # read-only runs: NONE (enforced by -r)
Must NOT touch: <protected/out-of-scope paths>
Preserve all unrelated changes.

METHOD & CONSTRAINTS
- Enumerate directly with commands; never estimate, infer, or recall.
- For voluminous command output (> ~20 lines, test suites, deep listings, diffs),
  run `mkdir -p /tmp/flash`, then `mktemp -d /tmp/flash/evidence.XXXXXX` once per
  invocation. Save each command's stdout and stderr to a distinct topic.log in
  that directory and capture its exit code. If the harness blocks log creation,
  return essential excerpts and record the missing full log in GAPS.
- <APIs, contracts, schemas to preserve, or search scope>

VERIFICATION
- Command: <pytest | npm test | ls -1 X | wc -l>
  Expected: <expected outcome>

RETURN
STATUS: complete | partial | blocked
EVIDENCE: for every number or claim, the exact command and its output:
  - Short output (< ~20 lines): paste verbatim before the conclusion it supports.
  - Voluminous output: cite the command, exit code, log file path
    ("Full output: <absolute log path>"),
    and paste only the essential verbatim lines supporting the claim.
  No command/output (or cited log file), no claim.
FINDINGS / CHANGES: <only what EVIDENCE above supports>
GAPS / BLOCKERS: <issues or none>

Report nothing outside these headings. Any figure you could not produce a command
for belongs in GAPS, not FINDINGS.
EOF
```

Heredocs are the natural way to pass a packet — no shell-quoting of multi-line text.

For read-only work add `-r`, which blocks writes at the harness level so `OWNERSHIP: NONE` is
enforced rather than merely requested. Verified: the worker still reads and runs commands, but
the workspace stays untouched.

### Long or parallel runs

Background each lane, then poll:

```bash
mkdir -p /tmp/flash
"$FLASH" -d "$REPO" -n api "…" > /tmp/flash/api.out 2>/tmp/flash/api.err &
"$FLASH" -d "$REPO" -n web "…" > /tmp/flash/web.out 2>/tmp/flash/web.err &

"$FLASH" -p -d "$REPO" -n api    # RUNNING/finished, step feed, output so far
"$FLASH" -k -d "$REPO" -n api    # give up on a worker; partial edits stay on disk
```

The wrapper saves the full latest report, including partial reports from worker errors and
crashes, to `${XDG_CACHE_HOME:-$HOME/.cache}/flash/<workspace-hash>/<lane>.out`.
Find the exact path with `flash -p` or the notice from a capped run. This file is replaced when
the lane's next invocation finishes; copy it elsewhere first if you need to retain it.

The `/tmp/flash/` redirects above belong to the caller; the wrapper never copies reports there.
Keep captures separate from the wrapper's cache files. Lane names are unique only *within*
a workspace: for concurrent projects, qualify capture filenames (`/tmp/flash/<project>-api.out`)
or create a unique capture directory with `mktemp -d /tmp/flash/capture.XXXXXX`.

### Iterating

```bash
"$FLASH" -c -d "$REPO" -n api "Test test_login failed: <error>. Fix and re-run verification."
```

Resume targets that lane's own worker, so it stays correct with many in flight.

---

## Parallelism Guardrails

- **One worker per lane.** Resuming a busy lane is refused; use distinct `-n` names for concurrent work.
- **File Disjointness:** Concurrent workers MUST have strictly non-overlapping `Allowed to change` lists.
- **Worktree Isolation:** For overlapping or multi-branch work, give each worker its own `git worktree`
  and point that lane's `-d` at it. `-d` is the *only* thing that scopes a worker.

---

## Review & Acceptance Gate

1. **Exit code** — non-zero means don't trust the output. Covers transport errors and empty responses.
2. **Check EVIDENCE, not the summary** — verify figures against command output. A log citation
   points to evidence; it does not verify the claim. Inspect relevant excerpts with `rg -n`
   or `sed -n 'START,ENDp'` and reconcile breakdowns with their totals. If the log is missing,
   an excerpt is insufficient, or totals disagree, re-run with `-c` for the needed evidence.
   When stdout is capped, inspect the saved report's remaining findings and gaps before acceptance.
3. **Worker self-report** — the `STATUS:` / `FINDINGS` / `CHANGES` lines. The exit code says the
   CLI ran; only these say the task succeeded.
4. **Inspect diff** — `git diff` to confirm changes stayed strictly within `OWNERSHIP`. Skipped
   under `-r`, where the workspace should show no diff at all.
5. **Iterate** — `flash -c -n <lane>` to correct in place rather than restarting.

---

## If Something Looks Wrong

For report persistence, capping, and exit-code regressions, run
`python3 scripts/test_flash.py`. It uses a fake CLI and temporary workspaces.

Run `flash --selftest`. It spins up a throwaway workspace and checks that a worker can reach the
workspace, that read-only mode really blocks writes, and that write mode really edits files.
If it fails, read the script's header comment: it documents the underlying behaviour, how to
re-verify each part by hand, and which line to patch. Keep the script and this file in sync.
