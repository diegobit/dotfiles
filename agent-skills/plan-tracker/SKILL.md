---
name: plan-tracker
description: Find and maintain a project's Markdown plan directory, status ledger, and naming conventions when locating, publishing, or updating planned work.
---

# Plan tracker

Use the repository's existing Markdown planning conventions. Use an external tracker when the user requests one.

## Find the authoritative files

Read repository instructions and existing indexes such as `docs/plans/README.md` and `docs/state/README.md`. Distinguish the plan directory (future work) from the status ledger (what is open or done).

Follow an explicitly named ledger first. Otherwise check `docs/plans/TODO.md`, an index that actually records statuses, and root `TODO.md`. Reuse the file carrying live work; avoid creating a competing ledger. If conflicting ledgers leave authority unclear, report the conflict instead of guessing.

A read-only lookup creates nothing. For requested publication with no convention, use `docs/plans/` and `docs/plans/TODO.md`.

Where the repo distinguishes requirements, current state, and plans, treat requirements as intent and verified state as the current baseline. Plans cannot override either. Preserve client requirements unless their revision was requested.

## Publish and update

Match existing naming, statuses, and archive rules. Without a convention:

- Name plans `YYYYMMDD-<slug>.md`; for multiple independently actionable units, use `YYYYMMDD-<slug>-NN-<name>.md`.
- Use a `00` index only when it makes a multi-file effort easier to navigate. Small plans can stay in one file.
- Record title, link, status, and genuine blockers in the ledger. Use `ready`, `blocked`, `wip`, and `done` for executable work; identify a specification as a specification, not a ready implementation unit.
- Update the ledger with the corresponding work change. Archive completed plans under `completed/` and repair links when no other convention exists.

Resolve links relative to their containing file and verify targets. Re-read shared indexes before editing and preserve unrelated entries. Report status based on evidence, not an old plan's claim of completion.
