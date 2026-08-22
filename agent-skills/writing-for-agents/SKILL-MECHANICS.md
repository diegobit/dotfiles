# Skill mechanics

The skill-specific branch of [`writing-for-agents`](SKILL.md): portable frontmatter, invocation policy, dependencies, and router skills. Everything else about writing a skill lives in the main file.

## Portable frontmatter

This repository ships one `SKILL.md` to several harnesses. Keep its YAML frontmatter portable: `name`, `description`, and only fields accepted by every target. Harness-specific behavior belongs in that harness's metadata, not in the shared frontmatter.

Codex explicit-only invocation belongs in `agents/openai.yaml`:

```yaml
policy:
  allow_implicit_invocation: false
```

Otherwise omit the policy and write a discriminating model-facing description. Claude-only fields such as `disable-model-invocation` and `argument-hint` make the shared file invalid in Codex, so they do not belong here.

## Dependencies

When one skill genuinely depends on another installed skill, say `Load and apply the <name> skill`. Keep the wording tool-agnostic because harnesses expose skills differently. Ensure every named dependency is wired into every target harness.

## Splitting by invocation

Split off a discoverable skill when it has a distinct leading word that should trigger it independently, or when another skill must reach it. Its description spends permanent context load, so that independent reach must earn the cost.

## Router skills

When explicit-only skills multiply past what a human can remember, create one router skill that names them and says when each applies. This reduces cognitive load to one entrypoint. Keep its references tool-agnostic and verify that every named skill exists in each target harness.
