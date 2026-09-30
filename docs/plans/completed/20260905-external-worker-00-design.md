# External worker consolidation

Status: `done`. Implemented and validated on 2026-09-05; changes are uncommitted.

## Outcome and scope

Replace `flash-worker`, `claude-worker`, and `cursor-worker` with one discoverable
`external-worker` skill and one launcher. The orchestrator supplies a task and
optionally an executor name: `gemini`, `claude`, or `cursor`. Omission always means
`gemini`, using Gemini 3.8 Flash at high effort through `agy`.

Keep packet guidance, evidence handling, report persistence, capping, lifecycle,
and acceptance rules in one place. Provider command flags, model IDs, stream
formats, and session identifiers stay inside the launcher or its troubleshooting
reference. The skill exposes executor names rather than model configuration.

Source baseline: the three worker scripts and skills at commit `9c5d2b2`, which
includes the verified Flash report fixes. Provider behavior below describes the
existing wrappers; implementation must validate the port against installed CLIs.

## Public interface

```text
external-worker [--executor gemini|claude|cursor] [-r] [-d DIR] [--spill N] "task"
external-worker [--executor gemini|claude|cursor] -c [-d DIR] [--spill N] "correction"
external-worker [--executor gemini|claude|cursor] -p [-d DIR]
external-worker [--executor gemini|claude|cursor] -k [-d DIR]
external-worker [--executor gemini|claude|cursor] --selftest
```

The actual entrypoint is `agent-skills/external-worker/scripts/external-worker.sh`.
An `EW` shell variable can hold that path, following the existing skills' examples.
No new global command installation is required. `-e` abbreviates `--executor`.
Task text may come from arguments or stdin. Options precede task text; `--`
permits a task beginning with a hyphen.

- Executor defaults to `gemini` on every action, including continue, peek, and kill.
  There is no automatic provider selection, provider fallback, or model argument.
- `-d` defaults to the current directory. Use the same workspace and executor for
  later actions. For example, `-e claude -c` resumes Claude; plain `-c` resumes Gemini.
- `-r` starts a read-only worker. Continuation inherits the stored permission mode;
  omitting `-r` must never promote an existing read-only session to write mode.
  Mode changes require a fresh run. A contradictory `-r` on a write continuation
  is rejected with an explanation.
- `--spill N` and `EW_SPILL_LINES` retain the Flash behavior: nonnegative decimal
  integer, zero/unset means unlimited, CLI overrides environment, and capped
  output includes a path notice. Apply it to every executor and failure path.
- Reject unknown executors, `-n`/`--lane`, contradictory actions, and invalid
  argument values before launching any CLI.

## Worker identity and concurrency

Identity is `(canonical workspace, executor)`. There is no named lane or run ID
for the orchestrator to choose. One invocation per identity can be active; both
fresh starts and continuations reject an already active identity before touching
its session or output files. Use an atomic lock to enforce this under simultaneous
starts, rather than only checking a PID file.

Implementation decision: stale or incompletely initialized locks are retained and
reported for explicit recovery. Automatic removal reproduced a race in which two
launchers entered the same identity when the first paused before publishing its
PID. The regression suite injects that pause. Normal exit/cancellation releases
the owner's lock; recovery instructions cover uncatchable termination.

Different executors can run concurrently in the same workspace when their file
ownership is disjoint. Multiple workers using the same executor need separate
workspaces/worktrees or sequential execution. This intentionally replaces the
old same-workspace, same-provider named-lane concurrency with a simpler interface.

Continue uses the explicitly stored provider session ID, never the provider's
implicit "latest conversation" command. A new run clears any old session identity
before launch so an initialization failure cannot leave an unrelated resumable ID.

## Implementation shape

Use one Bash launcher compatible with the host's system Bash, `jq`, and existing
macOS utilities. Bash arrays hold argv without `eval` or shell command strings.
Keep the initial implementation in one script: provider-specific functions and
small `case` branches are sufficient for these three backends.

One shared flow owns parsing, workspace resolution, locking, state paths, process
launch/wait/kill, session persistence, peek layout, output saving, cap validation,
report printing, diagnostics, and exit-code selection. Provider code supplies:

1. An argv array and any provider-specific session initialization.
2. Extraction of the session ID, final response/status, partial text, and tool
   progress from that CLI's raw stream.

Normalize final data to result-present, success/error, body, and error detail.
Normalize session/progress information only as needed by the common flow; retain
raw streams for diagnosis. Claude and Cursor share assistant-text extraction and
result parsing where their schemas coincide. A provider branch must not contain
its own cache layout, cap implementation, or lifecycle loop.

Do not retain three old full wrappers behind a dispatcher: that would preserve
the duplication this change is meant to remove. No plugin registry or configurable
backend schema is needed.

## Provider details to preserve

| Executor | Existing model and launch behavior | Read-only behavior | Session behavior |
|---|---|---|---|
| `gemini` | `agy`, `gemini-3.8-flash`, `--effort high`, `--add-dir`, stream JSON, long explicit print timeout on start and resume | `--mode plan` together with `--dangerously-skip-permissions` | Extract `conversation_id`; resume with `--conversation` |
| `claude` | `claude`, `claude-opus-5`, high effort, workspace as cwd, stream JSON with `--verbose` | `--permission-mode plan` without skip-permissions; write mode uses skip-permissions | Generate UUID on start with `--session-id`; resume with `--resume`, without re-sending model/effort |
| `cursor` | `agent`, `cursor-grok-4.6-high`, `--workspace` and matching cwd, `--force --trust --sandbox disabled --approve-mcps`, stream JSON | Use `--mode ask --force`; plan mode allowed a live `switchMode` escape during migration | Extract `session_id`; resume with `--resume`, without re-sending model |

The common launcher may set cwd for all three; Gemini still requires `--add-dir`.
Read-only flags are provider-specific: applying Claude's skip flag in plan mode
would change the permission boundary. Tests must inspect argv, not just reports.

Keep fixed production models in the command builders. Preserve the optional Claude
spend limit as `EW_CLAUDE_BUDGET`, documented in troubleshooting rather than the
normal task flow. Use explicit executable overrides such as `EW_GEMINI_BIN`,
`EW_CLAUDE_BIN`, and `EW_CURSOR_BIN` for offline tests. Do not carry forward model
override/fallback advice into the orchestrator's interface. Missing CLI/auth/model
errors identify the selected executor and never silently select another one.

## State, reports, and failures

Use `${XDG_CACHE_HOME:-$HOME/.cache}/external-worker/<workspace-hash>/<executor>/`
for raw stream, stderr, session/mode metadata, process/lock metadata, and one
canonical `report.out`. Each completed invocation replaces that identity's report;
there is no global `/tmp` copy. Peek shows whether the report is from a previous
completed invocation while a new invocation is active.

The shared saver writes the full response or salvaged partial text before printing
it, applies the cap from the saved file, and handles missing-result crashes too.
Caller stdout captures remain separate. Evidence logs use unique directories under
`/tmp/external-worker/`; the shared packet requests command, exit code, full-log
path, and essential verbatim excerpts. A citation alone never verifies a claim.

Keep the existing exit-code categories: `0` successful transport with nonempty
output, `1` explicit worker error/cancellation or nonzero CLI exit with a result,
`2` successful transport with empty/whitespace output, `3` missing result/crash,
`64` invalid usage. A successful result paired with a nonzero CLI exit is an error
for Gemini too, matching the existing Claude/Cursor treatment. A requested kill
should let the runner save partial output and exit `1`; the separate successful
kill command returns `0`. Signal cleanup releases only the invocation's own lock.

Peek and kill consult local state without requiring an installed/authenticated CLI.
Store the wrapper and worker process identities needed to avoid signaling unrelated
processes from stale metadata. Test interruption and stale-lock handling before
claiming lifecycle equivalence.

## Skill and discovery migration

Publish one `SKILL.md` with one packet and one acceptance gate. Include `DECISIONS`
for any executor when it makes judgment calls; the packet defines its authority.
The only executor choice in normal examples is `-e claude` or `-e cursor`; default
examples omit it. Keep permission/model/stream quirks in a single troubleshooting
reference linked from the skill.

Replace the three README dependency rows with `external-worker`: `jq`, macOS
utilities, and only the selected authenticated CLI are required. Remove the old
skill directories after tests pass and discovery points to the replacement.
Do not keep compatibility skills or duplicate launchers. Old direct script calls
must be updated; old caches remain untouched and are not imported for resume.

`bin/link-agent-skills.sh` creates links for existing skill directories, but neither
removes nor detects links for removed skills. Migration must explicitly remove only
the old worker symlinks that point into this repository, then run the linker for
the new skill. Cover its four repository discovery roots and three user roots.
Verify unrelated files/links remain intact. Keep historical completed plans as
historical records rather than rewriting their old script paths.

## Work packages and completion

1. [Shared launcher and contract tests](20260905-external-worker-01-launcher.md).
2. [Unified skill and discovery migration](20260905-external-worker-02-migration.md),
   after package 1.

Done means all three executors use the same report/lifecycle implementation,
Gemini is the default, no public lane exists, offline tests cover provider flags
and failure paths, and all discovery roots expose only `external-worker` for this
capability. Run explicit live selftests in throwaway workspaces during implementation
to verify read-only behavior and session resume; fake streams cannot prove harness
permission enforcement. Record installed versions/models and distinguish live checks
from offline coverage. No paid workers are needed to write this plan.


## Validation record

- `python3 agent-skills/external-worker/scripts/test_external_worker.py`: **43 tests
  passed**, including subcases across providers. Full output:
  `/tmp/external-worker-final-offline.log`.
- Bash syntax checks for the launcher and installer, ShellCheck at warning severity
  for the launcher, the skill-creator validator, and `git diff --check`: passed.
- Live production-model selftests passed for Gemini (`agy` 1.1.27), Claude
  (Claude Code 2.1.261, reported model `claude-opus-5`), and Cursor
  (2026.09.02-c22c1a3, reported model Cursor Grok 4.6 High). They exercised actual
  file reads, attempted writes on a read-only continuation without repeating `-r`,
  a new writable session, and a resumed session recalling a unique prior-turn token.
  Logs: `/tmp/external-worker-gemini-live.log`,
  `/tmp/external-worker-claude-live.log`,
  `/tmp/external-worker-cursor-final-live.log`.
- The original Cursor plan/force combination failed the attempted-write test:
  its stream showed `switchModeToolCall` to agent mode followed by `editToolCall`.
  Ask/force passed the same test twice, including from the final launcher. Plan mode
  without force blocked writes but returned an incomplete report. Cursor auto-updated
  during initial testing; subsequent Cursor tests pinned the installed executable
  path to version 2026.09.02-c22c1a3. Its read-only builder now uses ask mode.
- A delayed lock-publication probe reproduced two simultaneous launches in the
  worker's initial draft. The final test injects the same pause and asserts only one
  CLI starts. Stale locks are retained for explicit recovery; mode/session metadata
  is read only after locking. Missing saved permission mode refuses continuation.
- Installer retirement logic tested with owned links, a personal link, and a regular
  directory in an isolated fixture: only the owned retired link was removed; check
  mode detected it beforehand and rerunning was clean.
- `bin/link-agent-skills.sh --check`: passed after migration. All seven replacement
  links resolve, all 21 retired links are absent, and a before/after snapshot verified
  all 125 unrelated discovery entries were preserved. Logs:
  `/tmp/external-worker-discovery-migration.log`,
  `/tmp/external-worker-discovery-after.log`.

- Codex executor added 2026-09-11 (`codex exec`, GPT-6-Astra at medium effort). It
  discovers `thread_id` from `thread.started`, treats `turn.completed`/`turn.failed`
  as its result event, and re-specifies model and effort on resume because the
  recorded session does not persist them. Offline suite extended to codex argv, mode
  inheritance, and stream parsing (**44 tests passed**). Live selftest passed against
  `codex-cli 0.154.0` (workspace read, blocked write on read-only continuation,
  writable run, and context-preserving resume).

- OpenCode executor added 2026-09-11 (`opencode run`, DeepSeek V4.1 Flash at variant
  `max`). Session comes from the top-level `sessionID`; success is `step_finish`/
  `stop` and failure is a top-level `error`, with the report assembled from the
  final assistant message's text parts. Read-only uses the built-in `plan` agent
  (edit denied; bash remains allowed, so it is the weakest read-only guarantee of
  the five) and write uses `build` with `--auto`. Offline suite extended to opencode
  argv, mode inheritance, and stream parsing (**45 tests passed**). Live selftest
  passed against opencode 1.18.30 (workspace read, blocked edit on read-only
  continuation, writable run, and context-preserving resume).

The installer now knows the three retired skill names and removes only links with
its exact expected target once their source directories are absent. This makes the
migration repeatable on existing checkouts; it does not prune arbitrary old skills.
The three old wrappers/skills are removed, active README dependencies are consolidated,
legacy caches and historical plans remain, and unrelated user configuration edits
were left untouched.
