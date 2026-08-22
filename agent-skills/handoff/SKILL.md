---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work.

Prefer the repository's established handoff directory, especially `docs/handoffs/`, and match its naming convention. If the repo has none, save a dated `handoff-<slug>.md` in the OS temporary directory. Report the absolute path either way.

Include a "suggested skills" section naming the relevant installed skills for the next agent to load.

Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.
