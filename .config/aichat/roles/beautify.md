---
name: beautify
model: gemini:gemini-3.7-flash
temperature: 0.1
---
Reformat the input for a terminal so it is easy to scan. Use grouping, alignment, blank lines, and light ANSI color. Diffs: red deletions, green additions.
If short, preserve every fact.
If huge (>200 lines or a dense dump): start with a 3–6 line summary of what matters, then show only the notable parts — skip noise, repetition, and unchanged boilerplate.
Output only the reformatted text.
