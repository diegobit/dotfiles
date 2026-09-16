# 01: Safe lookup and exact title

**Outcome:** `list` and `get` find the intended thread. `get t3 w0910` selects the thread titled exactly `w0910` when that title is unique. A broken database does not look like “no chats”. An apostrophe in a title cannot change the SQL. Reviewer runs the offline tests and the four-row `w0910` case (against a fixture, not the live db).

**Blocked by:** None (can start immediately).

## Scope

- `agent-skills/harness-history/scripts/chat-read.sh` — `list_*` / `get_*`, dispatcher, usage text, store-path constants.
- `agent-skills/harness-history/scripts/test_chat_read.py` — create.
- `agent-skills/harness-history/SKILL.md` — only the `list`/`get` contract: resolution order, search vs exact title, per-provider list columns. Do not add `last` or the resume recipe yet.
- Excluded: `last`, resume steps, opencode tool-line wording (unit 02), harness symlink copies, journal-wiki.

Re-resolve symbol names before editing; line numbers in the Codex review (list_t3 ~100, get_t3 ~106, dispatcher ~180) are hints.

## Decisions and invariants

- Follow [00 design](20260916-harness-history-00-design.md): id → unique exact title → unique search candidate.
- Exact title is case-sensitive equality on the title field only.
- `list` search is case-insensitive fixed-string; keep it broad.
- Env overrides for every store root used in tests (at least `T3_DB` and the sqlite/jsonl roots the fixtures need). Default remains the current machine paths.
- Bind SQL parameters for t3 and opencode. No `thread_id='$id'` concatenation.
- sqlite failures: non-zero exit, stderr visible. Do not `2>/dev/null` + `|| true` the query.
- `get` unresolved: exit 1 and print candidates, as today.
- Live `~/.t3/userdata/state.sqlite` is never opened by tests.

## Implementation outline

1. Add env overrides and a sqlite bind helper (`.parameter` or a python3 helper already justified by the skill’s `python3` dependency).
2. Change `get` title resolution for claude, t3, antigravity/agy, and opencode. Codex stays id/path lookup.
3. Change `list` filtering to fixed-string search; emit honest columns (t3: id, time, title, branch).
4. Surface sqlite errors.
5. Write fixture-backed tests for the cases in 00 Testing Decisions that belong to `list`/`get`.
6. Update SKILL.md `list`/`get` bullets to match, including the `project` column correction.

## Acceptance

- [x] Fixture: threads titled `w0910`, `w0910 astra`, `w0910 cursor`, and `Continue Work from w0910`. `get t3 w0910` prints the exact-title thread and exits 0.
- [x] Same fixture: `get t3 w0910` with the exact-title row removed yields candidates and exit 1 (not a silent pick of a cousin).
- [x] `get t3 <uuid>` of a cousin row still returns that id, not a title match.
- [x] Title containing `'` round-trips in `get`.
- [x] Simulated sqlite failure (missing db file or `chmod`/bad path) exits non-zero; it is not an empty list with exit 0.
- [x] `list t3 w0910` still returns multiple rows (search unchanged in breadth).
- [x] SKILL.md no longer promises a universal `project` column.
- [x] `python3 agent-skills/harness-history/scripts/test_chat_read.py` passes offline.
- [x] `sh -n agent-skills/harness-history/scripts/chat-read.sh` and `git diff --check` pass.

## Verification

```bash
python3 agent-skills/harness-history/scripts/test_chat_read.py
sh -n agent-skills/harness-history/scripts/chat-read.sh
bin/link-agent-skills.sh --check
```

Optional live smoke (not a gate): `scripts/chat-read.sh get t3 w0910` on the real db should open `f37457a9-c7e8-4a1a-92c8-eebff42211db` while that title stays unique.

No paid worker.

## Worktree safety

- Repo: `dotfiles`. Edit only `agent-skills/harness-history/` plus this unit’s test file.
- Re-check branch and dirty state. Do not touch journal-wiki or live chat stores.
- Symlinks under `~/.cursor/skills/harness-history` must keep pointing at `agent-skills/harness-history`; do not duplicate files.
