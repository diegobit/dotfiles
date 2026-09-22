---
name: writing-for-agents
description: Writing documents for agents. Use when creating or editing skills, or modifying AGENTS.md or CLAUDE.md.
---

# Writing for agents

Write the information that changes an agent's decisions: the requested outcome, local conventions, non-obvious constraints, available interfaces, and how to recognize completion.

## Make instructions usable

- Distinguish requirements from defaults and examples. Preserve the user's scope and existing authorization; describe where input is actually needed rather than adding blanket approval stops.
- State conditions precisely enough to act on. Keep important properties explicit: “fast and deterministic” is clearer than an unexplained “tight.”
- Keep related constraints together and give each rule one authoritative home. Reference commands or configuration for easily discoverable details; explain local gotchas the environment does not reveal.
- Keep essential guidance in the entry point. Put substantial conditional procedures in references, with a clear condition for reading each. A short document does not need a routing layer.
- Use scripts for repeated or fragile mechanics. Document their inputs, relevant failure modes, and observable results instead of teaching the model to reconstruct them.
- Choose completion criteria that demonstrate the requested outcome. Scale verification to the consequences; a fixed phase count or exhaustive checklist needs a concrete reason.

- Remove instructions that add no useful behavior beyond the model’s default. Delete redundant rules rather than merely shortening them; use representative tasks when the benefit is uncertain.

## Skill packaging

Give each skill a concise name and a description that identifies its capability and when to select it. Add exclusions only for likely routing collisions. Resolve supporting paths relative to the skill directory.

This repository shares skills across harnesses. Preserve portable frontmatter and put Codex invocation policy in `agents/openai.yaml`. Preserve the existing invocation mode unless the user requests a change; describe explicit-only intent in shared text for other harnesses. A skill directory needs a `SKILL.md` with valid YAML frontmatter containing `name` and `description`; keep the name consistent with the directory. Link supporting references where their use becomes relevant.

When another skill is required, state the condition and say “Load and apply the <name> skill.” Verify that dependency is available in the target environment. If skill-creator is installed, load and apply it when packaging or validation needs its guidance; otherwise validate frontmatter, names, references, and executable examples directly.

## Check the result

Verify references and executable examples. Compare instructions against the task scope and look for conflicts, duplicate rules, and unnecessary stopping points. For a meaningful behavioral change, use representative tasks to compare the current instructions, the revision, and the model's default behavior. Keep rules supported by useful outcomes; treat prompting theories as hypotheses until tested.
