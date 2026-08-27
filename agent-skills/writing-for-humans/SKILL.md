---
name: writing-for-humans
description: Draft or revise a human-facing prose artifact. Must use for requests to write, rewrite, unslop, humanize, tighten, simplify, or remove jargon; preserve facts, uncertainty, attribution, protected text, and voice. Use for human-facing HTML files. Never use for ordinary conversation or agent-facing instructions; skills, markdown plans, AGENTS.md, and CLAUDE.md use writing-for-agents.
---

# Writing for humans

Write prose for adult human readers that is clear, concrete, natural, and precise.

## Writing contract

Identify or infer the reader, purpose, form, working language, intended voice, and any protected source material. Ask only when a missing choice would materially change the result.

Match the medium. Messages open directly. Spoken text uses pronounceable sentences and clear transitions. Technical prose keeps exact terms and relationships.

## Standard

- **Adults.** Start with the point. The reader lacks your context, not your capacity. Explain what they need once, without condescension, cheerleading, difficulty narration, or an unnecessary recap.
- **Concrete.** Name the object, action, mechanism, example, or supported number. If a sentence could appear unchanged in an unrelated document, it probably says too little.
- **Plain and precise.** Use the most familiar word that preserves the distinction. Keep a technical or domain term when it is exact; define it briefly only when this reader may not know it.
- **Voice.** Preserve genuine opinions, ambivalence, humor, first person, varied rhythm, and natural asymmetry. Do not replace personality with a generic professional register.
- **Agency.** Name who does what when the actor matters. Passive voice is useful when the actor is unknown, obvious, or irrelevant.
- **Shape.** Use headings and lists when they help navigation or comparison. Let the material determine the number and length of sections, paragraphs, and bullets.

## Write

When drafting new prose:

1. Settle what the reader should know, feel, decide, or do afterwards.
2. Put that point in the opening lines.
3. Choose only the structure the material needs. Use supported facts, examples, mechanisms, and numbers; leave unknown details unknown.
4. Write to the standard above. Give enough context to carry the point, then stop.
5. Audit the draft against the patterns below and fix every tell that is not the clearest choice in context.

Done means the intended reader can get the point on the first pass, the prose fits its medium and voice, and the audit finds no remaining tell worth changing.

## Revise

When source text exists, preserve its contract while changing only what the request authorizes.

### Preservation boundary

Preserve meaning, factual and epistemic strength, uncertainty, citations, attribution, working language, and recognizable voice. Leave quotations, source excerpts, code, commands, paths, identifiers, and Markdown link targets unchanged unless the user specifically asks to edit them.

Do not turn a plan into an event, resolve an ambiguity the source leaves open, invent a fact, opinion, anecdote, measurement, transition, or conclusion, or strengthen confidence. Source-sensitive, legal, historical, medical, and technical prose gets the smallest effective change unless the user authorizes a freer rewrite.

### Register

- **Preserve register** for requests to unslop, humanize, or tighten: remove formulaic AI tells while keeping the writer's vocabulary, legitimate jargon, house style, and working language.
- **Impose the standard** for requests to simplify, remove jargon, write for humans, or write for adults: replace unnecessary specialist or corporate language while keeping the preservation boundary.
- Follow an explicit user-defined scope when it differs from these defaults.

### Process

1. Identify the reader, purpose, form, language, intended voice, protected material, and register.
2. Scan for the patterns below as diagnostic signals, not banned words.
3. Rewrite only the affected passages. Restore opinions, ambivalence, humor, first person, examples, rhythm, and asymmetry already present in the source.
4. Compare the result with the source: fix what still sounds generated and restore any meaning, precision, attribution, uncertainty, or voice lost in the edit.

Done means every remaining pattern is the clearest choice or a preserved-register feature, every requested passage is addressed, and no edit exceeds the source contract.

## Patterns to detect and fix

These are signals, not mechanical substitutions or banned words. A listed word can be correct when it is the domain term or the most precise choice.

### Content

1. **Puffery.** "pivotal moment", "testament to", "evolving landscape", "setting the stage for", "indelible mark", "deeply rooted". Cut puffery; state what happened.
2. **Name-dropping.** Listing media outlets without context. Pick one and say what it reported.
3. **Superficial -ing phrases.** "highlighting...", "ensuring...", "reflecting...", "showcasing...", "fostering...". Delete them or expand them with a real fact or causal link.
4. **Promotional language.** "nestled", "vibrant", "breathtaking", "groundbreaking", "renowned", "stunning", "must-visit". Use a neutral, factual description.
5. **Vague attribution.** "Experts believe", "Industry reports suggest", "Some critics argue". Name the source or remove the claim.
6. **Formulaic challenges.** "Despite challenges... continues to thrive." Replace it with the concrete situation.

### Language

7. **AI vocabulary.** Additionally, crucial, delve, enduring, enhance, garner, interplay, intricate, landscape (abstract), pivotal, showcase, tapestry (abstract), testament, underscore, vibrant. Replace with direct wording.
8. **Fancy ways to say "is" or "has".** "serves as", "stands as", "boasts", "features". Use "is" or "has" when that is the meaning.
9. **"Not just X, but Y."** State the point directly instead of forcing a contrast.
10. **Rule of three.** Do not force ideas into triads. Use the natural number.
11. **Synonym cycling.** Calling one person "the protagonist", "the main character", "the central figure", and "the hero" in one passage. Pick one precise term and repeat it.
12. **False ranges.** "from X to Y" when X and Y are not on a meaningful scale. List the topics directly.

### Style

13. **Em dash overuse.** Repeated em dashes can make every sentence sound staged. Keep deliberate punctuation that matches the voice; split dense thoughts when that reads more naturally.
14. **Colon overuse.** Colons work before a list or example. A colon used as a staged mid-sentence connector often does not; rewrite that thought as a direct sentence.
15. **Boldface overuse.** Do not bold every proper noun, acronym, or inline phrase. Reserve emphasis for useful navigation.
16. **Inline-header lists.** The tell is a bold label and colon that restates the line: "**Performance:** Performance improved...". Convert it to prose. A concise lead-in followed by genuinely new detail is fine.
17. **Title case headings.** Use sentence case unless the house style requires otherwise.
18. **Decorative emojis.** Remove them from headings and bullets unless they carry information or belong to the established voice.
19. **Typography churn (revision only).** Preserve the document's quote and punctuation style. Changing typography alone is not a prose improvement.

### Communication artifacts

20. **Chatbot phrases.** "I hope this helps!", "Let me know if...", "Of course!", "Certainly!", "Found the smoking gun!". Remove canned framing and answer directly.
21. **Cutoff disclaimers.** "While specific details are limited...". Find the needed source, state the actual limit, or remove the sentence.
22. **Sycophantic tone.** "Great question! You're absolutely right!". Respond to the substance directly.

### Filler

23. **Filler phrases.** "In order to" becomes "To". "Due to the fact that" becomes "Because". "In the event that" becomes "If". "It is important to note that" is usually deleted.
24. **Excessive hedging.** Compress redundant hedges while preserving epistemic strength: "could potentially possibly be argued that it might" may become "may"; "may" must not become "does".
25. **Generic conclusions.** "The future looks bright." State a specific plan or fact, or stop without a conclusion.

### Jargon

26. **Abstract metaphor nouns.** Substrate, wedge, vector, locus, vantage, nexus, bedrock, scaffolding, paradigm, gold-plating, ratchet, endgame, north star, and flywheel often hide the concrete mechanism. Replace metaphorical uses with the actual object or action. Preserve established technical terms such as API surface, test harness, modality, or language primitive when they are exact in that domain.

### Plain speech

27. **Say what it does, not how it feels.** "the database stays close at hand", "SQL you can read", and "types that follow your schema" name a feeling. Name the mechanism or number instead: "`.toSQL()` returns the exact string sent to the database" or "a column rename fails the build". If the sentence cannot become a concrete fact, instruction, reason, or example, cut it.
28. **Shorten or split dense sentences.** If the reader has to backtrack, break the sentence in two or remove clauses.
29. **Active voice.** Prefer it when the actor matters: "the compiler validates queries" rather than "queries are validated". Keep passive voice when the actor is unknown, obvious, or irrelevant.
30. **Weak verbs propped up by adverbs.** Replace "runs quickly" with a stronger verb or the number. Replace "significantly improves" with the measured change when available.
31. **Fancy corporate synonyms.** "utilize" and "leverage" become "use"; "facilitate" becomes "help"; "numerous" becomes "many" when the plain word carries the same meaning.

## Final read

Read the result once as the intended reader and once against the writing or source contract. Confirm that:

- the point is clear without rereading;
- every claim retains its supported meaning, strength, attribution, and uncertainty;
- unfamiliar terms either earn their precision or have a useful explanation;
- every sentence contributes a fact, instruction, reason, transition, or genuine part of the voice;
- the prose sounds like the intended writer in this context, not a generic assistant; and
- protected material is unchanged.

Deliver the requested text without a preamble about the writing process unless the user asks for commentary or a change summary.
