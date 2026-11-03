---
name: telegram-notify
description: Use when the user says 'telegram-notify', or when you are blocked and need the user to act (approval, credentials, a decision). Not for ordinary task completion.
---

# Telegram notifications

Send Diego a Telegram message with `tg '<message>'`.

## When

- Once each time you yield control: at the end of the turn, or just before you stop to wait
  for the user. Never otherwise mid-run.
- A `telegram-notify` request covers the current task. "For this session" means one message at
  the end of every turn after that.
- If the work is delegated, the parent sends it, not the child.

## How

- Shape: `<project> <status> <message>`, one line.
  - ✅ done
  - ❌ error or problem
  - 🙋 stopped to ask Diego for input
  - ⏳ turn ends while external work (CI, deploy) is still running
- Plain language: the outcome and any action needed, no file paths, commands or internal names.
- `tg` appends `(cwd)` itself, so do not repeat the path.
- No `-p`: `tg` uses the machine's default profile. Pass `-p <profile>` only when the user
  names a channel.
- `tg` takes one argument and does not chunk: keep it well under Telegram's 4096 characters.
- If `tg` is missing or its secret files are absent, say so in the reply and skip the
  notification. No retries, no alternative channel.

Example: `dotfiles ✅ telegram-notify skill added`
