---
name: plan-tracker
description: Locate a project's Markdown plan directory, status ledger, and local conventions. Use when publishing or finding a spec or plan, or when checking what work is open, blocked, or done.
---

# Plan Tracker

Prefer the repository's Markdown files for planning and status. Use an external tracker only when the user explicitly asks for it.

## Discover the local convention

Separate two things that may live in different files:

- The **plan directory** holds forward-looking work packages.
- The **status ledger** says what is open, blocked, in progress, or done.

Read the repository instructions and the small index files that define those roles: `AGENTS.md`, `CLAUDE.md`, `docs/plans/README.md`, and `docs/state/README.md` when present. Then inspect likely ledger files in this order:

1. The exact file named by `docs/state/README.md` (often `docs/state/project-state.md`). A directory is never itself a ledger.
2. `docs/plans/TODO.md`.
3. `docs/plans/README.md`, only when it actually carries live statuses or checkboxes.
4. `TODO.md` at the repo root.

Use the file that already carries live work. Treat other candidates as indexes or context. Never invent a second ledger beside an existing one.

For a read-only lookup, report that no ledger exists without creating one. When the user asked to publish work and no convention exists, create `docs/plans/TODO.md` and report that choice.

## The three folders

Where a repo uses this split, respect it. It is a precedence order, not just a layout:

| folder | holds | authority |
|---|---|---|
| `docs/requirements/` | business intent, client-provided artifacts | highest: never rewrite unasked |
| `docs/state/` | what is actually true now, including status when its README says so | beats plans |
| `docs/plans/` | forward-looking execution | lowest: non-authoritative, archive when stale |

A plan that contradicts requirements or state is wrong; fix the plan.

## Plan file naming

Match existing names first. For a repo with no convention, use `docs/plans/YYYYMMDD-<slug>-NN-<name>.md`.

- `NN` numbers the units in dependency order, blockers first, starting `01`.
- `NN` = `00` names the masterplan: the index for a multi-unit effort.
- One unit per file. Never a single combined file.
- Follow the repo's archive convention. When none exists, move completed plans to `docs/plans/completed/` and update their ledger links.

## Status ledger template

```markdown
# TODO

Status: `ready` (unblocked) · `blocked` · `wip` · `done`

## <Effort name> — [masterplan](<relative-path-from-this-ledger-to-the-masterplan>)

- [ ] `ready` **01 <unit title>** — [plan](<relative-path-from-this-ledger>) — blocked by: none
- [ ] `blocked` **02 <unit title>** — [plan](<relative-path-from-this-ledger>) — blocked by: 01
- [x] `done` **00 <unit title>** — [plan](<relative-path-from-this-ledger>)
```

Compute every link relative to the ledger file's directory and verify that it resolves. Keep one line per unit. The line carries title, status, link, and blocking edges; everything else lives in the plan file it points at.

## Working the frontier

The **frontier** is every unit whose blockers are all `done`. Those are the units that can start now. A linear chain means the frontier is one unit; a wide fan-out means several can run in parallel.

Update the ledger in the same change set as the status change. Commit only when the user has separately authorized a commit. A ledger that lags the repo is worse than no ledger, because it is believed.
