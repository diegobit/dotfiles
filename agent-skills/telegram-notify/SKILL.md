---
name: telegram-notify
description: Use when the user says 'telegram-notify', or when you are blocked and need the user to act (approval you are asking for, credentials, a decision). Not for ordinary task completion.
---

# Telegram notifications

Send Diego a Telegram message with `tg "<message>"`.

## When

- Asked: the user wrote `telegram-notify`. Send one message when you yield control for that
  task — at the end of the turn, or just before you stop to wait for them. If they said "for
  this session", send one at the end of every later turn too.
- Blocked: you loaded this skill yourself because the user must act. Send one 🙋 message just
  before you stop to wait, and nothing else. When they answer and you finish, send nothing.

Either way: at most one message per turn, never mid-run. A delegated child never sends; it
reports to its parent, and the parent applies these rules.

## How

- Shape: `<project> <status> <message>`, one line; `<project>` is the short repo or task name.
  - ✅ done
  - ❌ error or problem
  - 🙋 stopped to ask Diego for input
  - ⏳ turn ends while external work (CI, deploy) is still running
- Plain language: the outcome and any action needed, no file paths, commands or internal names.
- `tg` appends `(cwd)` itself, so do not repeat the path.
- No `-p`: `tg` uses the machine's default profile. Pass `-p <profile>` only when the user
  names a channel.
- Quote with double quotes (`tg "…"`) and avoid `$` and backticks in the text; single quotes
  break on apostrophes.
- `tg` takes one argument and does not chunk: keep it well under Telegram's 4096 characters.
- If `tg` is missing or its secret files are absent: on an explicit request, say so in one line;
  on the blocked path, skip it silently. No retries, no alternative channel.

Example: `dotfiles ✅ telegram-notify skill added`
