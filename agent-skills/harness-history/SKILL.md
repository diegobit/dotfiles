---
name: harness-history
description: Read past conversations from local AI chat stores (Claude Code, Codex, t3.code, Antigravity, opencode). Use when the user asks "read the chat of <provider> named <title>", "get conversation history for <provider>", or wants to find/search/export conversation history, sessions, or transcripts.
---

# Harness History — 5 Provider Chat Stores

Find and read past conversations from **Claude Code, Codex, t3.code, Antigravity, and opencode** using `scripts/chat-read.sh`.

## Supported Providers & Storage

| Provider | Storage Location | Content Format |
|---|---|---|
| Claude Code | `~/.claude/projects/<project-dir>/<uuid>.jsonl` | JSONL events |
| Codex | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` | JSONL events |
| t3.code | `/Users/diego/.t3/userdata/state.sqlite` | SQLite (`projection_threads`, `projection_thread_messages`) |
| Antigravity | `~/.gemini/antigravity/brain/<uuid>/.system_generated/logs/transcript.jsonl` | Human-readable transcript JSONL |
| opencode | `~/.local/share/opencode/opencode.db` | SQLite (`session`, `message`, `part`) |

## Usage

```bash
# List conversations (columns: id | date | title/workspace | project)
scripts/chat-read.sh list claude|codex|t3|antigravity|opencode [search-text]

# Print conversation in plain text (user/assistant only)
scripts/chat-read.sh get  <provider> <chat-id-or-title>
```

- `list` → columns `id | date | title/workspace | project`.
- `get` → plain text conversation (user/assistant only, no binaries).
- `get` also accepts a title: if it finds exactly 1 match it will use it, otherwise it lists candidate matches.

> [!TIP]
> To inspect underlying schemas, query implementations, or customize searches (e.g. searching deep inside raw message payloads), view `scripts/chat-read.sh`
