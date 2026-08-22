---
name: unslop
description: Revise prose to remove formulaic AI patterns while preserving facts, attribution, uncertainty, and the writer's voice. Use when the user asks to unslop, humanize, tighten, or remove AI-sounding language from text.
---

# Unslop

Edit prose to remove formulaic AI patterns and restore the intended human voice.

## Preservation boundary

Preserve meaning, factual strength, uncertainty, citations, attribution, and the working language. Leave quotations, source excerpts, code, commands, paths, identifiers, and Markdown link targets unchanged unless the user specifically asks to edit them. In source-sensitive or legal/technical text, make the smallest wording change that removes the tell.

Do not invent opinions, anecdotes, measurements, or confidence. Strengthen an opinion only when it is already the writer's. Match the user's vocabulary and house style instead of imposing an English internet voice on Italian, client, or evidence-grade prose.

## Process

1. Identify the audience, language, intended tone, and protected source material.
2. Scan for the patterns below as heuristics, not banned words.
3. Rewrite only the affected passages. Prefer concrete nouns, verbs, evidence, and natural rhythm.
4. Self-audit: "What still sounds generated, and did any edit change the claim?" Fix the tell and restore any lost precision.

## Restoring voice

Removing patterns is half the job. Sterile, voiceless writing is just as obvious.

- **Keep real opinions.** Let the writer react when the source already contains that reaction.
- **Vary rhythm.** Short sentences. Then longer ones that take their time. Mix it up.
- **Keep real ambivalence.** When the writer already holds two reactions at once, preserve both instead of flattening them into neutral summary.
- **Use "I" when it fits.** First person isn't unprofessional.
- **Allow natural asymmetry.** Do not force every paragraph or list into the same shape.
- **Be specific.** Replace a generic reaction with the concrete fact or example already present in the source.

## Patterns to detect and fix

These are signals, not mechanical substitutions. A listed word can be correct when it is the domain term or the most precise word.

### Content

1. **Puffery.** "pivotal moment", "testament to", "evolving landscape", "setting the stage for", "indelible mark", "deeply rooted". Cut puffery, state what happened.
2. **Name-dropping.** Listing media outlets without context. Pick one, say what was said.
3. **Superficial -ing phrases.** "highlighting...", "ensuring...", "reflecting...", "showcasing...", "fostering...". Delete or expand with real sources.
4. **Promotional language.** "nestled", "vibrant", "breathtaking", "groundbreaking", "renowned", "stunning", "must-visit". Use neutral descriptions.
5. **Vague attributions.** "Experts believe", "Industry reports suggest", "Some critics argue". Name the source or delete.
6. **Formulaic challenges.** "Despite challenges... continues to thrive." Replace with specific facts.

### Language

7. **AI vocabulary.** Additionally, crucial, delve, enduring, enhance, fostering, garner, interplay, intricate, landscape (abstract), pivotal, showcase, tapestry (abstract), testament, underscore, vibrant. Replace with plain words.
8. **Fancy ways to say "is".** "serves as", "stands as", "boasts", "features". Just say "is" or "has".
9. **"Not just X, but Y."** State the point directly instead.
10. **Rule of three.** Forcing ideas into groups of three. Use the natural number.
11. **Synonym cycling.** Protagonist, main character, central figure, hero all in one paragraph. Pick one, repeat it.
12. **False ranges.** "from X to Y" where X and Y aren't on a meaningful scale. List topics directly.

### Style

13. **Em dash overuse.** Repeated em dashes can make every sentence sound staged. Keep deliberate punctuation that matches the writer; split dense thoughts when that reads more naturally.
14. **Colon overuse.** Colons are fine before a list or example. Not as mid-sentence connectors. "If you're coming from traditional automation: instead of registering event handlers, you describe conditions" adds nothing with the colon. Rewrite to let the point stand on its own without comparison framing. "Describing when the scheduler should fire works best as plain English." Same meaning, no crutch punctuation.
15. **Boldface overuse.** Don't bold every proper noun or acronym.
16. **Inline-header lists.** The tell is a bold label and colon that restates the line: "**Performance:** Performance improved...". Convert those to prose. A bold lead-in that ends in a period, names the item, and is followed by genuinely new detail ("**Schema in TypeScript.** Tables live in one file.") is fine, not a tell.
17. **Title case headings.** Use sentence case.
18. **Decorative emojis.** Remove from headings and bullets.
19. **Typography churn.** Preserve the document's existing quote and punctuation style. Changing typography is not a prose improvement.

### Communication artifacts

20. **Chatbot phrases.** "I hope this helps!", "Let me know if...", "Of course!", "Certainly!", "Found the smoking gun!" Remove.
21. **Cutoff disclaimers.** "While specific details are limited..." Find sources or remove.
22. **Sycophantic tone.** "Great question! You're absolutely right!" Respond directly.

### Filler

23. **Filler phrases.** "In order to" becomes "To". "Due to the fact that" becomes "Because". "It is important to note that" gets deleted.
24. **Excessive hedging.** "could potentially possibly be argued that it might" becomes "may".
25. **Generic conclusions.** "The future looks bright." State specific plans or facts.

### Jargon

26. **Abstract metaphor nouns.** Substrate, wedge, vector, locus, vantage, nexus, bedrock, scaffolding, paradigm, gold-plating, ratchet, endgame, north star, and flywheel often hide the concrete mechanism. Replace metaphorical uses with the actual object or action. Preserve established technical terms such as API surface, test harness, modality, or language primitive when they are precise in that domain.

### Plain speech

27. **Say what it does, not how it feels.** "the database stays close at hand", "SQL you can read", "types that follow your schema" name a feeling. The fix names the mechanism or a number: "`.toSQL()` returns the exact string sent to the database", "a column rename fails the build". Ask what the sentence tells the reader to do or know, then write that. If you can't restate it as a concrete instruction, fact, or number, cut it. One more check: if the sentence could appear unchanged in another project's docs, it says nothing about this one. Cut it.
28. **Shorten or split dense sentences.** If the reader has to backtrack to parse a sentence, break it in two or drop clauses. One idea per sentence.
29. **Active voice.** Prefer it. Catch "is/are/was/were + past participle" and name the actor: "queries are validated" becomes "the compiler validates queries", "the file is parsed by the loader" becomes "the loader parses the file". Passive is fine only when the actor is unknown or genuinely doesn't matter.
30. **Cut adverbs, or use a stronger verb.** "runs quickly" becomes "is fast" or the number. "significantly improves" becomes the measured delta. An adverb propping up a weak verb means the verb is wrong.
31. **Prefer the plain word.** "utilize" becomes "use", "leverage" becomes "use", "facilitate" becomes "help", "numerous" becomes "many", "in the event that" becomes "if". The fancier synonym is rarely clearer.
