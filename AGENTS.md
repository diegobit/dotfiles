# Environment

Local dev platform: macOS, Apple Silicon; Fish shell.

# Notifications

- The `tg` command sends Diego a notification on his phone via Telegram: `tg '<text_message>'`. It's a standalone script at `~/.local/bin/tg`, runnable from any shell, including non-interactive ones (cron, scripts).
- `-p ait '<text_message>'` posts to the "AIT Alerts" channel instead of Diego's private chat (default profile: `dg`).
