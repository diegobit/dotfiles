---
name: code-simplifier
description: Refactor recently modified code to be clearer, simpler, and more consistent without changing behavior. Use when the user asks to clean up, simplify, refactor, or tidy code they just wrote, or to improve readability/consistency of recent changes. Follows CLAUDE.md conventions and avoids "clever" one-liners.
---

# Code Simplifier

## Purpose

Refine code for **clarity, consistency, maintainability, simplicity, elegance** while preserving **exact functionality**.

This skill improves *how* code is written, **not** *what* it does.

## Default scope

- Refactor **only** code that was **recently modified/touched** in the current session (diff/edited files/lines).
- Expand scope only if the user explicitly requests it.

## Non-negotiables

### Preserve behavior (always)
Do **not** change:
- outputs, side effects, observable performance characteristics that are relied upon, or public APIs
- error behavior (what fails, what returns, user-visible messages/types) unless explicitly requested
- data formats, serialization, ordering, timing semantics (when relevant)

If you can't be confident behavior is unchanged, **ask** for expected behavior/tests.

### Follow project standards (always)
- If `CLAUDE.md` or `AGENTS.md` exists, treat it as the **source of truth**.
- Otherwise, follow repository conventions (lint/format, naming, patterns, directory structure).

## Principles

The goal is to lower complexity.

Prefer:
- removing **redundant code**, dead code, and unnecessary abstractions
- Control complexity at every edit. Pick the simplest working design; refactor immediately if a change feels kludgy.
- Favor deep modules. Expose a tiny, stable interface; hide as much logic as possible behind it.
- Enforce information hiding. No internal data, types, or temporal ordering should leak across module boundaries.
- Pull complexity downward. High-level code must remain obvious—push gritty details into helpers/utilities.
- Remove duplication & special cases. Unify repeated logic; redesign so rare paths are handled automatically, not with if ladders.
- Let names tell the story. Precise, consistent names; if naming is hard, the abstraction is wrong.
- Comment intent, not mechanics. Explain why, constraints, and surprising decisions—never narrate what the code plainly shows.
- Optimize for readers. Prefer clarity over clever tricks or micro-optimizations.
- Think strategically, not tactically. Allocate steady effort to cleanup; reject "quick" hacks that create debt.

Avoid "simplifications" that:
- create clever/dense code that's harder to read (one-liners, tricky short-circuiting, overly abstracted pipelines)
- over-DRY into abstractions that hide intent
- merge multiple concerns into one function/module
- prioritize fewer lines over maintainability
- reduce debuggability (harder breakpoints/stack traces) without strong reason

## When `CLAUDE.md` specifies language/framework rules

Apply them exactly. Examples of project-standard rules you might see:
- import/module conventions (e.g., ES modules, import sorting, extensions)
- "prefer `function` over arrow functions"
- explicit return types for exported/top-level functions (TypeScript)
- framework component patterns (React/Vue/etc.) and explicit props types
- error handling patterns ("avoid try/catch when possible", etc.)

Treat these as **conditional**: enforce them only if they are part of the project's standards.

## Workflow

1. **Identify the refactor target**
   - Use the diff/changed files or user-provided snippet to locate recently modified code.
2. **Read surrounding context**
   - Match nearby patterns and repo conventions.
3. **Refine**
   - Apply small, safe transformations that improve readability and consistency.
4. **Sanity-check behavior preservation**
   - Re-check edge cases, error paths, and types/contracts.
5. **Report**
   - Summarize only changes that affect understanding (not every mechanical edit).

## Output expectations

When producing changes:
- Apply edits directly to the files with the Edit tool (this is the Claude Code idiom), rather than emitting a patch for the user to apply.
- Provide a short **change summary** focused on readability/consistency.
- State that behavior is intended to be unchanged, and note any assumptions + what to verify.
