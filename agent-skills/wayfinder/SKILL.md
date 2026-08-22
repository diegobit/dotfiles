---
name: wayfinder
description: Plan a huge chunk of work (more than one agent session can hold) as a shared map of decision plan files under docs/plans/, and resolve them one at a time until the way to the destination is clear.
---

A loose idea has arrived, too big for one agent session, and wrapped in fog: the way from here to the **destination** isn't visible yet. Wayfinding is about finding that way, not charging at the destination. This skill charts the way as a **shared map** in the repo's `docs/plans/`, then works its **decision units** (questions whose resolution is a decision, not slices of a build to execute) one at a time until the route is clear.

The destination varies per effort, and naming it is the first act of charting: it shapes every unit. It might be a spec to hand off and iterate on, a decision to lock before planning starts, or a change made in place like a data-structure migration. The map is domain-agnostic: engineering work, course content, whatever fits the shape.

## Plan, don't do

Wayfinder is **planning** by default: each unit resolves a decision, and the map is done when the way is clear, with nothing left to decide before someone goes and does the thing. The pull to just do the work is usually the signal you've reached the edge of the map and it's time to hand off. An effort can override this in its **Notes**, carrying execution into the map itself, but absent that, produce decisions, not deliverables.

## Refer by name

Every map and unit is a file, so it has a **name**: its title. In everything the human reads (narration, the map's Decisions-so-far), refer to it by that name, never by a bare number, filename, or slug. A wall of `01, 02, 03` is illegible; names read at a glance. The number and path don't vanish; a name wraps its link, but they ride _inside_ the name, never stand in for it.

## The Map

The map is a single markdown file, `docs/plans/YYYYMMDD-<slug>-00-map.md`, the canonical artifact. Its units are sibling files, `docs/plans/YYYYMMDD-<slug>-NN-<name>.md`.

Load and apply the `plan-tracker` skill for this repo's plan conventions and status ledger.

The map is an **index**, not a store. It lists the decisions made and points at the units that hold their detail; a decision lives in exactly one place, its unit file, so the map never restates it, only gists it and links.

### The map body

The whole map at low resolution, loaded once per session. Open units live in the **Open** table; resolved ones collapse to one line under Decisions so far.

```markdown
## Destination

<what reaching the end of this map looks like: the spec, decision, or change this effort is finding its way to. One or two lines; every session orients to it before choosing a unit.>

## Notes

<domain; skills every session should consult; standing preferences for this effort>

## Open

<!-- the live units; frontier = every open unit whose blockers are all resolved and which is unclaimed -->

| # | Name | Type | Blocked by | Claimed |
|---|---|---|---|---|
| 01 | [<unit title>](YYYYMMDD-<slug>-01-<name>.md) | grilling | none | |

## Decisions so far

<!-- the index: one line per resolved unit, enough to judge relevance, then zoom the link for the detail the unit holds -->

- [<resolved unit title>](completed/YYYYMMDD-<slug>-NN-<name>.md): <one-line gist of the answer>

## Not yet specified

<!-- see "Fog of war": in-scope fog you can't unit yet; graduates as the frontier advances -->

## Out of scope

<!-- see "Out of scope": work ruled beyond the destination; resolved, never graduates -->
```

### Units

Each unit is a sibling file of the map, numbered `NN` in dependency order. Its body is the question, sized to one 100K token agent session:

```markdown
# <NN>: <Unit title>

**Type:** research | prototype | grilling | task
**Blocked by:** <unit numbers/titles, or "none">
**Claimed:** <who/when, or empty>

## Question

<the decision or investigation this unit resolves>

## Resolution

<empty until resolved>
```

A session **claims** a unit by filling its `Claimed` field and the map's Claimed column, **first**, before any work, so concurrent sessions skip it. That field _is_ the claim: an open unit with an empty Claimed is unclaimed.

Blocking is the `Blocked by` field, mirrored in the map's Open table so the frontier is readable without opening every unit. A unit is **unblocked** when every unit blocking it is resolved; the **frontier** is the open, unblocked, unclaimed units, the edge of the known.

The answer isn't part of the question; it's written into `## Resolution` (see [Work through the map](#work-through-the-map)). Assets created while resolving a unit are linked from the file, not pasted in.

## Unit Types

Every unit is either **HITL** (human in the loop, worked _with_ a human who speaks for themselves) or **AFK**, driven by the agent alone. A HITL unit only resolves through that live exchange; the agent never stands in for the human's side of it (a grilling agent that answers its own questions has broken this).

- **Research** (AFK): Reading documentation, third-party APIs, or local resources like knowledge bases to surface a fact a decision waits on. Resolved by a subagent that loads the `research` skill. Use when knowledge outside the current working directory is required.
- **Prototype** (HITL): Raise the fidelity of the discussion by making a cheap, rough, concrete artifact to react to (an outline, a rough take, a stub, or UI/logic code) by loading the `prototype` skill. Links the prototype as an asset. Use when "how should it look" or "how should it behave" is the key question.
- **Grilling** (HITL): Conversation. The default case. Load and combine the `grilling` and `domain-modeling` skills.
- **Task** (HITL or AFK): Manual work that must happen before a _decision_ can be made: nothing to decide, prototype, or research, but the discussion is blocked until it's done. Signing up for a service so its API can be judged, provisioning access, moving data so its shape can be seen. This is the one type that _does_ rather than decides, and it earns its place by unblocking a decision, not by delivering the destination. The agent drives it alone where it can (AFK); otherwise it hands the human a precise checklist (HITL). Resolved when the work is done; the answer records what was done and any resulting facts (credentials location, new URLs, row counts) later units depend on.

## Fog of war

The map is _deliberately_ incomplete: don't chart what you can't yet see. Beyond the live units lies the **fog of war**: the dim view of decisions and investigations you can tell are coming but can't yet pin down, because they hang on questions still open. Resolving a unit clears the fog ahead of it, graduating whatever's now specifiable into fresh units, one at a time, until the way to the destination is clear and no units remain.

The map's **Not yet specified** section is where that dim view is written down: the suspected question, the area to revisit later. It's the undiscovered frontier _toward_ the destination: everything here is in scope, just not sharp enough to unit. Write as loosely or as fully as the view allows; it doubles as a signpost for collaborators reading where the effort is headed.

**Fog or unit?** The test is whether you can state the question precisely now, _not_ whether you can answer it now.

- **Unit when** the question is already sharp, even if it's blocked and you can't act on it yet.
- **Not yet specified when** you can't yet phrase it that sharply. Don't pre-slice the fog into unit-sized pieces: it's coarser than a unit, and one patch may graduate into several units, or none, once the frontier reaches it.

**Not yet specified** excludes what's already decided (Decisions so far), what's already a live unit, and what's out of scope (the next section).

## Out of scope

Fog only ever gathers _toward_ the destination. The destination fixes the scope, so work beyond it is **out of scope**: it isn't fog, and it doesn't belong in **Not yet specified**. It gets its own **Out of scope** section on the map: work you've consciously ruled out of _this_ effort. Scope, not sharpness, lands it here.

Out-of-scope work never graduates (the frontier stops at the destination), so it returns only if the destination is redrawn, and then as a fresh effort, not a resumption.

Ruling something out of scope is a scoping act, not a step on the route. When a unit that already exists turns out to sit past the destination (mis-scoped in while charting, or exposed by a resolution), **retire it**: drop its row from the Open table and move its file to `docs/plans/completed/` (a retired unit is unambiguously off the frontier). Leave one line in the **Out of scope** section: the gist plus why it's out of scope, linking the retired file. It stays out of **Decisions so far**, which records the route actually walked; a scope boundary isn't a step on it.

## Invocation

Two modes. Either way, **never resolve more than one unit per session**, with the exception of research units.

### Chart the map

User invokes with a loose idea.

1. **Name the destination.** Load and combine `grilling` and `domain-modeling` to pin down what this map is finding its way to: the spec, decision, or change. The destination fixes the scope, so it's settled first.
2. **Map the frontier.** Grill again, **breadth-first** this time: fan out across the whole space rather than deep on any one thread, surfacing the open decisions and the first steps takeable now. **If this surfaces no fog** (the way to the destination is already clear, the whole journey small enough for one session), you don't need a map. Stop and ask the user how they'd like to proceed.
3. **Create the map** at `docs/plans/YYYYMMDD-<slug>-00-map.md`: Destination and Notes filled in, Open and Decisions-so-far empty, the fog sketched into **Not yet specified**.
4. **Create the unit files you can specify now**, numbered `01` upward, then wire blocking edges in a **second pass** (units need numbers before they can reference each other) and mirror them into the map's Open table. Wiring sorts them into the frontier and the blocked; everything you can't yet specify stays in the fog: the **Not yet specified** section.
5. **Fire bounded research subagents when capacity allows.** Give each `research` unit to a subagent that loads `research`; when session or concurrency limits are tight, resolve them sequentially. Capture each result as a Markdown file with a context pointer from the unit.
6. Stop: charting is one session's work; it hand-resolves nothing.

### Work through the map

User invokes with a map (a path). A unit is **optional**: without one, you pick the next decision, not the user.

1. Load the **map**: the low-res view, not every unit body.
2. Choose the unit. If the user named one, use it. Otherwise take the first frontier unit in order. **Claim it**: fill its `Claimed` field and the map's Claimed column before any work.
3. Resolve it. **Zoom as needed**: read the full body of related or resolved units on demand; load whichever installed skills the `## Notes` block names. If no more specific route applies, combine `grilling` and `domain-modeling`.
4. Record the resolution: write the answer into the unit's `## Resolution`, move the file to `docs/plans/completed/`, drop its row from the map's Open table, and **append a context pointer** to the map's Decisions-so-far.
5. Add newly-surfaced units (create-then-wire); graduate any fog the answer has made specifiable, clearing each graduated patch from **Not yet specified** so it lives only as its new unit. If the answer reveals that a unit (this one or another) sits beyond the destination, **rule it out of scope** rather than resolving it on the route. If the decision invalidates other parts of the map, update or delete those units.

The user may run unblocked units in parallel, so expect other sessions to be editing the map concurrently: re-read the map immediately before you write to it, and touch only your own unit's row.
