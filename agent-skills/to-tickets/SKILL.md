---
name: to-tickets
description: Break a spec, plan, or conversation into implementation-ready tracer-bullet plan files with explicit dependencies and verification, indexed in the project's Markdown status ledger.
---

# To Plans

Break a spec, plan, or conversation into a set of **units**: tracer-bullet vertical slices, each one its own plan file, each declaring the units that **block** it.

Load and apply the `plan-tracker` skill to find the repo's plan directory, status ledger, and naming convention.

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes a reference (a spec path, a plan file, a requirements file) as an argument, read it in full.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Unit titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching.

Look for opportunities to prefactor the code to make the implementation easier. "Make the change easy, then make the easy change."

### 3. Draft vertical slices

Break the work into **tracer bullet** units.

<vertical-slice-rules>

- Each slice cuts a narrow but COMPLETE path through every layer (schema, API, UI, tests): vertical, NOT a horizontal slice of one layer
- A completed slice is demoable or verifiable on its own
- Each slice is sized to fit in a single fresh context window
- Any prefactoring should be done first

</vertical-slice-rules>

Give each unit its **blocking edges**: the other units that must complete before it can start. A unit with no blockers can start immediately.

**Wide refactors are the exception to vertical slicing.** A **wide refactor** is one mechanical change (rename a column, retype a shared symbol) whose **blast radius** fans across the whole codebase, so a single edit breaks thousands of call sites at once and no vertical slice can land green. Don't force it into a tracer bullet; sequence it as **expand–contract**. First expand: add the new form beside the old so nothing breaks. Then migrate the call sites over in batches sized by blast radius (per package, per directory), each batch its own unit blocked by the expand, keeping CI green batch to batch because the old form still exists. Finally contract: delete the old form once no caller remains, in a unit blocked by every migrate batch. When even the batches can't stay green alone, keep the sequence but let them share an integration branch that all block a final integrate-and-verify unit; green is promised only there.

### 4. Confirm only material choices

Present the proposed breakdown as a numbered list. For each unit, show:

- **Title**: short descriptive name
- **Blocked by**: which other units (if any) must complete first
- **What it delivers**: the end-to-end behaviour this unit makes work

If the conversation has not already settled the breakdown, ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the blocking edges correct: does each unit only depend on units that genuinely gate it?
- Should any units be merged or split further?

When the requested outcome and dependency boundaries are already clear, write the plans without another approval round and report the breakdown.

### 5. Write the plan files

Write one file per unit in the discovered plan directory, named and numbered per `plan-tracker`, with blockers first. One unit per file.

Where the effort has more than about three units, also write the `-00-masterplan.md`: the index that names the destination, lists the units in order with their blocking edges, and links each to its file. This is the file you hand an orchestrator session.

Then add one line per unit to the project's status ledger, using the repo's statuses. In a new ledger, use `ready` for unblocked units and `blocked` otherwise. Compute and verify links relative to the ledger file.

Work the **frontier**: any unit whose blockers are all done. For a purely linear chain that means top to bottom.

Leave `docs/requirements/` alone. Touch `docs/state/` only when the discovered status ledger lives there and the repo's own convention says planned work is registered in it; otherwise this skill writes only plans and their ledger/index.

<plan-file-template>

# <NN>: <Unit title>

**Outcome:** the end-to-end behaviour this unit makes work and how a reviewer can observe it.

**Blocked by:** the numbers/titles of the units that gate this one, or "None (can start immediately)".

## Scope

- Exact repository paths and symbols expected to change; treat line numbers as hints and re-resolve symbols before editing.
- Explicitly excluded paths and behavior.

## Decisions and invariants

- Contracts this unit must preserve.
- Decisions already made, with links to their source when available.

## Implementation outline

The smallest contract-complete sequence. Keep design judgement in this plan; leave mechanical discovery to the implementer.

## Acceptance

- [ ] Acceptance criterion 1
- [ ] Acceptance criterion 2

## Verification

- Exact focused commands and expected signals.
- Broader regression gate proportional to the change.
- Any live, paid, deployment, or hardware gate that remains closed without renewed approval.

## Worktree safety

- Re-check branch and dirty state before editing.
- Preserve named user-owned dirty paths and all unrelated changes.

</plan-file-template>

Use exact paths and symbols when they make ownership or verification unambiguous, but tell the implementer to re-resolve them before editing. Include code only when it encodes a decision more precisely than prose can (state machine, reducer, schema, type shape); trim it to the decision-rich part.
