---
name: to-questionnaire
description: Turn a decision you can't fully answer into a questionnaire for someone else to fill in.
---

Turn something the user can't answer alone into a **questionnaire**: a Markdown document they hand to one person to fill in async, or fill out together over a meeting. The recipient holds knowledge the user lacks; the questionnaire pulls it out of them.

**Grill the send, not the subject.** Interview the user only about the _send_, which they can always answer: who it goes to, and what they need back. The questions in the document then target the **gap** between what the recipient knows and what the user needs.


1. **Who is it going to?** Infer the recipient's role, expertise, and relationship from the conversation and repo. Ask in one exchange only when this is materially unclear. Done when you know who the recipient is and what they know that the user doesn't.

2. **What do you need back?** Infer the needed decisions or facts from context. Ask in one exchange only for gaps that would change the questions. Done when you have a concrete list of what the user must walk away able to do or decide.

3. **Write the questionnaire.** Draft questions aimed at the gap from steps 1–2, following the Voice and Document structure below. Write it to `to-questionnaire-<slug>.md` in the current directory (slug from the topic) and report the path. Done when the file exists and every item the user named in step 2 is covered by a question.

## Voice

Write as the user, in the user's own words. Two rules bind this.

**Mine their vocabulary, don't supply your own.** The user has already described this subject in the conversation, in their prompts, and in the repo's docs and code. Take the nouns from there. Where they call it a *plan*, don't write *ticket*; where they say *staging*, don't write *the pre-production environment*. A questionnaire in vocabulary the recipient has never heard from this user reads as written by someone else, and gets answered as such.

**Plain language, short.** One idea per sentence. Ordinary words over formal ones: *use* not *utilise*, *find out* not *ascertain*, *decide* not *make a determination*. Cut every sentence that carries no question and no fact the recipient needs. A question the recipient can answer in one line should not take three to ask.

Match the language the user and recipient actually correspond in: if the working language is Italian, write the questionnaire in Italian.

**Length bar:** the whole document fits on one screen unless the user asked for more. If it doesn't, you have either asked questions they didn't need or explained context they already have. Cut the context first.

## Document structure

Frame the document as a **discovery questionnaire**: the user lacks context, the recipient holds it. Order questions most-important-first, since async means you may only get one pass, and group them under `##` headings by theme once there are more than a handful. Write it using the template below.

<questionnaire-template>

# <Questionnaire title>

**Purpose:** why this questionnaire exists and the decision riding on it.

**From:** <the user>, **To:** <the recipient>, **How your answers will be used:** <where they go>

## Context

Two or three sentences orienting a recipient who wasn't in the user's head. Enough to answer well. Skip whatever they already know.

## How to answer

Deadline and rough effort. Partial answers and "I don't know" are useful: flag anything you're unsure of rather than skipping it.

## <Theme heading>

One `##` section per theme. Under each, its questions, most-important-first. Every question is one idea, never compound, with an answer stub directly beneath. Add a one-line _why this matters_ only where the question could be misread or invite a throwaway answer; most questions don't need one.

<question-example>
### What load is the system expected to handle at launch?

_Why this matters: it decides whether we provision for burst traffic now or defer it._

>
</question-example>

## Anything else?

A closing catch-all: anything we didn't ask that we should know?

</questionnaire-template>
