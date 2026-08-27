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
| **flash-worker** | Gemini CLI, authenticated | see the skill |
| **claude-worker** | Claude Code CLI, authenticated; `jq` | `brew install jq` |
| **cursor-worker** | Cursor CLI (`agent`), authenticated; `jq` | `curl https://cursor.com/install -fsS \| bash` · `brew install jq` |
| **harness-history** | `python3`, `jq` | `brew install jq` |
| **code-simplifier** | none | — |

The adapted engineering/productivity set (`grilling`, `grill-me`, `grill-with-docs`,
`diagnosing-bugs`, `handoff`, `to-spec`, `to-tickets`, `wayfinder`, `deep-review`,
`domain-modeling`, `writing-for-agents`, `research`, `prototype`, `to-questionnaire`, plus the
local `plan-tracker`) needs nothing installed: pure markdown.
Two deliberate divergences from upstream: there is no issue tracker, so anything that would have
been published to one is written as markdown under `docs/plans/` per `plan-tracker`; and upstream's
`code-review` is installed as `deep-review` to avoid collisions with existing review commands.

The adapted `arena`, `create-verification-skill`, and `writing-for-humans` skills are also pure
Markdown. Their shared instructions contain no harness-specific model IDs, paths, rules,
manifests, or commands.
`create-verification-skill` uses the repository's existing skill root and defaults to
`.agents/skills/` when none exists.

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

- The engineering/productivity set was adapted from
  [mattpocock/skills](https://github.com/mattpocock/skills).
- `arena`, `create-verification-skill`, and `writing-for-humans` were adapted from
  [Pstack](https://github.com/cursor/plugins/tree/main/pstack).
