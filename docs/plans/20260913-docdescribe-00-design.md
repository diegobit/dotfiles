# Design: Global Visual Description and Document Summarization (`docdescribe`)

Status: `done`
Ledger: [TODO.md](TODO.md)
Work units:
- [01 Core CLI and Engine](20260913-docdescribe-01-cli.md)
- [02 Skill Integration and FCRF Adapter](20260913-docdescribe-02-integration.md)

## Problem and Context

The `docextract` skill is a global agent skill for macOS that extracts text, markdown, and structured JSON from documents (PDF, Office, images) with best-in-class fidelity and benchmarked performance.

In the `fcrf` repository, an offline ingest script (`describe_corpus.py`) was developed to enhance document retrieval (RAG) by:
1. Rendering PDF page screenshots of figures/diagrams using `docextract --screenshot`.
2. Inspecting the visual page together with extracted surrounding text using a local VLM (Ollama `qwen3.5:9b`).
3. Generating structured descriptions (charts, diagrams, tables, screenshots, entities, values).
4. Generating document-level summaries from extracted text.
5. Emitting `*.describe.json` sidecar files consumed by `src/fcrf/corpus.py`.

An uncommitted change in `agent-skills/docextract/SKILL.md` attempted to guide agents toward this capability, but hardcoded:
`In the FCRF repo: python3 scripts/describe_corpus.py`.

This is an architectural defect and an abstraction leak:
- `docextract` is a shared global skill across multiple repositories.
- `fcrf/scripts/describe_corpus.py` is tightly coupled to FCRF's internal folder structure (`data/raw`, `data/extracted`), custom `manifest.jsonl`, hardcoded FCRF evaluation PDFs, and Italian keyword heuristics.
- Any project processing documents with `docextract` would benefit from semantic visual descriptions and summaries without having to reinvent or copy FCRF's script.

## Architectural Principles

1. **Separation of Extraction vs. Semantic Interpretation:**
   `docextract.py` remains fast, deterministic, CPU-bound, and free of heavy AI runtimes or daemon dependencies (PyMuPDF + Apple Vision + openpyxl).
   Semantic interpretation (VLM page descriptions and document summarization) lives in a dedicated companion script: `agent-skills/docextract/scripts/docdescribe.py`. It invokes `docextract.py` over a clean CLI subprocess boundary, preserving `docextract`'s PEP 723 dependency lifecycle and process isolation.

2. **Disabled Thinking by Default & Dual Backend Support:**
   Following empirical benchmarking on real-world FCRF and Italian public procurement (Capitolati) corpora, reasoning models like Qwen3.5:9B spend hundreds of internal thinking tokens that bloat latency (from 11s up to 45s) and risk output truncation when constrained by token budgets. Thinking is therefore disabled by default (`--think off`), restoring ~4x throughput and 100% schema validity. Optional reasoning remains selectable via `--think {low,medium,high}`.
   The runner also provides dual backend support for both Ollama (native Metal acceleration on macOS) and standalone `llama-server` (OpenAI-compatible `/v1/chat/completions` for Linux CUDA / containerized deployments) via `--backend {auto,ollama,llama-server}`.

3. **Input Support Matrix and Physical vs. Converted Pages:**

   | Input Format | Visual Description Support | Summary Support | Notes / Constraints |
   |---|---|---|---|
   | **PDF** | Render selected pages via `docextract` | Extracted text with recorded coverage | Bounded page batches at 150 DPI; cap max dimension to avoid giant engineering raster memory spikes. |
   | **Raster Images** (`.png`, `.jpg`, `.jpeg`, `.webp`, `.tif`) | Logical page 1 | Text from OCR pass | Decode/normalize format; reject animated GIF / multipage TIFF in v1 with explicit error. |
   | **Office / Converted Formats** (`.docx`, `.pptx`, `.xlsx`, etc.) | Unsupported in v1 (explicit error) | Converted text | Office files yield synthetic single-page text; no fabricated physical page screenshots until a headless office renderer exists. |

4. **Candidate-Page Discovery vs. Explicit Selection:**
   - Candidate discovery combines `figure_pages` and `image_text_pages` reported by `docextract --json`.
   - `--all-pages` bypasses candidate filtering to inspect every page.
   - `--pages <spec>` explicitly selects pages (validated strictly: deduplicated, sorted, range-checked against total pages).
   - If `docextract` exits with code 3 (no extractable text) but returns a valid JSON document record, visual description proceeds regardless.

5. **Page-Level Visual Description Scope:**
   Descriptions in v1 represent whole-page visual contents (`type` represents primary visual, `key_information` and `summary` capture all meaningful diagrams/charts on that page). Region-level bounding box decomposition is explicitly deferred.

6. **Full vs. Partial Document Summary Contract:**
   When generating document summaries, if extracted text fits within the context budget, generate directly. If text exceeds budget, use chunked extraction and reduction, or explicitly record coverage metadata (`chars_extracted`, `chars_summarized`, `truncated: bool`) so callers know whether the summary is holistic or a prefix. Summary-only execution (`--summary-only`) is supported without requiring candidate figure rendering.

7. **Canonical Request Caching & Downstream Sidecar Contract:**
   - Request cache key is a SHA256 digest of canonical parameters: `task_kind`, `normalized_image_bytes`, `exact_messages_prompt`, `schema_digest`, `prompt_version`, `model_tag`, `effective_think_level`, `temperature`, and `context_chars`.
   - Durable sidecars (`<source_filename>.describe.json`) are published via atomic temporary-sibling file replacement (`os.replace`).
   - Cache hits do not rewrite timestamps or sidecar bytes, avoiding spurious downstream cache invalidations.
   - Downstream RAG compatibility (required by `src/fcrf/corpus.py`):
     - `source_relpath`
     - `pages[].page`
     - `pages[].type` and `pages[].relevant`
     - `pages[].summary` and `pages[].key_information`
     - `pages[].index_text` (pre-formatted visual retrieval text: `[visual p.N type=...] ...`)
     - `pages[].important_values` with `values_untrusted: true`
     - `pages[].cache_key`, `model`, `described_at`, `wall_seconds`
     - `doc_summary` record with provenance and coverage

8. **Temporary Screenshot Lifecycle:**
   Screenshots are rendered into a dedicated per-document `tempfile.TemporaryDirectory` and cleaned up on success and failure. An explicit `--keep-shots <DIR>` debugging option allows retaining screenshots when desired.

## CLI & Usage Contract

```bash
# Describe figures on candidate pages discovered by docextract
$SK/docdescribe.py report.pdf

# Describe only specific pages
$SK/docdescribe.py report.pdf --pages "3,22"

# Describe and generate top-level document summary
$SK/docdescribe.py report.pdf --summarize

# Summary only (no figure rendering or image calls)
$SK/docdescribe.py report.pdf --summary-only

# Accept pre-extracted JSON to skip duplicate extraction in pipelines
$SK/docdescribe.py report.pdf --extract-json report.json

# Process a directory of documents
$SK/docdescribe.py ./docs/ -o ./extracted/

# Options:
#   --model MODEL         Ollama model (default: qwen3.5:9b, or env OLLAMA_MODEL)
#   --think {low,med,hi}  Mandatory thinking budget (default: low)
#   --ollama-url URL      Ollama endpoint (default: http://127.0.0.1:11434, honors OLLAMA_HOST)
#   --timeout SECONDS     Inference wall-clock timeout per call (default: 180s)
#   --keep-shots DIR      Retain rendered screenshot PNGs for inspection
#   --force               Bypass sidecar cache
#   --dry-run             List planned extraction, rendering, and inference without calling Ollama
```

## Work Breakdown

- [Unit 01: Core CLI and Engine](20260913-docdescribe-01-cli.md) — Implement `docdescribe.py` in `agent-skills/docextract/scripts/` with CLI, strict input matrix, batched rendering, Ollama client with `stream: false` and mandatory thinking, schema validation, atomic sidecar writes, and offline mock tests.
- [Unit 02: Skill Integration and FCRF Adapter](20260913-docdescribe-02-integration.md) — Update `agent-skills/docextract/SKILL.md` with project-agnostic instructions; adapt `fcrf/scripts/describe_corpus.py` to be a thin adapter over the global tool; verify compatibility with FCRF corpus ingestion.
