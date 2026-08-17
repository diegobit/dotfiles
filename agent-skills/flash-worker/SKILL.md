---
name: flash-worker
description: Delegate bounded implementation, refactors, test-writing, codebase audits, or parallel multi-file work to an autonomous Gemini 3.7 Flash subagent via the Antigravity CLI (`agy`). Runs either in write mode, returning an ownership-scoped diff to review, or in enforced read-only mode for investigations and second opinions — both keep verbose execution and build logs out of the main context.
---

# Flash Worker Subagent (`agy`)

Delegate implementation or investigation tasks to **Gemini 3.7 Flash** (High reasoning) via the **Antigravity CLI (`agy`)**.

---

## Why & When to Use

- **Save Context Tokens:** Offload verbose multi-file edits, build logs, and repetitive coding to keep your primary context clean.
- **Bounded Execution:** Fast implementation of settled designs, functions, migrations, or tests.
- **Read-Only Investigations:** Fast codebase audits or debugging without modifying files.
- **Parallel Work:** Run multiple independent subagent tasks concurrently in background jobs.

---

## Two Rules That Break Everything If Ignored

1. **`agy` does NOT inherit the shell's working directory.** It runs in `~/.gemini/antigravity-cli`.
   `cd`-ing into a repo or worktree has no effect. **Always pass `--add-dir <abs-path>`**, and use
   absolute paths in the worker packet. Without it the worker burns minutes searching, then
   operates on Antigravity's own internals.
2. **Always use `--output-format json` and capture `conversation_id`.** Text mode discards it, and
   without that id you cannot reliably resume a specific worker (see Iterating below).

---

## Commands

### 1. Spawn Initial Task

```bash
OUT=$(agy -p "$WORKER_PACKET" \
    --model gemini-3.7-flash \
    --effort high \
    --add-dir "$REPO_ROOT" \
    --dangerously-skip-permissions \
    --output-format json \
    --print-timeout 15m)

CONV=$(jq -r .conversation_id <<<"$OUT")   # resume handle — keep it
jq -r .status   <<<"$OUT"                  # SUCCESS | ERROR
jq -r .response <<<"$OUT"                  # the worker's full report
```

`agy` prints a single line of clean JSON to stdout (stderr stays empty on success), so `jq <<<"$OUT"`
is safe. Do **not** `echo "$OUT"` — echo expands the `\n` escapes inside `response` and splits the
object across lines, breaking every parser downstream. Use `<<<`, `printf '%s'`, or redirect to a file.

`--model gemini-3.7-flash` **requires** `--effort` (`low|medium|high`) or the run fails immediately.
The canonical ids from `agy models` are `gemini-3.7-flash-high` / `-medium` / `-low`; the
alias + `--effort` form above is equivalent.

### 2. Read-Only Investigation

Do not rely on the packet saying "read-only" — enforce it with `--mode plan`, which blocks writes
at the harness level while still allowing reads.

```bash
agy -p "$WORKER_PACKET" \
    --model gemini-3.7-flash \
    --effort high \
    --add-dir "$REPO_ROOT" \
    --mode plan \
    --dangerously-skip-permissions \
    --output-format json \
    --print-timeout 15m
```

Keep `--dangerously-skip-permissions` even here. The two flags do different jobs: plan mode stops
writes, skip-permissions stops the run from auto-denying its own **read** tools. Dropping it yields
`status: SUCCESS` with an empty `response` and no work done.

### 3. Send Iterative Corrections (Same Session)

Resume by **id**, not with `-c`. `-c` means "continue the most recent conversation" globally, so
with parallel workers it silently targets whichever finished last.

```bash
agy --conversation "$CONV" \
    -p "Test <name> failed with error: <details>. Fix the issue and re-run verification." \
    --add-dir "$REPO_ROOT" \
    --dangerously-skip-permissions \
    --output-format json \
    --print-timeout 15m
```

Model and effort are inherited from the original session — do not re-pass `--model`.
Do re-pass `--print-timeout`: it defaults back to `5m`, and fix-then-re-run-tests iterations are
usually slower than the initial spawn.

---

## Worker Packet Template

Provide explicit **absolute** file boundaries and acceptance checks:

```text
ROLE
Implement or investigate the specified task. Do not change architecture, APIs, or out-of-scope files.

OBJECTIVE
<Goal and concrete acceptance criteria>

OWNERSHIP
Allowed to change:
- <absolute file/dir paths, or "NONE (read-only investigation)">

Must NOT touch:
- <protected/out-of-scope files>
Preserve all unrelated changes.

INTERFACES & CONSTRAINTS
- <APIs, contracts, schemas, or standards to preserve>

VERIFICATION
- Command: <e.g., pytest, npm test, cargo check>
  Expected: <expected outcome>

RETURN
STATUS: complete | partial | blocked
CHANGES (or FINDINGS): <summary of edits or investigation evidence>
VERIFIED: <test output or verification evidence>
GAPS / BLOCKERS: <any issues or none>
```

---

## Parallelism Guardrails

- **File Disjointness:** Concurrent subagents MUST have strictly non-overlapping `Allowed to change` file lists.
- **Worktree Isolation:** For overlapping or multi-branch work, give each subagent its own
  `git worktree` and point that worker's `--add-dir` at it. The worktree path is the *only* thing
  that scopes the worker — there is no cwd to inherit.
- **Track ids:** Store each worker's `conversation_id` alongside its lane so corrections reach the
  right session.

---

## Review & Acceptance Gate

Check all four before accepting work:

1. **Transport:** `status == SUCCESS` **and** `response` is non-empty. `SUCCESS` with an empty
   response means the run was auto-denied or produced nothing — it is not a pass.
2. **Worker self-report:** the `STATUS:` / `VERIFIED:` lines in the packet's RETURN block. The
   harness `status` says the CLI ran; only these say the task actually succeeded.
3. **Inspect Diff:** `git diff` to confirm changes stayed strictly within `OWNERSHIP`.
4. **Iterate:** If issues exist, resume with `--conversation "$CONV"` to correct in-place rather
   than restarting from scratch.
