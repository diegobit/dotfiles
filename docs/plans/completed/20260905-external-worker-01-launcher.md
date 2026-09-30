# Shared external-worker launcher

Status: `done`
Depends on: none.
Design: [external-worker consolidation](20260905-external-worker-00-design.md).

## Deliverable

Create `agent-skills/external-worker/scripts/external-worker.sh` and an offline
Python standard-library regression suite in the same directory. Port the proven
command details from the existing wrappers into the provider functions defined by
the design. Leave the existing skills available until package 2 completes.

## Steps

1. Implement parsing and default executor selection; workspace/executor identity;
   atomic start/resume exclusion; stored session and read-only mode; and local
   peek/kill operations. Validate arguments before provider launch or state reset.
2. Port the three command builders and stream extractors. Centralize process
   lifecycle and normalize results into the shared exit-code rules.
3. Move Flash's canonical report saving and spill behavior into the common flow.
   Salvage partial output on worker errors, crashes, and cancellation.
4. Port selftest operations into one shared test sequence with provider-specific
   model/flag details hidden internally. Label any cheaper test-model substitution;
   it cannot establish production-model availability.

## Verification and acceptance

Use fake executables that record argv/cwd and emit controlled streams. Adapt
`flash-worker/scripts/test_flash.py` to parameterize the common behavior across
all three executors. Cover:

- Omitted executor selects Gemini 3.8 Flash/high; explicit names select the right
  CLI; invalid names, lane flags, conflicting actions, and invalid caps fail early.
- Arbitrary task text, spaces in workspace paths, and stdin packets survive argv
  construction without evaluation.
- Read-only argv matches each provider's distinct rules. Continuation preserves
  stored mode/session and excludes new-session model flags.
- Capped/uncapped stdout, separate captures, canonical full reports, empty output,
  provider errors, nonzero process exits, missing results, and partial recovery.
- Workspace/executor isolation; simultaneous starts cannot both acquire the same
  identity; rejected starts do not truncate reports or replace session IDs.
- Resume never targets another executor or a stale ID from a failed new launch.
- Peek and kill work without provider binaries; cancellation preserves partial
  output; lock cleanup and stale process metadata do not affect another worker.

Run Bash syntax checking and the offline suite. Run live reachability, read-only,
write, and resume checks in throwaway workspaces for the three installed CLIs
before completing migration. Record failures as remaining acceptance work rather
than weakening the shared contract or quietly falling back to another provider.

Update the ledger when complete. This package is complete when its checks pass;
removing old discovery entries belongs to package 2.

Validation completed 2026-09-05; see the [validation record](20260905-external-worker-00-design.md#validation-record).
