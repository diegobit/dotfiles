# Backend maintenance

Read this when a launcher fails, session resume behaves unexpectedly, read-only
behavior changes, or an installed CLI is updated. The public skill chooses an
executor; command construction and stream decoding live in `scripts/delegate.sh`.

## Invariants carried from the original wrappers

These details were recorded by the original worker wrappers at `9c5d2b2`. Recheck
them behaviorally when upgrading a CLI; initialization metadata alone does not
prove file tools resolve the right workspace.

| Executor | Command and model | Default effort | Workspace | Read-only |
|---|---|---|---|---|
| gemini | `agy`, Gemini 3.8 Flash | `high` (`--effort`) | `--add-dir` registers the file-tool root; cwd alone is insufficient | `--mode plan` **and** `--dangerously-skip-permissions` |
| claude | `claude`, Opus 5.5 | `high` (`--effort`) | process cwd | `--permission-mode plan` **without** `--dangerously-skip-permissions` |
| cursor | `agent`, Grok 4.7 High | in the model ID (`-high`, `-high-fast`) | `--workspace` plus matching cwd | `--mode ask --force` |
| codex | `codex exec`, GPT-6-Astra (default) or Sol (`-m`) | `medium` (`-c model_reasoning_effort=`) | `-C` plus `--skip-git-repo-check` (else Codex roots at the enclosing Git repo) | `-s read-only` on start, `-c sandbox_mode=read-only` on resume |
| opencode | `opencode run`, DeepSeek V4.1 Flash | `max` (variant) | `--dir` plus matching cwd | `--agent plan` (edit denied; bash still allowed) |

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

Gemini requires a long `--print-timeout` on both start and resume; `--effort` is
passed on start only. Claude stream JSON requires `--verbose`. Cursor's effort is
part of its model ID rather than an effort flag; `--effort` rewrites the
`-<level>[-fast]` suffix, and a model without a recognised suffix is rejected with
exit 64. Its unattended command also uses trust, disabled sandbox, and MCP consent
flags from the original wrapper.

## Effort

`--effort LEVEL` is validated per executor before the CLI runs: gemini
`low|medium|high|max`, claude `low|medium|high|xhigh|max`, codex
`low|medium|high|xhigh`, cursor `low|medium|high|xhigh|max`, opencode any
provider variant (for example `high`, `max`, `minimal`). `extra-high`/`x-high`
normalize to `xhigh`; an invalid value exits 64. Defaults come from
`EW_GEMINI_EFFORT`, `EW_CLAUDE_EFFORT`, `EW_CODEX_EFFORT`, and
`EW_OPENCODE_VARIANT`. The chosen level is stored in `$state/effort` beside
`$state/model` and shown by peek. Codex and opencode re-pass it on resume and
accept an override; gemini, claude, and cursor cannot change model or effort on
resume, so a repeated identical value is accepted and a different one (or
`-c -m` for a different model) exits 64 and requires a fresh run.

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
  `config.toml` default. `delegate.sh` persists the chosen model in `$state/model`
  and effort in `$state/effort` so continuations keep the selection unless
  explicitly changed with `-m` or `--effort`.
- OpenCode: every event carries `sessionID` at the top level (`-s` resumes it).
  Success is `.type == "step_finish"` with `.part.reason == "stop"`; a fatal failure
  is `.type == "error"` with `.error.data.message`. Assistant text arrives as
  `text` parts, and the report is the concatenation of the text parts sharing the
  last `messageID`. Tool progress is `tool_use` parts (`read`, `bash`, `edit`, …).
  Model and variant are re-specified on resume from `$state/model`/`$state/effort`
  and may be overridden. A `step_finish`/`stop` is treated as
  success even if an earlier `error` event appeared, so mid-run errors do not
  override a completed turn.
- Claude and Cursor: `.type == "result"` carries subtype, is_error, and result.
  Partial output comes from assistant text messages; tool progress schemas differ.

Always preserve raw JSONL. Use `printf` or files, not `echo` on captured JSON with
escaped newlines. A result marked successful can still describe a blocked task;
the report, exit status, evidence, and diff are separate acceptance checks.

## Configuration and diagnosis

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
