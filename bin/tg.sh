#!/bin/sh
# Send a Telegram message. Usage: tg [-p <profilo>] '<text_message>'
#
# I segreti stanno in ~/.telegram-bot-token-<profilo> e ~/.telegram-chat-id-<profilo>.
#   dg   -> notifiche personali (chat privata)
#   ait  -> canale "AIT Alerts"
# Il profilo di default è "dg", salvo che ~/.telegram-default-profile dica altro
# (sul Jetson contiene "ait": lì tutto è allarme di automazione).
#
# Versione shell-agnostic della funzione tg in ~/.config/fish/config.fish:
# serve a cron, agli script e alle shell non interattive.

set -e

profile=""
case "$1" in
    -p|--profile) profile=$2; shift 2 ;;
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
