---
name: create-verification-skill
description: Create a project-local skill that launches and drives the real application, captures user-visible evidence, and cleans up safely. Use when a repo lacks a repeatable way for agents to verify UI, CLI, desktop, or service behavior.
---

# Create a verification skill

Generate a project-local `verify-<app>` skill that a fresh agent can run without rediscovering how the application starts, how users drive it, and what proves a feature works.

Load and apply `writing-for-agents` while generating it.

## 1. Find the project skill root

Follow an explicit user choice or repository instruction first. Otherwise reuse the first established canonical source:

1. a repo-owned `agent-skills/` directory with a linking script;
2. an existing `.agents/skills/` directory;
3. another skill root explicitly documented by the repository's agent instructions;
4. `.agents/skills/` as the portable default.

Use a harness-specific skill root only when the repository already establishes it or the user explicitly requests it. The portable default adds no harness-specific rules, manifests, or commands.

## 2. Interview the repo

Derive these facts from code and documentation before asking the user:

- **Surface:** the primary user-facing UI, CLI/TUI, desktop app, API, mobile app, or library.
- **Run:** the existing local start command, readiness signal, ports, environment, fixtures, and auth.
- **Drive:** existing Playwright/Cypress tests, PTY helpers, CLI commands, HTTP endpoints, debug ports, or other stable handles.
- **Observe:** screenshots, accessibility snapshots, terminal transcripts, response bodies, logs, exit codes, files, or database state.
- **Isolate:** ports, profiles, data directories, and other controls that keep concurrent runs from sharing mutable state.

Ask only for information that cannot be discovered and would change the generated procedure.

Invoking this skill authorizes creation of the verification skill and helpers inside its directory. It does not authorize changing application behavior, repairing an unrelated broken baseline, touching production, or using paid, live, deployment, or hardware paths. If the checkout cannot start safely as documented, report the exact blocker and leave the generated skill marked as an unverified draft unless the user separately asks for the prerequisite fix.

## 3. Generate `verify-<app>`

Create a valid `SKILL.md` with portable frontmatter and these sections, grounded in real repository commands and identifiers:

- **Launch:** exact start and teardown commands plus the readiness signal. Track the process or container created by the run.
- **Doctor:** one read-only check that confirms the expected app, build, port, profile, data directory, and auth context before driving it.
- **Drive:** real commands and stable selectors. Prefer accessibility roles, prompt strings, route paths, and public interfaces over coordinates or internal setters.
- **Evidence:** capture the action and resulting state, plus user-visible side effects. Name the evidence directory and distinguish verified, skipped, and blocked paths.
- **Cleanup:** stop only instances created by this run and remove only its scratch state. Retain evidence.
- **Helpers:** keep repeated mechanics in executable scripts inside the skill and show their invocation.

Use the repository's existing test or dry-run mode when it exercises the real user boundary. Verify what that mode skips instead of trusting its name.

## 4. Seed a small feature map

Create `features/README.md` and files for the 1-3 highest-value user-facing features that can be grounded from routes, commands, menus, or documentation. Read [`references/feature-map-example/`](references/feature-map-example/) for the format.

Each feature file covers:

1. user-visible behavior and sub-features;
2. every supported user entry point;
3. exact drive actions and observable results;
4. gotchas that can invalidate the proof.

Keep implementation details out of the map. A path that was not exercised remains skipped or blocked, not verified by analogy.

## 5. Prove the generated skill

Run launch, doctor, one mapped feature, evidence capture, and cleanup end to end in a safe local or test environment. Confirm cleanup left no owned process or scratch state behind and retained the evidence.

If any step cannot run within the user's authorization or environment, report the exact boundary and label the generated skill `draft, not run`. A passing frontmatter validator does not count as behavioral verification.

## 6. Hand off maintenance

Report the generated skill path, the feature exercised, evidence path, commands run, and remaining unverified features. Future application changes should update the feature map and rerun at least the affected recipe; do not rely on an uninstalled maintenance skill.
