---
name: harness-history
description: Read past conversations from local AI chat stores (Claude Code, Codex, t3.code, Antigravity app, Antigravity CLI, opencode). Use when the user asks to list or search chats, to get or read a named conversation, or to resume or continue a past chat.
---

# Harness History

Find and read past chats with `scripts/chat-read.sh`. Providers: `claude`, `codex`, `t3`, `antigravity`, `antigravity-cli` (alias `agy`), `opencode`.

```bash
scripts/chat-read.sh list <provider> [search-text]
scripts/chat-read.sh get  <provider> <id-or-title>
scripts/chat-read.sh last <provider> <id-or-title> [N]
```

Run the script from this skill directory (or via the symlink in the harness skills dir).

## list — search

`list` is a broad, case-insensitive fixed-string search over title and context columns. It does not prefer an exact title, and it does not search ids.

Columns differ by provider; the last field is context and may be empty. There is no universal `project` column.

| Provider | Columns |
|---|---|
| `claude` | id, time, title, project-dir |
| `codex` | id, date, cwd (no titles) |
| `t3` | id, time, title, branch |
| `antigravity` / `agy` | id, time, first user line |
| `opencode` | id, time, title, worktree, agent |

Empty search → empty stdout, exit 0. A store that cannot be opened → stderr message, exit 1.

## get — read

Resolve in this order: existing id; unique exact title (title field only, case-sensitive); unique `list` candidate. If that does not yield one thread, print the candidates on stderr and exit 1.

Codex has no titles: pass an id (a substring of the rollout filename).

`get` prints user and assistant text. t3 (and other stores that keep a timestamp) prefix each line with it. opencode also prints tool, file, and compaction lines (tool input/output already truncated).

## last — tail

Same resolver as `get`. `N` is a message count, default 20, oldest first. If that window has no user message, expand backward until one user message is included or the thread starts.

Use `last` to continue a chat. Use full `get` only when the thread is smaller than the default window.

## Resume

1. Resolve the chat and load `last` (or `get` when the thread is smaller than the default window).
2. Read the latest user instruction and its constraints.
3. Note the latest assistant claim and any pending actions.
4. Verify the relevant workspace artifacts: `git status`; when the claim is a commit or patch, also `git diff` and `git log`.
5. Continue from the instruction and those artifacts.

Done when the artifacts have been checked against the latest user instruction. Chat text is context, not proof of completion.
