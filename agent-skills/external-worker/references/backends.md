# Backend maintenance

Read this when a launcher fails, session resume behaves unexpectedly, read-only
behavior changes, or an installed CLI is updated. The public skill chooses an
executor; command construction and stream decoding live in `scripts/external-worker.sh`.

## Invariants carried from the original wrappers

These details were recorded by the original worker wrappers at `9c5d2b2`. Recheck
them behaviorally when upgrading a CLI; initialization metadata alone does not
prove file tools resolve the right workspace.

| Executor | Command and model | Workspace | Read-only |
|---|---|---|---|
| gemini | `agy`, Gemini 3.8 Flash, high effort | `--add-dir` registers the file-tool root; cwd alone is insufficient | `--mode plan` **and** `--dangerously-skip-permissions` |
| claude | `claude`, Opus 5, high effort | process cwd | `--permission-mode plan` **without** `--dangerously-skip-permissions` |
| cursor | `agent`, Grok 4.6 High | `--workspace` plus matching cwd | `--mode ask --force` |
| codex | `codex exec`, GPT-6-Astra, medium effort | `-C` plus `--skip-git-repo-check` (else Codex roots at the enclosing Git repo) | `-s read-only` on start, `-c sandbox_mode=read-only` on resume |
| opencode | `opencode run`, DeepSeek V4.1 Flash, variant `max` | `--dir` plus matching cwd | `--agent plan` (edit denied; bash still allowed) |

Claude's skip-permissions flag overrides its plan mode and re-enables writes.
Gemini needs the skip flag even in plan mode to avoid auto-denying reads. Cursor
uses ask mode: with `--plan --force`, the model can call `switchMode` to enter agent
mode and edit files (reproduced during migration). Ask mode passed the same live
read-only continuation test on CLI 2026.09.02-c22c1a3. Test both
readability and attempted writes in a throwaway directory before claiming safety.
These are harness permission modes, not operating-system filesystem sandboxes.

Codex is the exception on two points. Its read-only mode is a real OS sandbox
(`-s read-only`), not just a harness permission mode. Write mode uses
`--dangerously-bypass-approvals-and-sandbox`, matching the other executors' full
unattended authority. `codex exec resume` rejects `-s/--sandbox` and `-C`, so the
read-only sandbox is re-applied on continuation as `-c sandbox_mode=read-only`
and the workspace is only the process cwd.

OpenCode has no sandbox flag and no dedicated read-only switch. Read-only uses the
built-in `plan` agent, whose permission rules deny the `edit` tool; write uses the
`build` agent with `--auto` to auto-approve anything not explicitly denied. Plan is
the weakest read-only guarantee of the five because `bash` remains allowed, so a
model can still modify files through a shell redirect. Treat it like Claude's plan
mode (a harness permission mode), and verify attempted writes behaviorally rather
than assuming the sandbox blocks them.

Gemini requires effort with its model alias and a long `--print-timeout` on both
start and resume. Claude stream JSON requires `--verbose`. Cursor's high effort
is part of its model ID rather than an effort flag; its unattended command also
uses trust, disabled sandbox, and MCP consent flags from the original wrapper.

## Sessions and streams

Resume uses explicit saved session IDs. Gemini's implicit continue and Cursor's
implicit continue can select another workspace's conversation; Claude's implicit
continue can select another session in the same workspace.

- Gemini: `conversation_id` from initialization; `--conversation` for resume;
  final `.event == "result"` carries `.result.status` and `.result.response`.
  Partial output is reconstructed from `step_update.text_delta`.
- Claude: generate a UUID and pass `--session-id` on start; use `--resume` without
  `--fork-session` or a new model/effort on continuation.
- Cursor: initialization carries `session_id`; use `--resume` without a new model.
- Codex: the first event is `thread.started` with `thread_id`; resume with
  `codex exec resume <id>`. `.type == "turn.completed"` marks success and
  `.type == "turn.failed"` carries `.error.message`; agent text is the
  `item.completed` items of type `agent_message`, and tool progress uses
  `command_execution`/`file_change` items. Codex does **not** persist model or
  reasoning effort in the recorded session, so both must be re-passed on resume
  (`-m` and `-c model_reasoning_effort=`) or it silently falls back to the user's
  `config.toml` default.
- OpenCode: every event carries `sessionID` at the top level (`-s` resumes it).
  Success is `.type == "step_finish"` with `.part.reason == "stop"`; a fatal failure
  is `.type == "error"` with `.error.data.message`. Assistant text arrives as
  `text` parts, and the report is the concatenation of the text parts sharing the
  last `messageID`. Tool progress is `tool_use` parts (`read`, `bash`, `edit`, …).
  Model and variant are re-specified on resume. A `step_finish`/`stop` is treated as
  success even if an earlier `error` event appeared, so mid-run errors do not
  override a completed turn.
- Claude and Cursor: `.type == "result"` carries subtype, is_error, and result.
  Partial output comes from assistant text messages; tool progress schemas differ.

Always preserve raw JSONL. Use `printf` or files, not `echo` on captured JSON with
escaped newlines. A result marked successful can still describe a blocked task;
the report, exit status, evidence, and diff are separate acceptance checks.

## Configuration and diagnosis

Only the selected CLI must be installed and authenticated. The launcher also
requires Bash, jq, and the macOS command-line utilities used for process and state
handling. `EW_CLAUDE_BUDGET` optionally caps Claude spend in USD. Executable overrides
`EW_GEMINI_BIN`, `EW_CLAUDE_BIN`, `EW_CURSOR_BIN`, `EW_CODEX_BIN`, and
`EW_OPENCODE_BIN` support offline testing.
Production model choices are fixed in the command builders. A provider failure
does not trigger an automatic fallback to a different provider or model.

Peek exposes state paths and recent tool progress without calling the provider.
Inspect stderr and relevant raw-stream lines when the final report is absent.
Legacy worker caches remain untouched; this launcher starts its own session state.

An existing lock is never stolen automatically: missing owner metadata can mean
a process is still starting, and removing it could admit two workers. For recovery
after an uncatchable termination, inspect `lock/wrapper.pid`, `lock/worker.pid`,
and their `*.lstart` values against `ps -p <pid> -o lstart=,command=`. Confirm both
original processes have exited and stop concurrent launch attempts before removing
that identity's lock directory. A missing or mismatched start time is insufficient
evidence to signal a PID; it may now belong to another process.

## Verification

The offline suite checks argv, session/mode inheritance, reports, caps, errors,
isolation, and lifecycle behavior using fake CLIs. Live selftests exercise file
reachability, attempted writes in read-only mode, a real write, and context-preserving
resume. Installed-version and migration validation results are recorded in the
[consolidation validation record](../../../docs/plans/20260905-external-worker-00-design.md#validation-record).
