---
name: plan-work
description: Explicitly requested synthesis of a conversation into a specification or decomposition of agreed work into implementation plans. Replaces to-spec and to-tickets. Select when the user requests plan-work by name.
---

# Plan work

Load and apply plan-tracker to locate the repository's plan directory, ledger, and conventions. Use the requested mode; produce both only when asked for both. Planning does not itself request implementation.

## Synthesize a specification

Turn settled conversation and relevant repository evidence into a spec. Preserve agreed decisions; record unresolved choices and their implementation impact instead of inventing answers or restarting the interview.

Cover the problem, intended behavior, scope, important failure paths, agreed design decisions, and acceptance/verification. Use the structure the work needs; user-story phrasing is optional. Cite requirements and decisions rather than copying them into competing sources of truth.

Include paths, symbols, or small code fragments when they make a decision precise; tell the implementer to re-resolve them. Prefer existing test seams appropriate to the behavior. Record material test decisions that remain open.

Publish in the plan directory and register as a specification according to local conventions, not automatically as ready implementation work.

## Create implementation plans

Translate agreed scope into independently verifiable units with genuine dependencies. Prefer end-to-end slices when they can land coherently. For changes that cannot land that way, use the smallest safe sequence, such as expand, migrate, contract.

Each unit needs:

- the observable outcome and scope;
- decisions and contracts it must preserve;
- blockers, if any;
- enough implementation direction to carry settled decisions forward;
- acceptance criteria and focused verification commands or signals grounded in the repo.

Match file granularity to the work. A small effort can use one plan; separate files help when units have distinct owners or execution boundaries. Add an index when useful and register dependencies in the existing ledger.

Proceed with settled choices. Ask only about unresolved decisions that materially affect the breakdown; do not insert an approval round for an already clear request. Respect authorization already given, and identify any actual external access or irreversible action needed later.

## Verify the handoff

Check that every requested behavior is covered, dependencies are consistent, references resolve, and open decisions are visible. Leave the source requirements and unrelated work unchanged. Report what was written and any remaining decision that prevents implementation.
