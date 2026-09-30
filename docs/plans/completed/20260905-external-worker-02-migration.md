# Unified skill and discovery migration

Status: `done`.
Depends on: [shared launcher](20260905-external-worker-01-launcher.md).
Design: [external-worker consolidation](20260905-external-worker-00-design.md).

## Deliverable

One discoverable `external-worker` skill with one launcher, shared packet/evidence
instructions, and the old worker skills removed from discovery.

## Steps

1. Write `agent-skills/external-worker/SKILL.md` using the public interface and
   identity rules in the design. Combine packet, DECISIONS, evidence, file ownership,
   continuation, and acceptance guidance. Explain the concurrency limit explicitly.
2. Move CLI quirks and empirical verification notes into
   `references/backends.md`, linked for troubleshooting. Normal delegation needs
   only executor names; keep model configuration out of its examples.
3. Consolidate `agent-skills/README.md` dependencies. Search active tracked callers
   and shell aliases/functions for old names and migrate actual callers. Keep old
   completed-plan references and old cache contents unchanged.
4. After package 1 passes, remove the three superseded skill directories and
   safely remove their repository-owned discovery symlinks. Run
   `bin/link-agent-skills.sh` to publish the new skill to all seven configured
   discovery roots. No compatibility skills or launchers are retained.

## Verification and acceptance

- The skill-creator validator passes for the new skill and reference links resolve.
- The shared offline suite still passes from the final directory layout.
- `bin/link-agent-skills.sh --check` passes; additionally assert old worker names
  are absent from every discovery root, since the linker does not check removed
  skills. Unrelated links and non-symlink contents remain unchanged.
- Search active code/docs for old executable paths, model overrides, and lane
  examples; each remaining match is either historical or an intentional backend
  troubleshooting reference.
- Confirm installed CLI versions, production-model availability, and live-test
  outcomes from package 1 are recorded. Inspect the final diff for a single copy
  of report saving, cap validation, and lifecycle handling.

Mark this package and the consolidation effort done only after discovery and
behavioral acceptance both pass.

Validation completed 2026-09-05; see the [validation record](20260905-external-worker-00-design.md#validation-record).
