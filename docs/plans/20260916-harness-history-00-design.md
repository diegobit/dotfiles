# Design: Harness-history lookup and resume

Status: `done`
Ledger: [TODO.md](TODO.md)
Work units:
- [01 Safe lookup and exact title](20260916-harness-history-01-lookup.md)
- [02 last and resume recipe](20260916-harness-history-02-last.md)

Source of truth: `agent-skills/harness-history/` (symlinked into harness discovery dirs; do not edit the copies).

## Problem Statement

An agent asked to read or continue a past chat (`/harness-history t3 "w0910"`) cannot reliably find the thread or know what to load. `get` treats the query as a case-insensitive regex over the whole list row, so a unique exact title still collides with substring cousins and with the current session. `get` then dumps the entire transcript (no timestamps on t3), and the skill has no resume branch: the agent either over-reads or trusts the chat’s last “I’ll commit” as done. The skill also promises a universal `project` column and “user/assistant only” output that the script does not honour.

Measured on t3 `w0910` (2026-09-16): `list t3 w0910` and `get t3 w0910` return four rows; the live DB has 84 messages (19 user); the opening user turn is ~38 KB; the last eight messages are all assistant; `worktree_path` is NULL.

## Solution

Keep `list` as a broad search. Make `get` resolve id, then unique exact title, then search candidates. Add `last` so resume loads a bounded tail that still contains the latest user instruction, with timestamps. Rewrite the skill around those three branches and the real output contract. Historical claims are context; the agent verifies workspace artifacts before repeating work.

## User Stories

1. As an agent given an exact chat title, I want `get` to select that thread when the title is unique, so substring cousins and the current session do not block resume.
2. As an agent searching loosely, I want `list` to still match partial titles, so discovery does not require memorising the exact string.
3. As an agent resolving by id, I want id lookup to win even when the id appears inside another row’s text, so a known uuid is unambiguous.
4. As an agent continuing a chat, I want a timestamped tail that includes the latest user instruction, so I do not dump a 190 KB paste or resume from assistant-only noise.
5. As an agent following the skill, I want the documented columns and `get` contents to match the script, so I do not invent a `project` field or drop opencode tool lines that are actually printed.
6. As an operator, I want a failed store read to fail the command, so a missing database does not look like “no chats”.
7. As an operator, I want user-supplied ids and titles bound as SQL parameters, so an apostrophe in a title cannot break or alter the query.

## Implementation Decisions

- Two executable units: lookup correctness first (tests plus `list`/`get`), then `last` plus the resume recipe. The skill may only promise behaviour the script already implements in that unit.
- `get` resolution, in order: existing id → unique exact title (title field only, case-sensitive) → unique search candidate → print candidates and exit 1. Duplicate exact titles list those rows and exit 1.
- `list` stays a search. Search is fixed-string and case-insensitive (`grep -F` / equivalent), not a regex over the whole row. Do not apply exact-title preference to `list`.
- List context column is per-provider and may be empty. t3 emits id, timestamp, title, and branch (not project; `worktree_path` is often empty). The skill documents that instead of a universal four-column contract.
- `last <provider> <id-or-title> [N]` uses the same resolver as `get`. `N` is a message count, default 20. Print chronological order with timestamps. If that window contains no user message, expand backward until one user message is included or the thread starts.
- `last` is implemented for every provider `get` already supports. Codex remains id-only (no titles).
- Store roots (`T3_DB`, Claude/Codex/Antigravity/OpenCode paths) are overridable by environment variables so tests use fixtures and never the live machine stores.
- SQLite queries bind user values; they do not interpolate them into SQL text. Same rule for t3 and opencode.
- A store error is a non-zero exit with a message on stderr. Zero matches is an empty list (or candidate list for `get`) with a distinct, documented exit: `list` empty → 0; `get`/`last` unresolved → 1 as today.
- Skill body: keep a short provider/alias list; drop sqlite table names and absolute paths (those live in the script). Add a *resume* branch: last user instruction, last assistant claim, pending actions, then `git status` plus diff and log when the claim is about a commit. No `raw/` or journal-wiki rule.
- `get` contract: user/assistant text for every provider; opencode additionally prints tool/file/compaction lines (already truncated). Say that in the skill; do not add a new tool-filter.
- Tests live next to the script (`scripts/test_chat_read.py`), following `delegate/scripts/test_delegate.py`: offline fixtures, no paid calls, no live chat stores.

## Testing Decisions

- Seam: the `chat-read.sh` CLI only. Fixture stores via env overrides. Do not assert internal function names.
- Cover: exact unique title; substring-ambiguous `get`; id wins; apostrophe in title/id; sqlite failure is not an empty success; `list` does not regex-match an id prefix unless that prefix is in the title; `last` default window of assistant-only messages expands to the preceding user message; timestamps present on t3 `last`/`get`.
- Live smokes against Diego’s real t3 db are optional and not a merge gate.

## Out of Scope

- journal-wiki `utils/`, PERDITA, ingest, `raw/`.
- New providers, binary/image dump, or changing opencode’s 400/800 truncation.
- Filtering tool-calls down to user/assistant only.
- Exact-title preference on `list`.
- Rewiring `bin/link-agent-skills.sh` (symlinks already point at this directory).

## Open Decisions

None. Default `N=20`, case-sensitive exact titles, `last` on all current providers, and the resume verification recipe are settled above.

## Further Notes

Codex second opinion (2026-09-16, session `01a0ab3f-dc20-71d0-9c49-3cf80a1187f2`): keep (1) and (2) with the `get`-only exact-title and `last` completeness safeguards; weaken “the skill is only a cache”; drop a wiki-specific `raw/` rule; add SQL binding, visible sqlite errors, and honest `get` contents. Independently re-measured: four `w0910` list rows; `get t3 w0910` exit 1; hashes of `SKILL.md` / `chat-read.sh` unchanged during that review.
