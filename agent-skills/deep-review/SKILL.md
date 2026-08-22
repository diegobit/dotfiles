---
name: deep-review
description: "Review a branch, PR, or worktree along three independent axes: Standards, Spec, and Quality (the simplest behavior-preserving implementation). Uses separate review agents when available and reports the axes side by side."
---

Three-axis review of a branch comparison or the current worktree change set:

- **Standards**: does the code conform to this repo's documented coding standards?
- **Spec**: does the code faithfully implement the originating plan / spec?
- **Quality**: is this the simplest thing that works, and does it reuse what already exists?

Run the axes as **independent review lanes** so their standards do not pollute each other. Use subagents when available; run them sequentially when concurrency or session limits are tight.

## Process

### 1. Pin the fixed point

Use the fixed point the user supplies. For "current changes" or work-in-progress with no ref, use `HEAD` and include staged, unstaged, and untracked files. For a branch or PR with no ref, discover the default branch and use its merge-base. Ask only when neither intent can be inferred safely.

Capture the comparison once. For a branch use `git diff <fixed-point>...HEAD` plus `git log <fixed-point>..HEAD --oneline`. For worktree changes use `git diff HEAD`, `git diff --cached`, and the full contents of relevant untracked files from `git status --short`.

Before going further, confirm any fixed point resolves and the total change set is non-empty. A bad ref or empty change set should fail here, not inside review lanes.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. A path the user passed as an argument.
2. Plan-file references in the commit messages or branch name (`20260803-fallback-recovery-02-...`), resolved against `docs/plans/` and `docs/plans/completed/`.
3. The project's status ledger: load `plan-tracker` to find it, then take the plan linked from the line covering this work.
4. A spec under `docs/requirements/`, `docs/`, or `specs/` matching the branch name or feature.
5. If nothing is found, ask the user where the spec is. If they say there isn't one, the **Spec** sub-agent will skip and report "no spec available".

### 3. Identify the standards sources

Anything in the repo that documents how code should be written, such as `CODING_STANDARDS.md` or `CONTRIBUTING.md`.

On top of whatever the repo documents, the Standards axis always carries the **smell baseline** below: a fixed set of Fowler code smells (_Refactoring_, ch.3) that applies even when a repo documents nothing. Two rules bind it:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"), never a hard violation. Like any standard here, skip anything tooling already enforces.

Each smell reads *what it is* → *how to fix*; match it against the diff:

- **Mysterious Name**: a function, variable, or type whose name doesn't reveal what it does or holds. → rename it; if no honest name comes, the design's murky.
- **Duplicated Code**: the same logic shape appears in more than one hunk or file in the change. → extract the shared shape, call it from both.
- **Feature Envy**: a method that reaches into another object's data more than its own. → move the method onto the data it envies.
- **Data Clumps**: the same few fields or params keep travelling together (a type wanting to be born). → bundle them into one type, pass that.
- **Primitive Obsession**: a primitive or string standing in for a domain concept that deserves its own type. → give the concept its own small type.
- **Repeated Switches**: the same `switch`/`if`-cascade on the same type recurs across the change. → replace with polymorphism, or one map both sites share.
- **Shotgun Surgery**: one logical change forces scattered edits across many files in the diff. → gather what changes together into one module.
- **Divergent Change**: one file or module is edited for several unrelated reasons. → split so each module changes for one reason.
- **Speculative Generality**: abstraction, parameters, or hooks added for needs the spec doesn't have. → delete it; inline back until a real need shows.
- **Message Chains**: long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
- **Middle Man**: a class or function that mostly just delegates onward. → cut it, call the real target direct.
- **Refused Bequest**: a subclass or implementer that ignores or overrides most of what it inherits. → drop the inheritance, use composition.

### 4. Run three independent review lanes

**Standards sub-agent prompt** should include:

- The full comparison commands, commit list, and relevant untracked files.
- The list of standards-source files you found in step 3, **plus the smell baseline from step 3** pasted in full (the sub-agent has no other access to it).
- The brief: "Report, per file/hunk where relevant, (a) every place the diff violates a documented standard: cite the standard (file + the rule); and (b) any baseline smell you spot: name it and quote the hunk. Distinguish hard violations from judgement calls: documented-standard breaches can be hard, but baseline smells are always judgement calls, and a documented repo standard overrides the baseline. Skip anything tooling enforces. Under 400 words."

**Spec sub-agent prompt** should include:

- The comparison commands, commit list, and relevant untracked files.
- The path or fetched contents of the spec.
- The brief: "Report: (a) requirements the spec asked for that are missing or partial; (b) behaviour in the diff that wasn't asked for (scope creep); (c) requirements that look implemented but where the implementation looks wrong. Quote the spec line for each finding. Under 400 words."

**Quality sub-agent prompt** should include:

- The comparison commands, commit list, and relevant untracked files.
- The brief: "Report only what makes this change **simpler**, never what makes it more capable. Cover: (a) **reuse**: logic the diff hand-rolls that an existing helper, type or library in this repo already does; name the existing thing and its path; (b) **simplification**: branches, layers, options, indirection or state the change can drop while keeping its behaviour identical; quote the hunk and say what to cut; (c) **altitude**: code sitting at the wrong level, a special case that should be general or a general mechanism serving exactly one caller; (d) **efficiency**: only where a hot path is obviously worse than an equally simple alternative. Behaviour must be preserved: if a suggestion changes what the code does, it belongs to Standards or Spec, not here. Skip anything tooling enforces. Rank by lines removed per unit of risk. Under 400 words."

If the spec is missing, skip the Spec sub-agent and note this in the final report. The Standards and Quality axes always run.

### 5. Aggregate

Present the three reports under `## Standards`, `## Spec` and `## Quality` headings, verbatim or lightly cleaned. Do **not** merge or rerank findings, because the axes are deliberately separate (see _Why three axes_).

End with a one-line summary: total findings per axis, and the worst issue _within each axis_ (if any). Don't pick a single winner across axes: that's the reranking the separation exists to prevent.

## Why three axes

A change can pass one axis and fail another:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the plan asked but breaks the project's conventions → **Spec pass, Standards fail.**
- Code that is correct, conformant and three times longer than it needs to be → **Standards and Spec pass, Quality fail.**

Reporting them separately stops one axis from masking another. Standards asks *is it written the way we write things here*, Spec asks *is it the right thing*, Quality asks *is it the least code that could work*. The first two can both pass while the change quietly adds complexity nobody asked for, which is the failure mode that compounds fastest in an agent-written codebase.
