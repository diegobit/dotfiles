---
name: writing-for-humans
description: Draft or revise a human-facing prose artifact. Must use for requests to write, rewrite, unslop, humanize, tighten, simplify, or remove jargon; preserve facts, uncertainty, attribution, protected text, and voice. Use for human-facing HTML files. Never use for ordinary conversation or agent-facing instructions; skills, markdown plans, AGENTS.md, and CLAUDE.md use writing-for-agents.
---

# Writing for humans

Write prose for adult human readers that is clear, concrete, natural, and precise.

Infer the reader, purpose, medium, language, and intended voice from the request and source. Ask only when a missing choice would materially change the result.

Write the point clearly, with enough context for this reader. Prefer concrete objects, actions, and supported examples. Let the content determine the structure and length. Keep technical terms when they carry useful precision and personality when it belongs to the writer.

## Revision contract

Preserve facts, meaning, uncertainty, attribution, citations, and recognizable voice. Keep quotations, code, commands, identifiers, paths, and link targets unchanged unless their editing is requested. Leave unresolved ambiguity unresolved or flag it; do not invent facts or strengthen claims to make the prose flow.

For “tighten” or “unslop,” preserve register and change passages that actually benefit. For “simplify” or “remove jargon,” adjust register for the reader while retaining technical distinctions. Follow the user's requested scope when it differs.

Compare the revision with the source for lost nuance, changed certainty, and unnecessary edits. Read it once for clarity and natural rhythm. Stop when the requested text works; a word, punctuation mark, or sentence pattern is not an error by itself.

## Calibration examples

These illustrate the contract; they are provisional examples, not a claim about the user's personal taste.

- Source: “The cache could potentially remain intact.”
  Revision: “The cache could remain intact.” The uncertainty survives.
- Source: “I love the idea. I still don't trust the migration.”
  Revision: unchanged. The opinion and uneven rhythm are doing useful work.
- Source: “The reducer is pure; effects run after the state transition.”
  Revision for engineers: unchanged. Replacing exact terms would lose precision.
- Source: “The service leverages a queue in order to retry failed jobs.”
  Revision: “The service uses a queue to retry failed jobs.” No new mechanism is invented.

Prefer user-approved examples when available. Deliver the requested prose without a process preamble unless a change explanation was requested.
