---
name: writing-for-humans
description: Draft or revise a human-facing prose artifact. Must use for requests to write, rewrite, unslop, humanize, tighten, simplify, or remove jargon; preserve facts, uncertainty, attribution, protected text, and voice. Use for human-facing HTML files. Never use for ordinary conversation or agent-facing instructions; skills, markdown plans, AGENTS.md, and CLAUDE.md use writing-for-agents.
---

# Writing for humans

Write so the reader can spend attention on the ideas rather than deciphering the prose. Infer the reader, purpose, medium, language, and intended voice from the request and source. Ask only when a missing choice would materially change the result.

## Core principles

- **Write simply.** Prefer ordinary words and direct syntax that carry the whole thought. Keep technical terms when they add precision and deliberate stylistic choices when they serve the reader or the writer's voice.
- **Put the point early.** Give enough context to understand it, then develop details in a natural order. Let the content and medium determine structure and length; keep useful headings, lists, and emphasis.
- **Let the thought set the rhythm.** State simple ideas directly. Use longer sentences for connected reasoning or qualifications. Split overloaded sentences at thought boundaries; avoid repeatedly using em dashes to splice thoughts together. A punctuation mark or sentence pattern is not an error by itself.
- **Cut unearned importance.** Remove throat-clearing, repeated claims, inflated praise, and stock conclusions that add no substance. For “unslop,” revise empty corporate framing as well as individual words; replacing buzzwords with plainer buzzwords is not enough. Keep concrete actions and supported examples, but do not invent them to make vague prose sound useful.
- **Use awkwardness as a cue.** Read as the first reader: where do you stumble or lose the thread? Check the reasoning, missing context, or unsupported premise as well as the words. Fluency is not evidence that a claim is true, and clumsy prose alone does not discredit technical work.

## Revision contract

Preserve facts, meaning, uncertainty, attribution, citations, and recognizable voice. Keep quotations, code, commands, identifiers, paths, and link targets unchanged unless their editing is requested. Leave unresolved ambiguity unresolved or flag it; do not invent facts or strengthen claims to make the prose flow.

For “tighten” or “unslop,” preserve the author's substantive position and meaningful register while cutting empty rhetoric. Do not replace a vague promise with a new causal claim, outcome guarantee, ranking, or broader scope. If an unsupported assertion carries substantive meaning, preserve it as an assertion or flag it when the requested scope permits; do not silently validate or repair it. For “simplify” or “remove jargon,” adjust register for the reader while retaining technical distinctions. Follow the user's requested scope when it differs.

Compare the revision with the source for lost nuance, changed certainty or scope, and unnecessary edits. Read once for clarity and natural rhythm. Stop when the requested text works.

## Write in the target language

Keep the source language unless translation is requested. Use the output language's natural syntax, idiom, punctuation, and cadence, suited to its audience and register. Do not impose English sentence structure, word blacklists, or literal translations of idioms. Preserve established domain terms; an English loanword in Italian is not automatically an error.

## Calibration examples

These illustrate decisions, not mandatory wording:

- “The cache could potentially remain intact.” → “The cache could remain intact.” Keep the uncertainty.
- “The reducer is pure; effects run after the state transition.” → unchanged for engineers. The terms carry precision.
- “Our transformative process may help teams coordinate.” → “Our process may help teams coordinate.” Do not turn “may help” into “improves productivity.”
- “Questi strumenti possono favorire la collaborazione.” → unchanged. Replacing “possono favorire” with “garantiscono” would add certainty.

Deliver the requested prose without a process preamble unless a change explanation was requested.

## References

The principles adapt Paul Graham's essays; they are editing heuristics, not evidence of LLM performance. Read these optional references when the rationale or its limits matter:

- [Write Simply](https://www.paulgraham.com/simply.html): reading friction, ordinary words, and cutting.
- [Good Writing](https://www.paulgraham.com/goodwriting.html): thought-led rhythm and revision, including the limits of the link between fluency and correctness.
