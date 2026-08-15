---
name: harness-history
description: Read past conversations from the 5 local AI chat stores (Claude Code, Codex, t3.code, Antigravity, opencode). Use when the user asks "leggi la chat di <provider> chiamata <nome>", "read the chat of <provider> named <title>", or wants to find/search/export conversation history, sessions, or transcripts. Use the bundled chat-read.sh script FIRST — it wraps all queries below and avoids re-deriving them.
---

# Harness History — chat di 5 provider

Obiettivo: trovare e leggere conversazioni passate di **Claude Code, Codex, t3.code, Antigravity, opencode**. Prima di scrivere query a mano usa sempre `scripts/chat-read.sh` (tutte le ricette sotto sono già lì dentro).

## Riferimento rapido (una riga per provider)

| Provider | Dove stanno le chat | Formato contenuti |
|---|---|---|
| Claude Code | `~/.claude/projects/<project-dir>/<uuid>.jsonl` (1 file = 1 chat) | JSONL di eventi |
| Codex | `~/.codex/sessions/YYYY/MM/DD/rollout-<ts>-<ulid>.jsonl` | JSONL `{timestamp,type,payload}` |
| t3.code | `/Users/diego/.t3/userdata/state.sqlite` | SQLite (testo già in chiaro) |
| Antigravity | `~/.gemini/antigravity/conversations/<uuid>.db` + `brain/<uuid>/.system_generated/logs/transcript.jsonl` | SQLite (protobuf) + transcript JSONL leggibile |
| opencode | `~/.local/share/opencode/opencode.db` | SQLite (`message`=riepilogo, `part`=contenuto) |

## Uso rapido

```
chat-read.sh list claude|codex|t3|antigravity|opencode [testo-cerca]
chat-read.sh get  <provider> <id-chat-o-titolo>
```

- `list` → colonne `id | data | titolo/workspace | progetto`.
- `get` → la conversazione in testo puro (solo user/assistant, senza binario).
- Il `get` accetta anche un titolo: se trova 1 sola corrispondenza la usa, altrimenti elenca i candidati.

## Ricette per provider (fallback se lo script fallisce)

### Claude Code
- Titolo: eventi `{"type":"ai-title","aiTitle":...}`. ID = nome file `<uuid>.jsonl`.
- Lista titoli: `for f in ~/.claude/projects/*/*.jsonl; do jq -r 'select(.type=="ai-title") | "\(.sessionId)\t\(.aiTitle)"' "$f" 2>/dev/null; done`
- Leggi chat: `jq -r 'def txt: if (.message.content|type)=="string" then .message.content else (.message.content//[]|map(select(.type=="text")|.text)|join("\n")) end; select(.type=="user" or .type=="assistant")|select(.message!=null)|"[\(.message.role)] \(txt)"' <file>`
- Albero messaggi via `parentUuid`→`uuid`. Subagenti: `<uuid>/subagents/agent-*.jsonl`.

### Codex
- **Niente titoli**: cerca per contenuto/cwd/data. ID = ULID nel filename (`rollout-2026-07-01T09-01-41-019f1c7b-…`), sessione = `payload.session_id` (prima riga, `session_meta`, ha `cwd`, `cli_version`, `model_provider`).
- Messaggi in righe `{"type":"event_msg","payload":{"type":"user_message"|"agent_message","message":...}}` (stesso formato vecchio e nuovo; `message` è stringa, oppure `content[]` con `text`). Lo script gestisce entrambi.

### t3.code
- Lista: `sqlite3 /Users/diego/.t3/userdata/state.sqlite "SELECT thread_id, substr(created_at,1,16), title FROM projection_threads WHERE deleted_at IS NULL ORDER BY updated_at DESC;"`
- Leggi: `sqlite3 /Users/diego/.t3/userdata/state.sqlite "SELECT '['||role||'] '||text FROM projection_thread_messages WHERE thread_id='<id>' ORDER BY created_at, message_id;"`
- Tabelle utili: `projection_projects` (id→title, workspace_root), `projection_turns` (run del modello), `projection_thread_messages` (testo in chiaro).

### Antigravity
- **Non leggere i .db/protobuf**: usa `brain/<uuid>/.system_generated/logs/transcript.jsonl` (e `_full.jsonl`): righe `{step_index,type,content|thinking|tool_calls}` con `USER_INPUT` (prompt user), `PLANNER_RESPONSE` (risposta assistant: `thinking`+`content`), `RUN_COMMAND`, `VIEW_FILE`, `CHECKPOINT`.
- Titoli: mappa uuid→titolo in `agyhub_summaries_proto.pb` (binario: `strings ~/.gemini/antigravity/agyhub_summaries_proto.pb | grep -B1 <parola>`), oppure primo `USER_INPUT` del transcript.
- ID = nome file `<uuid>.db` (= `cascade_id` in `trajectory_meta`).

### opencode
- Lista: `sqlite3 ~/.local/share/opencode/opencode.db "SELECT id, datetime(time_created/1000,'unixepoch'), title, agent FROM session WHERE time_archived IS NULL ORDER BY time_created DESC;"`
- Leggi (join message→part):
```sql
SELECT json_extract(m.data,'$.role'), p.data FROM message m
JOIN part p ON p.message_id=m.id WHERE m.session_id='<id>'
ORDER BY m.time_created, p.time_created;
```
  `part.data.type`: `text`=contenuto; `tool`=`{tool,state:{input,output}}`; `file`/`patch`/`reasoning`/`step-start`/`step-finish`/`compaction`. Token/costo modello stanno in `message.data`, non in part.
- Subagenti = session con `parent_id` non nullo. Output tool grandi finiscono in `~/.local/share/opencode/tool-output/tool_<partid>`.

## Note chiave (pitfall)

- **Timestamp**: opencode = epoch millisecondi; Claude/Codex = ISO UTC; t3/Antigravity = ISO.
- **Nomi progetti Claude**: path con `/` e `~`→`-` (es. `-Users-diego-code-dg-rivolo-app`).
- SQLite di t3/opencode può avere WAL aperto mentre l'app gira: la lettura con `sqlite3` è comunque sicura.
- Codex e Claude sono JSONL: si navigano con `find`+`grep -l` (nessun DB).
