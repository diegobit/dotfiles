#!/usr/bin/env bash
# chat-read.sh — read conversations from Claude Code, Codex, t3.code, Antigravity, opencode
# Usage:
#   chat-read.sh list <provider> [text]      list chats: id | date | title/workspace | project
#   chat-read.sh get  <provider> <id|title>  print conversation in plain text
set -euo pipefail

CLAUDE_ROOT="$HOME/.claude/projects"
CODEX_ROOT="$HOME/.codex/sessions"
T3_DB="/Users/diego/.t3/userdata/state.sqlite"
ANTI_ROOT="$HOME/.gemini/antigravity"
ANTI_CLI_ROOT="$HOME/.gemini/antigravity-cli"   # agy workers: separate store, same format
OC_DB="$HOME/.local/share/opencode/opencode.db"

PROVIDERS="claude|codex|t3|antigravity|antigravity-cli (agy)|opencode"

usage() {
  cat <<EOF
chat-read.sh list <provider> [search-text]
chat-read.sh get  <provider> <chat-id-or-title>
provider: $PROVIDERS
EOF
  exit 1
}

ts_fmt() { date -r "$1" "+%F %H:%M"; }

# ---------- CLAUDE ----------
list_claude() {
  local q="$1"
  for f in "$CLAUDE_ROOT"/*/*.jsonl; do
    [ -f "$f" ] || continue
    local proj; proj="$(basename "$(dirname "$f")")"
    jq -r --arg proj "$proj" 'select(.type=="ai-title") | [.sessionId, .aiTitle] | @tsv' "$f" 2>/dev/null |
      while IFS=$'\t' read -r id title; do
        printf '%s\t%s\t%s\t%s\n' "$id" "$(ts_fmt "$(stat -f %m "$f")")" "$title" "$proj"
      done
  done | awk -F'\t' '!seen[$1]++' | sort -k2 -r | grep -i "$q" || true
}

get_claude() {
  local query="$1" f="" id
  for cand in "$CLAUDE_ROOT"/*/*.jsonl; do
    [ -f "$cand" ] || continue
    id="$(basename "$cand" .jsonl)"
    if [ "$id" = "$query" ]; then f="$cand"; break; fi
  done
  if [ -z "$f" ]; then
    local m; m="$(list_claude "$query")"
    local n; n="$(printf '%s\n' "$m" | grep -c . || true)"
    if [ "$n" = "1" ]; then
      id="$(printf '%s\n' "$m" | cut -f1)"
      f="$CLAUDE_ROOT/$(printf '%s\n' "$m" | cut -f4)/$id.jsonl"
    else
      printf 'Found %s chats for "%s", please specify an id:\n%s\n' "$n" "$query" "$m"
      return 1
    fi
  fi
  jq -r '
    def txt: if (.message.content|type)=="string" then .message.content
             else (.message.content//[]|map(select(.type=="text")|.text)|join("\n")) end;
    select(.type=="user" or .type=="assistant") | select(.message!=null)
    | "[\(.message.role)] \(txt)"' "$f"
}

# ---------- CODEX ----------
list_codex() {
  local q="$1"
  find "$CODEX_ROOT" -name 'rollout-*.jsonl' 2>/dev/null | while read -r f; do
    head -1 "$f" 2>/dev/null | jq -r --arg f "$f" '
      select(.type=="session_meta")
      | [.payload.session_id, $f, (.payload.cwd // "")] | @tsv'
  done | while IFS=$'\t' read -r id f cwd; do
    local d; d="$(basename "$f" | cut -c9-18)"
    printf '%s\t%s\t%s\n' "$id" "$d" "$cwd"
  done | sort -k2 | grep -i "$q" || true
}

get_codex() {
  local query="$1" f
  f="$(find "$CODEX_ROOT" -name "rollout-*${query}*.jsonl" 2>/dev/null | head -1)"
  if [ -z "$f" ]; then
    printf 'Codex has no titles: pass an id (e.g. 019f1c7b-c38f-7931-af3d-718232a0c98e) or search by content:\n  grep -rl "%s" %s\n' "$query" "$CODEX_ROOT"
    return 1
  fi
  jq -r '
    select(.type == "event_msg" and (.payload.type? == "user_message" or .payload.type? == "agent_message"))
    | (if .payload.type? == "user_message" then "user" else "assistant" end) as $role
    | (if (.payload.message? | type) == "string"
         then [.payload.message]
         else (.payload.message.content? // [] | map(select(.text? != null) | .text?))
       end)[]
    | "[\($role)] " + .' "$f"
}

# ---------- T3 ----------
list_t3() {
  local q="$1"
  sqlite3 -separator $'\t' "$T3_DB" \
    "SELECT thread_id, substr(created_at,1,16), title FROM projection_threads WHERE deleted_at IS NULL ORDER BY updated_at DESC" \
    2>/dev/null | grep -i "$q" || true
}

get_t3() {
  local query="$1" id="$1"
  if ! sqlite3 "$T3_DB" "SELECT 1 FROM projection_threads WHERE thread_id='$id'" 2>/dev/null | grep -q 1; then
    local m; m="$(list_t3 "$query")"
    local n; n="$(printf '%s\n' "$m" | grep -c . || true)"
    if [ "$n" = "1" ]; then id="$(printf '%s\n' "$m" | cut -f1)"
    else printf 'Found %s chats for "%s", please specify an id:\n%s\n' "$n" "$query" "$m"; return 1; fi
  fi
  sqlite3 -separator $'\n' "$T3_DB" \
    "SELECT '['||role||'] '||text FROM projection_thread_messages WHERE thread_id='$id' ORDER BY created_at, message_id"
}

# ---------- ANTIGRAVITY (app and agy CLI: two separate stores, identical format) ----------
list_antigravity() {
  local root="$1" q="$2"
  for d in "$root"/brain/*/; do
    local t="$d.system_generated/logs/transcript.jsonl"
    [ -f "$t" ] || continue
    local id; id="$(basename "$d")"
    local title; title="$(jq -r 'select(.type=="USER_INPUT") | .content' "$t" 2>/dev/null | grep -v '^<' | grep -v '^$' | head -1 | cut -c1-90)"
    printf '%s\t%s\t%s\n' "$id" "$(ts_fmt "$(stat -f %m "$t")")" "${title:-}"
  done | sort -k2 -r | grep -i "$q" || true
}

get_antigravity() {
  local root="$1" query="$2" id="$2"
  [ -f "$root/brain/$id/.system_generated/logs/transcript.jsonl" ] || {
    local m; m="$(list_antigravity "$root" "$query")"
    local n; n="$(printf '%s\n' "$m" | grep -c . || true)"
    if [ "$n" = "1" ]; then id="$(printf '%s\n' "$m" | cut -f1)"
    else printf 'Found %s chats for "%s", please specify an id:\n%s\n' "$n" "$query" "$m"; return 1; fi
  }
  jq -r '
    select(.type=="USER_INPUT" or .type=="PLANNER_RESPONSE")
    | "\n===== \(.type) \(.created_at // "") =====\n" + (.content // "")' \
    "$root/brain/$id/.system_generated/logs/transcript.jsonl"
}

# ---------- OPENCODE ----------
list_opencode() {
  local q="$1"
  sqlite3 -separator $'\t' "$OC_DB" \
    "SELECT s.id, datetime(s.time_created/1000,'unixepoch'), s.title, coalesce(p.worktree,''), s.agent
     FROM session s LEFT JOIN project p ON p.id=s.project_id
     WHERE s.time_archived IS NULL ORDER BY s.time_created DESC" \
    2>/dev/null | grep -i "$q" || true
}

get_opencode() {
  local query="$1" id="$1"
  if ! sqlite3 "$OC_DB" "SELECT 1 FROM session WHERE id='$id'" 2>/dev/null | grep -q 1; then
    local m; m="$(list_opencode "$query")"
    local n; n="$(printf '%s\n' "$m" | grep -c . || true)"
    if [ "$n" = "1" ]; then id="$(printf '%s\n' "$m" | cut -f1)"
    else printf 'Found %s chats for "%s", please specify an id:\n%s\n' "$n" "$query" "$m"; return 1; fi
  fi
  sqlite3 -separator $'\t' "$OC_DB" \
    "SELECT json_extract(m.data,'$.role'), json_extract(p.data,'$.type'), p.data
     FROM message m JOIN part p ON p.message_id=m.id
     WHERE m.session_id='$id' ORDER BY m.time_created, p.time_created" 2>/dev/null | while IFS=$'\t' read -r role ptype data; do
    case "$ptype" in
      text)      echo "[$role] $(jq -r '.text' <<<"$data")" ;;
      tool)      echo "## tool $(jq -r '.tool' <<<"$data")"; jq -r '.state.input // "" | tostring' <<<"$data" | head -c 400; echo; jq -r '.state.output // "" | tostring' <<<"$data" | head -c 800; echo ;;
      file)      echo "## file $(jq -r '.filename // ""' <<<"$data")" ;;
      compaction) echo "**[compaction]**" ;;
      *)         : ;;
    esac
  done
}

# ---------- MAIN ----------
cmd="${1:-}"; prov="${2:-}"; q="${3:-}"
[ $# -ge 2 ] || usage
case "$prov" in
  claude)      case "$cmd" in list) list_claude "$q";; get) get_claude "$q";; *) usage;; esac ;;
  codex)       case "$cmd" in list) list_codex "$q";; get) get_codex "$q";; *) usage;; esac ;;
  t3)          case "$cmd" in list) list_t3 "$q";; get) get_t3 "$q";; *) usage;; esac ;;
  antigravity) case "$cmd" in list) list_antigravity "$ANTI_ROOT" "$q";; get) get_antigravity "$ANTI_ROOT" "$q";; *) usage;; esac ;;
  antigravity-cli|agy)
               case "$cmd" in list) list_antigravity "$ANTI_CLI_ROOT" "$q";; get) get_antigravity "$ANTI_CLI_ROOT" "$q";; *) usage;; esac ;;
  opencode)    case "$cmd" in list) list_opencode "$q";; get) get_opencode "$q";; *) usage;; esac ;;
  *) usage ;;
esac
