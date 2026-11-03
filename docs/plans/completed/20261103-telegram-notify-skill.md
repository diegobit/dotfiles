# Telegram notifications as an on-demand skill

Status: `done`.
Depends on: none.

## Deliverable

`tg` leaves the always-loaded global instructions and becomes a skill that loads when Diego
says `telegram-notify`, or when an agent is blocked and needs him. The notification guidance
survives inside the skill; nothing pings him at the end of an ordinary run any more.

## Steps

1. Remove the `# Notifications` section from `AGENTS.md`, from the heading to end of file,
   leaving host and hardware only. No pointer line: the skill description is the discovery
   mechanism, and every harness that reads this file also loads skill descriptions.
2. Add `agent-skills/telegram-notify/SKILL.md` with front matter

   ```yaml
   name: telegram-notify
   description: Use when the user says 'telegram-notify', or when you are blocked and need the user to act (approval, credentials, a decision). Not for ordinary task completion.
   ```

   Body, in the order an agent needs it:
   - send with `tg '<message>'` once each time you yield control: at the end of the turn, or
     just before you stop to wait for the user. Never otherwise mid-run. The request covers the
     current task; "for this session" means one message at the end of every turn after that. If
     the work is delegated, the parent sends it, not the child;
   - shape `<project> <status> <message>`, one line, statuses ✅ done, ❌ error, 🙋 stopped
     for input, ⏳ turn ends while external work (CI, deploy) is still running;
   - plain language: outcome and required action, no paths, commands or internal names;
   - `tg` appends `(cwd)` itself, so the message must not repeat the path;
   - no `-p`: `tg` uses the machine's default profile. Pass `-p <profile>` only when the user
     names a channel;
   - `tg` takes one argument and does not chunk: keep it well under Telegram's 4096 characters;
   - if `tg` is missing or its secret files are absent, say so in the reply and skip the
     notification. No retries, no alternative channel.
3. Register the skill in `agent-skills/README.md`: add it to the instruction-only list (it has
   no scripts) and give it a dependency row (`tg` on `PATH`; `~/.telegram-bot-token-<profile>`
   and `~/.telegram-chat-id-<profile>`; `~/.telegram-default-profile` optional, absent means
   `dg`).
4. Publish the links with `bin/link-agent-skills.sh`. No script change is needed — it picks up
   any directory. This also writes the repo-owned symlinks under `.agents/skills`,
   `.claude/skills`, `.config/opencode/skills` and `.gemini/config/skills`, which are committed.
5. Commit only this change. `agent-skills/README.md` already carries uncommitted test-audit
   edits, so stage its hunks with `git add -p`, not `git add`. Include the plan file and the
   `TODO.md` entry. When the work is verified, move the plan to `docs/plans/completed/`, repair
   the link in `TODO.md` and mark the entry `done`.

## Deployment to every machine

For each machine with the dotfiles clone:

1. `git pull`.
2. `bin/link-agent-skills.sh --check`; run `bin/link-agent-skills.sh` if it reports missing
   links. Fresh machines get this from `install.sh`, which is macOS only.
3. On non-macOS hosts, create the `tg` command by hand and make sure `~/.local/bin` is on
   `PATH`: `ln -sf ~/dotfiles/bin/tg.sh ~/.local/bin/tg`.
4. Confirm `command -v tg` and the secret files for that host's default profile. `tg` falls back
   to `dg` when `~/.telegram-default-profile` is absent. A machine without the secrets still
   gets the skill; the skill then reports that notifications are unavailable instead of failing
   silently.

## Verification

- `bin/link-agent-skills.sh --check` passes on all seven discovery roots.
- `grep -n tg AGENTS.md` returns nothing; the file is host and hardware only.
- In a new session, "telegram-notify that the deploy finished" loads the skill and delivers one
  message to the machine's default chat with the expected shape and `(cwd)`.
- In a new session, an ordinary task that neither mentions Telegram nor blocks loads no skill
  and sends nothing.
- A task that stops for approval or a missing credential sends one message just before it
  waits, and none when it finishes afterwards.
- The `-p <profile>` override stays documented; exercise it only if a non-default channel is
  actually intended.

## Consequences

- Ordinary runs no longer notify: a long task ending, a delegated step finishing or a
  successful build stays silent unless Diego typed `telegram-notify`. T3 Code's own desktop
  notifications are unaffected. This is the intended trade.
- The one automatic path is the blocked case. It depends on the model recognising that it is
  waiting on him, and it will also fire for a clarifying question asked while he is watching.
  The explicit exclusion ("Not for ordinary task completion") is what keeps the old behaviour
  from creeping back.
- Paraphrases such as "ping me on Telegram" still do not select the skill; the literal token is
  the cheap path by design.

## Validation

Completed 2026-11-03: `bin/link-agent-skills.sh --check` passes with all 63 symlinks valid, the
skill resolves in all seven discovery roots, `AGENTS.md` contains no `tg` reference, and the
front matter parses.

Deployment did not follow the steps above: only `jacky` had a skills tree, and it has no
dotfiles clone. It received the skill by `rsync` plus absolute symlinks in `~/.claude/skills`,
`~/.config/opencode/skills` and `~/.codex/skills`. That host has no `tg` and no secrets, so the
skill stays silent there. The two spark hosts have no agent-skills tree and no skills discovery
setup, so they were skipped.

Still open: the behavioural checks (explicit trigger, blocked case, silent ordinary run) need a
fresh session.
