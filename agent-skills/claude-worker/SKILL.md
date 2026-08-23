---
name: claude-worker
description: Delegate harder implementation, refactors, debugging, or codebase investigations to autonomous Claude Opus 5 workers via the Claude Code CLI, keeping verbose execution out of the main context. Suitable for work that needs judgement calls, not just mechanical edits. Write mode returns an ownership-scoped diff to review; read-only mode is enforced for investigations and second opinions.
---

# Claude Worker Subagent

Delegate a task to **Claude Opus 5** (high effort) by running `scripts/claude-worker.sh`.

---

## Why & When to Use

- **Harder tasks.** Unlike [flash-worker](../flash-worker/SKILL.md), this worker can be trusted with
  the small judgement calls inside a task: picking between two reasonable implementations, deciding
  where a new abstraction belongs, working out why a test actually fails. Give it the goal and the
  constraints rather than a step list.
- **Save context tokens.** Multi-file edits, build logs, and long debugging loops stay in the
  worker's context, not yours.
- **Read-only investigations.** Audits, root-cause hunts, and second opinions with writes blocked
  by the harness.
- **Parallel work.** Independent workers in named lanes, each separately peekable, resumable, killable.

### What stays with you

Delegating is not free — every worker is a cold start that re-reads the code you already have loaded,
and Opus workers are the expensive kind. Keep for yourself:

- **The decision of what the task even is** — scope, acceptance criteria, which files are in play.
  A worker that has to guess the objective will confidently deliver the wrong one.
- **Anything cheaper to do than to specify.** A two-line edit you can already see is not worth a packet.
- **Choices the user cares about** — architecture, dependencies, anything user-visible or hard to
  reverse. Decide those (or ask), then hand the worker the settled decision.
- **Acceptance.** The worker's report is a claim; the diff and the verification output are the evidence.

Use flash-worker instead when the task is mechanical, wide, and fully specified — bulk renames,
scripted migrations, counting things across a repo. Use this skill when getting it right needs
some thought.

---

## Interface

```
claude-worker [-r] [-d DIR] [-n LANE] "task"     spawn a worker (packet normally arrives via stdin — see Usage)
claude-worker -c [-n LANE] "correction"          resume this lane's last worker
claude-worker -p [-n LANE]                       peek at live progress and partial output
claude-worker -k [-n LANE]                       kill a running worker
claude-worker --selftest                         check the tooling is working end to end
```

`-r` read-only · `-d` workspace (default `$PWD`) · `-n` lane name (default `default`).

stdout is the worker's report and nothing else, so it is safe to pipe or capture.
Model and effort are fixed (`CW_MODEL`, `CW_EFFORT` override; `CW_BUDGET=5` caps spend in USD).
Workers have no deadline, by design — *you* decide when one has run too long and kill it.

**Exit codes:** `0` ok · `1` worker error (including `-k`) · `2` empty response · `3` crash · `64` usage.
This is your first acceptance gate — `claude-worker … || handle`. On any failure the wrapper still
prints whatever the worker produced, rebuilt from the stream, so partial work is never lost.

---

## Usage

This skill is shared by several harnesses, so do not assume a harness-specific skills root.
Use `scripts/claude-worker.sh` relative to this skill's base directory, or the path all of them
resolve to:

```bash
CW=~/dotfiles/agent-skills/claude-worker/scripts/claude-worker.sh
```

`-d` defaults to `$PWD`, but pass it explicitly for anything beyond a one-shot call. A worker is
identified by `(workspace, lane)`, so `-p`, `-c` and `-k` only find it when given the same `-d` it
was spawned with — a mismatched working directory reports the worker as missing, not as running.

### The packet

Provide a packet to every invocation. Implementation and read-only investigation use the same
shape; only `OWNERSHIP` differs.

```bash
"$CW" -d "$REPO" -n api <<'EOF'
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
- <APIs, contracts, schemas to preserve, or search scope>
- Decide anything the constraints leave open, and say what you decided and why.
  Stop and report instead if the choice changes the public API, adds a dependency,
  or is user-visible.

VERIFICATION
- Command: <pytest | npm test | ls -1 X | wc -l>
  Expected: <expected outcome>

RETURN
STATUS: complete | partial | blocked
EVIDENCE: for every number or claim, the exact command and its verbatim output,
  pasted before the conclusion it supports. No output, no claim.
FINDINGS / CHANGES: <only what EVIDENCE above supports>
DECISIONS: <judgement calls you made, and the alternative you rejected>
GAPS / BLOCKERS: <issues or none>

Report nothing outside these headings. Any figure you could not produce a command
for belongs in GAPS, not FINDINGS.
EOF
```

Heredocs are the natural way to pass a packet — no shell-quoting of multi-line text.

Because this worker is allowed to decide, `METHOD & CONSTRAINTS` should draw the line between what
it settles on its own and what it must escalate, and `DECISIONS` is where it reports back across
that line. Without both, it will either ask about everything or quietly redesign things.

For read-only work add `-r`, which blocks writes at the harness level so `OWNERSHIP: NONE` is
enforced rather than merely requested. Verified: the worker still reads and runs commands, but the
workspace stays untouched.

### Long or parallel runs

Background each lane, then poll:

```bash
mkdir -p /tmp/claude-worker
"$CW" -d "$REPO" -n api "…" > /tmp/claude-worker/api.out 2>/tmp/claude-worker/api.err &
"$CW" -d "$REPO" -n web "…" > /tmp/claude-worker/web.out 2>/tmp/claude-worker/web.err &

"$CW" -p -d "$REPO" -n api    # RUNNING/finished, tool feed, output so far
"$CW" -k -d "$REPO" -n api    # give up on a worker; partial edits stay on disk
```

Keep these redirect files under `/tmp/claude-worker/` so they cannot collide with unrelated temp
files. Lane names only have to be unique *within* a workspace, so if you run the same lane name
against two workspaces at once, qualify the filenames too (`/tmp/claude-worker/<project>-api.out`).

### Iterating

```bash
"$CW" -c -d "$REPO" -n api "Test test_login failed: <error>. Fix and re-run verification."
```

Resume targets that lane's own worker, so it stays correct with many in flight. A resumed worker
keeps its whole context, which is usually cheaper and better than restating the packet — prefer
`-c` over a fresh spawn for corrections.

---

## Parallelism Guardrails

- **One worker per lane.** Resuming a busy lane is refused; use distinct `-n` names for concurrent work.
- **File Disjointness:** Concurrent workers MUST have strictly non-overlapping `Allowed to change` lists.
- **Worktree Isolation:** For overlapping or multi-branch work, give each worker its own `git worktree`
  and point that lane's `-d` at it. `-d` is the *only* thing that scopes a worker.

---

## Review & Acceptance Gate

1. **Exit code** — non-zero means don't trust the output. Covers transport errors and empty responses.
2. **Check EVIDENCE, not the summary** — any figure without pasted command output is unverified;
   any breakdown that doesn't reconcile with its stated total means re-run with `-c`, don't patch
   it by hand.
3. **Read DECISIONS** — this is the part a lower-cost worker wouldn't have produced, and the part
   most likely to disagree with what you'd have chosen. Overrule it with `-c` rather than editing
   around it.
4. **Worker self-report** — the `STATUS:` / `FINDINGS` / `CHANGES` lines. The exit code says the
   CLI ran; only these say the task succeeded.
5. **Inspect diff** — `git diff` to confirm changes stayed strictly within `OWNERSHIP`. Skipped
   under `-r`, where the workspace should show no diff at all.
6. **Iterate** — `claude-worker -c -n <lane>` to correct in place rather than restarting.

---

## If Something Looks Wrong

Run `claude-worker --selftest`. It spins up a throwaway workspace and checks that a worker can reach
the workspace, that read-only mode really blocks writes, that write mode really edits files, and
that resume returns to the same session. If it fails, read the script's header comment: it documents
the underlying CLI behaviour, how to re-verify each part by hand, and which line to patch. Keep the
script and this file in sync.

The one failure mode to watch for: `--dangerously-skip-permissions` overrides `--permission-mode
plan`, so a read-only worker that starts editing files means the two flags have been combined
somewhere. That is the inverse of how flash-worker's harness behaves — do not copy flag handling
between the two scripts.
