# Host System & Hardware

- OS: macOS / Apple Silicon arm64
- Shell: Fish interactive, Bash for scripts
- CPU: Apple M4 Max
- GPU/NPU: Apple integrated GPU + Neural Engine, no CUDA

# Notifications

- `tg '<text_message>'` sends Diego a Telegram notification. Send it when an execution
  yields control: a long run ending, a stop to ask Diego for input, or a delegated step
  finishing while the parent work continues. Never mid-run.
- Write for the user, not about the implementation: plain language, no file paths,
  commands, or internal names. State the high-level outcome and any action required
  from Diego.
- Message shape: `<project> <status> <message>`, one line (`<project>` = short repo or
  task name).
  - ✅ done
  - ❌ error or problem
  - ❓ stopped intentionally to ask Diego for input
  - 🔄 intermediate step done, or waiting on external work — subagents use this, never ✅

