#!/bin/sh
# Send a Telegram notification. Usage: tg [-p <profilo>] '<text_message>'
# Help: tg --help
#
# I segreti stanno in ~/.telegram-bot-token-<profilo> e ~/.telegram-chat-id-<profilo>.
#   dg   -> notifiche personali Diego
#   ait  -> canale "AIT Alerts"
# Il profilo di default è "dg", salvo che ~/.telegram-default-profile dica altro
#
# Shell-agnostic: usato da cron, script e shell non interattive.

set -e

usage() {
    cat <<EOF
tg - send a Telegram notification to Diego

Usage:
  tg [-p <profilo>] '<text_message>'   send message (cwd is appended)
  tg [-p <profilo>]                    ping: "Plin plon! (cwd)"
  tg --                                message starting with '-'
  tg -h | --help                       this help

Profiles:
  dg     Diego's private chat (default)
  ait    canale "AIT Alerts"

Secrets live in ~/.telegram-bot-token-<profilo> and ~/.telegram-chat-id-<profilo>;
the default is "dg" unless ~/.telegram-default-profile says otherwise.
EOF
}

profile=""
case "$1" in
    -h|--help) usage; exit 0 ;;
    -p|--profile)
        if [ -z "${2:-}" ]; then
            echo "tg: -p richiede un profilo (dg, ait)" >&2
            exit 1
        fi
        profile=$2; shift 2 ;;
    --) shift ;;
    -*) echo "tg: opzione sconosciuta: $1 (--help per l'uso)" >&2; exit 1 ;;
esac

if [ -z "$profile" ]; then
    if [ -r "$HOME/.telegram-default-profile" ]; then
        profile=$(tr -d '[:space:]' < "$HOME/.telegram-default-profile")
    else
        profile=dg
    fi
fi

token_file="$HOME/.telegram-bot-token-$profile"
chat_file="$HOME/.telegram-chat-id-$profile"

for f in "$token_file" "$chat_file"; do
    if [ ! -r "$f" ]; then
        echo "tg: profilo '$profile': manca $f" >&2
        exit 1
    fi
done

token=$(tr -d '[:space:]' < "$token_file")
chat=$(tr -d '[:space:]' < "$chat_file")

case "$PWD" in
    "$HOME"*) where="~${PWD#"$HOME"}" ;;
    *)        where="$PWD" ;;
esac

if [ -n "$1" ]; then
    msg="$1 ($where)"
else
    msg="Plin plon! ($where)"
fi

curl -sS --fail --max-time 10 \
    --form-string "chat_id=$chat" \
    --form-string "text=$msg" \
    "https://api.telegram.org/bot$token/sendMessage" >/dev/null
