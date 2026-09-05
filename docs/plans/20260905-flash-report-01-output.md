# Flash worker report handling

Status: `done`

## Scope

Apply the output-handling findings from the audit of commit `b2c1b01`.
Keep file-backed evidence and the optional report cap. Preserve model selection,
worker invocation, lane identity, and existing exit codes.

## Implementation

1. Keep one full report at the existing workspace-scoped cache path. Remove the
   automatic `/tmp/flash/<lane>.out` copy so caller redirects have separate ownership.
2. Share report persistence and printing across result and crash paths. Count and
   read the saved file when capping; append a notice pointing to the full report.
3. Validate CLI and environment caps before launching a worker. Accept nonnegative
   decimal integers supported by the shell; zero means unlimited, the default.
4. Update the skill: explain report paths, cap semantics, unique evidence logs,
   and verification through relevant excerpts rather than loading whole logs.

## Acceptance

- A capped stdout redirect contains only the requested report lines and its notice;
  the canonical file retains the full report.
- Same-named lanes in different workspaces retain separate reports.
- Success, error, empty response, and crash runs retain exit codes 0, 1, 2, and 3;
  partial crash/error reports are saved and capped, replacing earlier reports.
- Invalid caps exit 64 before the fake CLI is invoked; flag values override the
  environment default. Zero and omitted caps print the whole report.
- Shell syntax, isolated fake-CLI regression tests, and skill validation pass.

## Validation

- `python3 agent-skills/flash-worker/scripts/test_flash.py`: all nine tests pass,
  including subcases for caps, error responses, and environment overrides.
- The regression suite rejects the original `HEAD` wrapper in an isolated copy.
- `sh -n agent-skills/flash-worker/scripts/flash.sh` and `git diff --check`: pass.
- The skill-creator `quick_validate.py` check: pass.

Tests use temporary workspaces and a fake CLI; no paid worker or live selftest
was launched. Changes are uncommitted.
