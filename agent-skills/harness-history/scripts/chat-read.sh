#!/usr/bin/env bash
# chat-read.sh — read conversations from Claude Code, Codex, t3.code, Antigravity, opencode
# Usage:
#   chat-read.sh list <provider> [search-text]
#   chat-read.sh get  <provider> <id-or-title>
#   chat-read.sh last <provider> <id-or-title> [N]
set -euo pipefail

CLAUDE_ROOT="${CLAUDE_ROOT:-$HOME/.claude/projects}"
CODEX_ROOT="${CODEX_ROOT:-$HOME/.codex/sessions}"
T3_DB="${T3_DB:-$HOME/.t3/userdata/state.sqlite}"
ANTI_ROOT="${ANTI_ROOT:-$HOME/.gemini/antigravity}"
ANTI_CLI_ROOT="${ANTI_CLI_ROOT:-$HOME/.gemini/antigravity-cli}"
OC_DB="${OC_DB:-$HOME/.local/share/opencode/opencode.db}"

HERE="$(cd "$(dirname "$0")" && pwd)"
STORE="$HERE/chat_store.py"
PROVIDERS="claude|codex|t3|antigravity|antigravity-cli (agy)|opencode"
DEFAULT_LAST=20

usage() {
  cat <<EOF
chat-read.sh list <provider> [search-text]
chat-read.sh get  <provider> <id-or-title>
chat-read.sh last <provider> <id-or-title> [N]
provider: $PROVIDERS
list searches title/context, not ids. get resolves id, then unique exact title, then unique search.
last prints the last N messages (default $DEFAULT_LAST), oldest first; if that window has no user message it expands backward until one is included.
EOF
  exit 1
}

ts_fmt() { date -r "$1" "+%F %H:%M"; }

# Search fields after the id column (field 1). Fixed-string, case-insensitive.
filter_search() {
  local q="$1"
  awk -F '\t' -v q="$q" '
    BEGIN { ql = tolower(q) }
    q == "" { print; next }
    {
      hit = 0
      for (i = 2; i <= NF; i++) if (index(tolower($i), ql)) { hit = 1; break }
      if (hit) print
    }
  '
}

exact_title_rows() {
  local title="$1"
  awk -F '\t' -v t="$title" '$3 == t { print }'
}

print_candidates() {
  local query="$1" rows="$2" n
  n="$(printf '%s\n' "$rows" | grep -c . || true)"
  printf 'Found %s chats for "%s", please specify an id:\n%s\n' "$n" "$query" "$rows" >&2
}

# ---------- CLAUDE ----------
list_claude_all() {
  local f proj
  shopt -s nullglob
  for f in "$CLAUDE_ROOT"/*/*.jsonl; do
    proj="$(basename "$(dirname "$f")")"
    jq -r --arg proj "$proj" 'select(.type=="ai-title") | [.sessionId, .aiTitle] | @tsv' "$f" 2>/dev/null |
      while IFS=$'\t' read -r id title; do
        printf '%s\t%s\t%s\t%s\n' "$id" "$(ts_fmt "$(stat -f %m "$f")")" "$title" "$proj"
      done
  done | awk -F'\t' '!seen[$1]++' | sort -k2 -r
}

list_claude() {
  list_claude_all | filter_search "$1"
}

resolve_from_rows() {
  local query="$1" all="$2" id_col_match exact search n
  id_col_match="$(printf '%s\n' "$all" | awk -F '\t' -v q="$query" '$1 == q { print }')"
  if [ -n "$id_col_match" ]; then
    printf '%s\n' "$id_col_match" | head -1
    return 0
  fi
  exact="$(printf '%s\n' "$all" | exact_title_rows "$query")"
  n="$(printf '%s\n' "$exact" | grep -c . || true)"
  if [ "$n" = "1" ]; then
    printf '%s\n' "$exact"
    return 0
  fi
  if [ "$n" -gt 1 ]; then
    print_candidates "$query" "$exact"
    return 1
  fi
  search="$(printf '%s\n' "$all" | filter_search "$query")"
  n="$(printf '%s\n' "$search" | grep -c . || true)"
  if [ "$n" = "1" ]; then
    printf '%s\n' "$search"
    return 0
  fi
  print_candidates "$query" "$search"
  return 1
}

get_claude() {
  local query="$1" f="" id row all
  shopt -s nullglob
  for cand in "$CLAUDE_ROOT"/*/*.jsonl; do
    [ -f "$cand" ] || continue
    id="$(basename "$cand" .jsonl)"
    if [ "$id" = "$query" ]; then f="$cand"; break; fi
  done
  if [ -z "$f" ]; then
    all="$(list_claude_all)"
    row="$(resolve_from_rows "$query" "$all")" || return 1
    id="$(printf '%s\n' "$row" | cut -f1)"
    f="$CLAUDE_ROOT/$(printf '%s\n' "$row" | cut -f4)/$id.jsonl"
  fi
  jq -r '
    def txt: if (.message.content|type)=="string" then .message.content
             else (.message.content//[]|map(select(.type=="text")|.text)|join("\n")) end;
    select(.type=="user" or .type=="assistant") | select(.message!=null)
    | "[\(.message.role)] \(txt)"' "$f"
}

last_from_role_stream() {
  local n="$1"
  python3 -c '
import sys
try:
    n = int(sys.argv[1])
except ValueError:
    sys.stderr.write("chat-read: N must be a positive integer\n")
    sys.exit(1)
if n < 1:
    sys.stderr.write("chat-read: N must be a positive integer\n")
    sys.exit(1)
raw = sys.stdin.read().splitlines(keepends=True)
blocks = []
cur = []
for line in raw:
    if line.startswith("[user]") or line.startswith("[assistant]") or line.startswith("[User]") or line.startswith("[Assistant]"):
        if cur:
            blocks.append("".join(cur))
        cur = [line]
    else:
        if cur:
            cur.append(line)
        else:
            cur = [line]
if cur:
    blocks.append("".join(cur))
if not blocks:
    sys.exit(0)
start = max(0, len(blocks) - n)
def has_user(bs):
    return any(b.startswith("[user]") or b.startswith("[User]") for b in bs)
while start > 0 and not has_user(blocks[start:]):
    start -= 1
sys.stdout.write("".join(blocks[start:]))
' "$n"
}

last_claude() {
  local query="$1" n="$2"
  get_claude "$query" | last_from_role_stream "$n"
}

# ---------- CODEX ----------
list_codex_all() {
  find "$CODEX_ROOT" -name 'rollout-*.jsonl' 2>/dev/null | while read -r f; do
    head -1 "$f" 2>/dev/null | jq -r --arg f "$f" '
      select(.type=="session_meta")
      | [.payload.session_id, $f, (.payload.cwd // "")] | @tsv'
  done | while IFS=$'\t' read -r id f cwd; do
    local d; d="$(basename "$f" | cut -c9-18)"
    printf '%s\t%s\t%s\n' "$id" "$d" "$cwd"
  done | sort -k2
}

list_codex() {
  list_codex_all | filter_search "$1"
}

get_codex() {
  local query="$1" f
  # Codex has no titles: id is a substring of the rollout filename.
  f="$(find "$CODEX_ROOT" -name "rollout-*${query}*.jsonl" 2>/dev/null | head -1)"
  if [ -z "$f" ]; then
    printf 'Codex has no titles: pass an id (e.g. 019f1c7b-c38f-7931-af3d-718232a0c98e) or search by content:\n  grep -rl "%s" %s\n' "$query" "$CODEX_ROOT" >&2
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

last_codex() {
  get_codex "$1" | last_from_role_stream "$2"
}

# ---------- T3 / OPENCODE (sqlite) ----------
run_store() {
  python3 "$STORE" "$@"
}

list_t3() { run_store t3-list "$T3_DB" "$1"; }
get_t3() { run_store t3-get "$T3_DB" "$1"; }
last_t3() { run_store t3-last "$T3_DB" "$1" "$2"; }

list_opencode() { run_store oc-list "$OC_DB" "$1"; }
get_opencode() { run_store oc-get "$OC_DB" "$1"; }
last_opencode() { run_store oc-last "$OC_DB" "$1" "$2"; }

# ---------- ANTIGRAVITY ----------
list_antigravity_all() {
  local root="$1" d t id title
  shopt -s nullglob
  for d in "$root"/brain/*/; do
    t="$d.system_generated/logs/transcript.jsonl"
    [ -f "$t" ] || continue
    id="$(basename "$d")"
    title="$(jq -r 'select(.type=="USER_INPUT") | .content' "$t" 2>/dev/null | grep -v '^<' | grep -v '^$' | head -1 | cut -c1-90)"
    printf '%s\t%s\t%s\n' "$id" "$(ts_fmt "$(stat -f %m "$t")")" "${title:-}"
  done | sort -k2 -r
}

list_antigravity() {
  list_antigravity_all "$1" | filter_search "$2"
}

get_antigravity() {
  local root="$1" query="$2" id="$2" row all
  if [ ! -f "$root/brain/$id/.system_generated/logs/transcript.jsonl" ]; then
    all="$(list_antigravity_all "$root")"
    row="$(resolve_from_rows "$query" "$all")" || return 1
    id="$(printf '%s\n' "$row" | cut -f1)"
  fi
  jq -r '
    select(.type=="USER_INPUT" or .type=="PLANNER_RESPONSE")
    | "\n===== \(.type) \(.created_at // "") =====\n" + (.content // "")' \
    "$root/brain/$id/.system_generated/logs/transcript.jsonl"
}

last_antigravity() {
  local root="$1" query="$2" n="$3"
  get_antigravity "$root" "$query" | python3 -c '
import sys
try:
    n = int(sys.argv[1])
except ValueError:
    sys.stderr.write("chat-read: N must be a positive integer\n")
    sys.exit(1)
if n < 1:
    sys.stderr.write("chat-read: N must be a positive integer\n")
    sys.exit(1)
text = sys.stdin.read()
parts = []
buf = []
for line in text.splitlines(keepends=True):
    if line.startswith("===== "):
        if buf:
            parts.append("".join(buf))
        buf = [line]
    else:
        buf.append(line)
if buf:
    parts.append("".join(buf))
if not parts:
    sys.exit(0)
start = max(0, len(parts) - n)
def has_user(ps):
    return any("USER_INPUT" in p.split("\n", 1)[0] for p in ps)
while start > 0 and not has_user(parts[start:]):
    start -= 1
sys.stdout.write("".join(parts[start:]))
' "$n"
}

# ---------- MAIN ----------
cmd="${1:-}"; prov="${2:-}"
[ $# -ge 2 ] || usage
q="${3:-}"
n="$DEFAULT_LAST"
case "$cmd" in
  last)
    [ $# -ge 3 ] || usage
    if [ $# -ge 4 ]; then n="$4"; fi
    ;;
  get)
    [ $# -ge 3 ] || usage
    ;;
  list) ;;
  *) usage ;;
esac

case "$prov" in
  claude)
    case "$cmd" in
      list) list_claude "$q" ;;
      get) get_claude "$q" ;;
      last) last_claude "$q" "$n" ;;
    esac
    ;;
  codex)
    case "$cmd" in
      list) list_codex "$q" ;;
      get) get_codex "$q" ;;
      last) last_codex "$q" "$n" ;;
    esac
    ;;
  t3)
    case "$cmd" in
      list) list_t3 "$q" ;;
      get) get_t3 "$q" ;;
      last) last_t3 "$q" "$n" ;;
    esac
    ;;
  antigravity)
    case "$cmd" in
      list) list_antigravity "$ANTI_ROOT" "$q" ;;
      get) get_antigravity "$ANTI_ROOT" "$q" ;;
      last) last_antigravity "$ANTI_ROOT" "$q" "$n" ;;
    esac
    ;;
  antigravity-cli|agy)
    case "$cmd" in
      list) list_antigravity "$ANTI_CLI_ROOT" "$q" ;;
      get) get_antigravity "$ANTI_CLI_ROOT" "$q" ;;
      last) last_antigravity "$ANTI_CLI_ROOT" "$q" "$n" ;;
    esac
    ;;
  opencode)
    case "$cmd" in
      list) list_opencode "$q" ;;
      get) get_opencode "$q" ;;
      last) last_opencode "$q" "$n" ;;
    esac
    ;;
  *) usage ;;
esac
