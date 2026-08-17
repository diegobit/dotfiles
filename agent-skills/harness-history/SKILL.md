---
name: harness-history
description: Read past conversations from the 5 local AI chat stores (Claude Code, Codex, t3.code, Antigravity, opencode). Use when the user asks "read the chat of <provider> named <title>", "get conversation history for <provider>", or wants to find/search/export conversation history, sessions, or transcripts. Use the bundled chat-read.sh script FIRST — it wraps all queries below and avoids re-deriving them.
---

# Harness History — 5 Provider Chat Stores

Objective: Find and read past conversations from **Claude Code, Codex, t3.code, Antigravity, opencode**. Before writing queries manually, always use `scripts/chat-read.sh` (all recipes below are already implemented inside it).

## Quick Reference (One line per provider)

| Provider | Where chats are stored | Content format |
|---|---|---|
| Claude Code | `~/.claude/projects/<project-dir>/<uuid>.jsonl` (1 file = 1 chat) | JSONL events |
| Codex | `~/.codex/sessions/YYYY/MM/DD/rollout-<ts>-<ulid>.jsonl` | JSONL `{timestamp,type,payload}` |
| t3.code | `/Users/diego/.t3/userdata/state.sqlite` | SQLite (plain text) |
| Antigravity | `~/.gemini/antigravity/conversations/<uuid>.db` + `brain/<uuid>/.system_generated/logs/transcript.jsonl` | SQLite (protobuf) + human-readable transcript JSONL |
| opencode | `~/.local/share/opencode/opencode.db` | SQLite (`message`=summary, `part`=content) |

## Quick Usage

```
chat-read.sh list claude|codex|t3|antigravity|opencode [search-text]
chat-read.sh get  <provider> <chat-id-or-title>
```

- `list` → columns `id | date | title/workspace | project`.
- `get` → plain text conversation (user/assistant only, no binaries).
- `get` also accepts a title: if it finds exactly 1 match it will use it, otherwise it lists candidate matches.

## Provider Recipes (Fallback if script fails)

### Claude Code
- Title: events `{"type":"ai-title","aiTitle":...}`. ID = filename `<uuid>.jsonl`.
- List titles: `for f in ~/.claude/projects/*/*.jsonl; do jq -r 'select(.type=="ai-title") | "\(.sessionId)\t\(.aiTitle)"' "$f" 2>/dev/null; done`
- Read chat: `jq -r 'def txt: if (.message.content|type)=="string" then .message.content else (.message.content//[]|map(select(.type=="text")|.text)|join("\n")) end; select(.type=="user" or .type=="assistant")|select(.message!=null)|"[\(.message.role)] \(txt)"' <file>`
- Message tree via `parentUuid`→`uuid`. Subagents: `<uuid>/subagents/agent-*.jsonl`.

### Codex
- **No titles**: search by content/cwd/date. ID = ULID in filename (`rollout-2026-07-01T09-01-41-019f1c7b-…`), session = `payload.session_id` (first line, `session_meta`, has `cwd`, `cli_version`, `model_provider`).
- Messages in lines `{"type":"event_msg","payload":{"type":"user_message"|"agent_message","message":...}}` (same format in old and new versions; `message` is either a string or `content[]` with `text`). The script handles both.

### t3.code
- List: `sqlite3 /Users/diego/.t3/userdata/state.sqlite "SELECT thread_id, substr(created_at,1,16), title FROM projection_threads WHERE deleted_at IS NULL ORDER BY updated_at DESC;"`
- Read: `sqlite3 /Users/diego/.t3/userdata/state.sqlite "SELECT '['||role||'] '||text FROM projection_thread_messages WHERE thread_id='<id>' ORDER BY created_at, message_id;"`
- Useful tables: `projection_projects` (id→title, workspace_root), `projection_turns` (model runs), `projection_thread_messages` (plain text).

### Antigravity
- **Do not read .db/protobuf directly**: use `brain/<uuid>/.system_generated/logs/transcript.jsonl` (and `_full.jsonl`): lines `{step_index,type,content|thinking|tool_calls}` with `USER_INPUT` (user prompt), `PLANNER_RESPONSE` (assistant response: `thinking`+`content`), `RUN_COMMAND`, `VIEW_FILE`, `CHECKPOINT`.
- Titles: uuid→title mapping in `agyhub_summaries_proto.pb` (binary: `strings ~/.gemini/antigravity/agyhub_summaries_proto.pb | grep -B1 <keyword>`), or the first `USER_INPUT` of the transcript.
- ID = filename `<uuid>.db` (= `cascade_id` in `trajectory_meta`).

### opencode
- List: `sqlite3 ~/.local/share/opencode/opencode.db "SELECT id, datetime(time_created/1000,'unixepoch'), title, agent FROM session WHERE time_archived IS NULL ORDER BY time_created DESC;"`
- Read (join message→part):
```sql
SELECT json_extract(m.data,'$.role'), p.data FROM message m
JOIN part p ON p.message_id=m.id WHERE m.session_id='<id>'
ORDER BY m.time_created, p.time_created;
```
  `part.data.type`: `text`=content; `tool`=`{tool,state:{input,output}}`; `file`/`patch`/`reasoning`/`step-start`/`step-finish`/`compaction`. Token/model costs are in `message.data`, not in `part`.
- Subagents = sessions where `parent_id` is not null. Large tool outputs are stored in `~/.local/share/opencode/tool-output/tool_<partid>`.

## Key Notes (Pitfalls)

- **Timestamps**: opencode = millisecond epoch; Claude/Codex = ISO UTC; t3/Antigravity = ISO.
- **Claude project names**: path with `/` and `~`→`-` (e.g., `-Users-diego-code-dg-rivolo-app`).
- SQLite in t3/opencode may have WAL open while the app is running: reading with `sqlite3` is still safe.
- Codex and Claude are JSONL: navigate them with `find`+`grep -l` (no database).
