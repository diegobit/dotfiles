# 02: last and resume recipe

**Outcome:** `last` prints a timestamped tail that includes the latest user instruction. The skill’s *resume* branch tells the agent to take that tail plus workspace artifacts, not a full dump and not the assistant’s closing claim. Reviewer sees `last t3 <exact-title> 8` expand past eight assistant messages to the preceding user turn.

**Blocked by:** 01 Safe lookup and exact title.

## Scope

- `agent-skills/harness-history/scripts/chat-read.sh` — new `last` command, usage, timestamps on t3 (and other providers where the store has them).
- `agent-skills/harness-history/scripts/test_chat_read.py` — cases for `last`.
- `agent-skills/harness-history/SKILL.md` — `last` usage, *resume* steps, honest `get` contents (opencode tool/file/compaction lines), drop sqlite table names and absolute store paths from the skill body. Update `description` so *resume* / continue is a named branch.
- Excluded: lookup rules already shipped in 01; wiki ingest; opencode truncation constants unless a test already depends on documenting them.

## Decisions and invariants

- Same resolver as `get` (unit 01). `last` does not invent a second title algorithm.
- `N` is messages, default 20, printed oldest-to-newest. If the slice has no user message, expand backward until one user message is included or the thread starts.
- t3 `get` and `last` include `created_at` in the printed header (the table already has it; unit 01 may still omit it from `get` until this unit lands — this unit is what adds timestamps).
- Resume recipe (positive steps): resolve the chat; run `last` (full `get` only when the thread is smaller than the default window); read the latest user instruction and constraints; note the latest assistant claim and pending actions; verify the relevant artifacts in the workspace (`git status`, and `git diff` / `git log` when the claim is a commit or patch). Chat text is context, not proof of completion.
- Do not mention `raw/` or journal-wiki.
- `get` description: user/assistant for all providers; opencode also emits tool/file/compaction (truncated). No new filter.
- Description frontmatter: three branches — list/search, get/read, resume/continue. One trigger phrase per branch. Portable YAML (`name`, `description` only).

## Implementation outline

1. Add `last` to the dispatcher; reuse 01 resolution; slice messages with the completeness rule.
2. Print timestamps where the store has them; t3 is required.
3. Extend tests: assistant-only tail expands; default `N`; `last` with exact title; `last` with unresolved title exit 1.
4. Rewrite SKILL.md: usage for `list` / `get` / `last`; *resume* steps with a completion criterion (“artifacts checked against the latest user instruction”); prune storage-table internals; name opencode’s extra `get` lines.

## Acceptance

- [x] Fixture whose last eight messages are assistant and whose ninth-from-end is user: `last t3 <id> 8` includes that user message and timestamps.
- [x] `last t3 w0910` (exact title, unique) exits 0 and does not print the whole 80-message thread when `N` is small.
- [x] `last` with an ambiguous search title exits 1 and lists candidates (same as `get`).
- [x] SKILL.md describes *resume* without `raw/`, without sqlite table names, and with a checkable completion criterion.
- [x] SKILL.md `description` mentions continue/resume as its own branch.
- [x] `python3 agent-skills/harness-history/scripts/test_chat_read.py` still passes.
- [x] `sh -n agent-skills/harness-history/scripts/chat-read.sh` passes.

## Verification

```bash
python3 agent-skills/harness-history/scripts/test_chat_read.py
sh -n agent-skills/harness-history/scripts/chat-read.sh
```

Optional live smoke: `scripts/chat-read.sh last t3 w0910 8` on the real db must include the user turn “Commit se devi…” rather than eight assistant status lines only.

No paid worker.

## Worktree safety

- Same as unit 01: `dotfiles`, `agent-skills/harness-history/` only.
- Do not start unit 02 on a dirty 01; 01’s tests must be green.
- Preserve unrelated dirty files in the dotfiles worktree.
