# agent-skills

Skills shared by every coding agent on this machine. Each directory is one skill; its `SKILL.md`
is the single source of truth for how to use it. This file only covers the two things that are
*not* in a SKILL.md: how they get wired up, and what has to exist on the machine.

## Wiring

One directory per skill here, symlinked into the discovery locations the harnesses read from:

| harness | reads from |
|---|---|
| Claude Code (project) | `.claude/skills/` |
| Claude Code (user) | `~/.claude/skills/` |
| Cursor (user) | `~/.cursor/skills/` |
| opencode | `.config/opencode/skills/` |
| Gemini CLI | `.gemini/config/skills/` |
| Codex (user) | `~/.codex/skills/` |
| generic / `AGENTS.md` | `.agents/skills/` |

Edit the skill once in `agent-skills/`, and every harness sees it. To create or repair the links:

```bash
bin/link-agent-skills.sh            # idempotent; prints one line per link
bin/link-agent-skills.sh --check    # report only, non-zero exit if anything is missing/broken
```

`install.sh` calls it, so a fresh machine is wired automatically. Adding a skill is: make the
directory, re-run the script.

## Dependencies

Nothing here needs a global Python environment. `docextract` declares its Python packages inline
([PEP 723](https://peps.python.org/pep-0723/)) so `uv` installs them into a cache on first run.

| skill | needs | install |
|---|---|---|
| **docextract** | `uv`; Xcode CLT (for `swiftc`, builds the Vision OCR helper once) | `brew install uv` · `xcode-select --install` |
| **delegate** | `jq`, `shasum` or `sha1sum`; selected authenticated CLI: `agy` (default), `claude`, Cursor `agent`, `codex`, or `opencode` | `brew install jq`; see the skill |
| **harness-history** | `python3`, `jq` | `brew install jq` |
| **code-simplifier** | none | — |

The remaining instruction-only skills are `code-simplifier`, `domain-modeling`,
`plan-tracker`, `plan-work`, `writing-for-agents`, `writing-for-humans`, and
`create-verification-skill`. The verification skill uses the established project skill
root, defaulting to `.agents/skills/` when none exists.

`plan-work` replaces `to-spec` and `to-tickets`, with separate specification and
implementation-planning modes. It follows `plan-tracker` for publication.

The revised `docextract`, `writing-for-humans`, and `writing-for-agents` are the
default versions. Earlier versions remain in Git history; the `*2` comparison
entry points have been retired.

Codex marks `code-simplifier`, `create-verification-skill`, and `plan-work`
explicit-only through `agents/openai.yaml`.

OpenCode's `scheduled-tasks` and `db-cleanup` remain separate under
`~/.config/opencode/skills/`; the shared linker does not manage them.

`docextract` is macOS-only *for OCR* — that path uses Apple's Vision framework. PDF text, Office
formats and markdown conversion are portable Python and work anywhere; on a non-macOS host a
scanned page fails with an explicit error rather than returning silence.

Deliberately **not** required: no LibreOffice, no ImageMagick, no Node, no cloud API key. An
earlier document skill needed the first three; `docextract` was tested without them.

## Conventions

- `SKILL.md` front matter needs `name` and `description` — the description is what the model
  matches on, so it should name the triggers, not just the topic.
- Put executables in `<skill>/scripts/`, long reference material in `<skill>/references/` so it is
  loaded only when needed.
- Compiled artefacts stay out of git (`agent-skills/docextract/scripts/vision_ocr` is gitignored;
  it rebuilds itself on first use).
- Measured claims in a SKILL.md should say where the numbers come from — `docextract` points at
  `references/benchmark.md`.

## Sources

- The retained domain modeling and agent-writing skills, and the planning skills
  consolidated into `plan-work`, were adapted from
  [mattpocock/skills](https://github.com/mattpocock/skills).
- `create-verification-skill` and `writing-for-humans` were adapted from
  [Pstack](https://github.com/cursor/plugins/tree/main/pstack).
