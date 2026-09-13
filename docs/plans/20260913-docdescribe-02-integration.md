# Work Unit 02: Skill Integration and FCRF Adapter

Status: `done`
Depends on: [01 Core CLI and Engine](20260913-docdescribe-01-cli.md)
Design: [docdescribe Design](20260913-docdescribe-00-design.md)

## Deliverable

1. Update `agent-skills/docextract/SKILL.md` to document the global `docdescribe.py` workflow, removing all hardcoded references to private repos (`fcrf`).
2. Adapt `fcrf/scripts/describe_corpus.py` to delegate rendering, inference, validation, and sidecar serialization to `docdescribe.py`.

## Detailed Specifications

1. **Skill Documentation (`agent-skills/docextract/SKILL.md`):**
   - Replace the uncommitted FCRF paragraph under the Figures section with clean, project-agnostic instructions:
     ````markdown
     ## Visual descriptions and document summarization

     Text extraction ignores vector diagrams, photos, and complex charts. For RAG pipelines
     needing semantic visual descriptions or top-level document summaries:

     ```bash
     # Describe figures on candidate pages discovered by docextract via local Ollama
     $SK/docdescribe.py report.pdf

     # Describe only specific pages
     $SK/docdescribe.py report.pdf --pages "3,22"

     # Generate a top-level document summary
     $SK/docdescribe.py report.pdf --summarize

     # Generate a summary only without rendering figures
     $SK/docdescribe.py report.pdf --summary-only
     ```

     `docdescribe` writes `*.describe.json` sidecar files containing structured semantic
     records and retrieval-ready index text, with request-level caching.
     Do not generate bulk captions in-chat; use `docdescribe` for batch ingest and reserve
     in-chat inspection for targeted single-screenshot queries.
     ````
   - Document prerequisites: local Ollama (`ollama run qwen3.5:9b`).
   - Document thinking budget: mandatory reasoning (`--think {low,medium,high}`, default `low`).

2. **FCRF Adapter (`fcrf/scripts/describe_corpus.py`):**
   - Retain FCRF-specific concerns locally:
     - Reading `data/extracted/manifest.jsonl`.
     - FCRF-specific evaluation items (`EVAL_ITEMS`).
     - Evaluation reporting to `data/extracted/_describe_eval/REPORT.md`.
     - Evaluation exit code policy: exit nonzero if any evaluation sample fails operationally.
   - Delegate core operations to `docdescribe.py`:
     - Page screenshot rendering and cleanup.
     - VLM chat protocol, schema definitions, and prompt templates.
     - Thinking settings and response validation (rejection of truncated output).
     - Cache computation, `index_text` generation, and sidecar serialization.
   - Compatibility verification:
     - Ensure generated sidecars match the exact schema expected by `fcrf/src/fcrf/corpus.py` (including `source_relpath`, `pages[].page`, `pages[].index_text`, `values_untrusted`, and `doc_summary`).

## Verification & Acceptance

- `agent-skills/docextract/SKILL.md` contains no references to `fcrf`, private repository paths, or internal variables.
- `writing-for-agents` style guidelines are followed.
- In `fcrf`, run tests:
  `pytest tests/test_describe_bounds.py` and existing corpus sidecar ingestion tests.
- Operational verification: running `python3 scripts/describe_corpus.py --eval` in `fcrf` delegates cleanly and exits with code 0.
