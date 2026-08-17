---
name: flash-worker
description: Delegate execution tasks, boilerplate, investigations, or parallel workloads to an autonomous Gemini 3.7 Flash subagent (`agy`) to save context tokens and review verified diffs.
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

## Commands

### 1. Spawn Initial Task
```bash
agy -p "$WORKER_PACKET" \
    --model gemini-3.7-flash \
    --effort high \
    --dangerously-skip-permissions \
    --output-format text \
    --print-timeout 15m
```

### 2. Send Iterative Corrections (Same Session)
If checks fail or adjustments are needed, resume the existing session without repeating full context:
```bash
agy -c -p "Test <name> failed with error: <details>. Fix the issue and re-run verification." \
    --dangerously-skip-permissions
```

---

## Worker Packet Template

Provide explicit file boundaries and acceptance checks:

```text
ROLE
Implement or investigate the specified task. Do not change architecture, APIs, or out-of-scope files.

OBJECTIVE
<Goal and concrete acceptance criteria>

OWNERSHIP
Allowed to change:
- <allowed file/dir paths, or "NONE (read-only investigation)">

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
- **Worktree Isolation:** For overlapping or multi-branch work, run each subagent in a separate `git worktree`.

---

## Review & Acceptance Gate

1. **Inspect Diff:** Check `git diff` to ensure changes strictly stayed within `OWNERSHIP`.
2. **Verify Tests:** Confirm verification checks passed before accepting changes into the main conversation.
3. **Iterate:** If issues exist, use `agy -c -p ...` to correct in-place rather than restarting from scratch.
