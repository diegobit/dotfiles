# Work Unit 01: Core `docdescribe` CLI and Engine

Status: `done`
Depends on: none
Design: [docdescribe Design](20260913-docdescribe-00-design.md)

## Deliverable

Create `agent-skills/docextract/scripts/docdescribe.py` as an executable Python script (`uv run` or direct `python3`) with standard library networking (`urllib.request`) and robust CLI options. Provide unit and mock tests in `agent-skills/docextract/tests/test_docdescribe.py`.

## Detailed Specifications

1. **CLI Interface and Options:**
   - Positional: `INPUT` (file or directory).
   - `-o, --out DIR`: Target directory for durable sidecars (defaults to beside source file; for directory inputs with `--out`, mirrors relative input hierarchy).
   - `--pages "1,3,5-8"`: Explicit page selection; strictly validated (deduplicated, sorted, 1-indexed, bounds-checked against document page count).
   - `--summarize`: Generate document-level summary alongside visual descriptions.
   - `--summary-only`: Generate document summary only (bypasses candidate page discovery and screenshot rendering).
   - `--all-pages`: Inspect every page regardless of candidate figure flags.
   - `--extract-json PATH`: Use pre-extracted `docextract` JSON (skips redundant text extraction in batch pipelines).
   - `--keep-shots DIR`: Retain rendered screenshot PNGs; otherwise render into a `tempfile.TemporaryDirectory` and clean up immediately.
   - `--model`: Default `qwen3.5:9b`, or read from `OLLAMA_MODEL`.
   - `--think {low,medium,high}`: Mandatory thinking budget, default `low`. Completely remove `--think off` and keyword regex selectors.
   - `--ollama-url`: Normalized Ollama chat endpoint (reads `OLLAMA_HOST` or defaults to `http://127.0.0.1:11434`, ensuring `/api/chat` suffix is cleanly handled).
   - `--timeout`: Inference timeout per call in seconds (default 180s).
   - `--force`: Bypass sidecar cache.
   - `--dry-run`: Emit JSON plan of operations (documents, candidate pages, cache status) without invoking model inference or durable sidecar writes.

2. **Process Boundary and Extraction Integration:**
   - Locate `docextract.py` dynamically: check sibling path `Path(__file__).parent / "docextract.py"`, fallback to `shutil.which("docextract")`. Do not fallback from a broken sibling to a PATH executable.
   - If `--extract-json` is not passed: run `docextract FILE --json`. Accept return code 0 or 3 (where code 3 is empty text), and validate that output JSON parses into a valid document record.
   - Render target pages in a **single bounded batch** using `docextract FILE --screenshot <temp_dir> --pages "..." --dpi 150`, avoiding per-page process startup overhead.
   - For raster images (`.png`, `.jpg`, etc.), decode/normalize directly to logical page 1. Reject multipage TIFF and animated GIF in v1 with explicit error messages. Reject Office files for visual description until a physical renderer is available.

3. **Ollama Protocol and Response Validation:**
   - Always pass `stream: false`.
   - Pass `think: think_level` directly in the payload.
   - Format payload with `format: JSON_SCHEMA` or `format: DOC_SCHEMA`.
   - Options: `{"temperature": 0.1, "num_ctx": 16384, "num_predict": 4096}`.
   - **Safety & Error Diagnosis:**
     - Unreachable host -> raise actionable `OllamaUnreachableError("Ollama is not reachable at <url>. Start it with: ollama serve")`.
     - Model missing (404) -> raise `ModelNotFoundError("Model '<model>' not found. Pull it with: ollama pull <model>")`.
     - Check `done_reason`: reject with explicit `TruncatedOutputError` if `done_reason == "length"`.
     - Parse JSON: first inspect `message.content`. If empty and thinking mode is active, check `message.thinking` only as a documented fallback.
     - **Application-Side Schema Validation**: Do NOT use loose python coercions (`bool("false")` or `list("str")`). Strictly validate field types, enum values (`type` in `["chart", "diagram", "table", "photo", "screenshot", "signature", "decorative", "other"]`), and required keys.

4. **Cache & Atomic Sidecar Publishing:**
   - Compute canonical cache key: SHA256 of `(task_kind, image_bytes, messages_text, schema_digest, prompt_version, model_tag, think_level, temperature)`.
   - Sidecar envelope structure (matching downstream RAG requirements in `src/fcrf/corpus.py`):
     - `source_relpath`: relative path of document.
     - `model`: model tag used.
     - `prompt_version`: prompt identifier.
     - `pages`: list of page records containing `page`, `relevant`, `type`, `summary`, `key_information`, `entities`, `important_values`, `values_untrusted` (true), `index_text`, `cache_key`, `wall_seconds`, `described_at`.
     - `doc_summary`: summary object containing `summary`, `doc_type`, `entities`, `key_information`, `coverage`, `wall_seconds`, `described_at`.
   - Sidecar persistence: write to a temporary sibling file in the same directory (`<dest>.tmp.XXXXXX`) and perform atomic replacement (`os.replace`).
   - If all operations for a document hit the cache, do not touch timestamps or re-save the sidecar.

5. **Automated Offline Testing (`test_docdescribe.py`):**
   - CLI argument validation: test `--pages` parsing (ranges, invalid numbers, out-of-bounds, duplicates), invalid `--think` options (rejecting `off`), `--summary-only` flag.
   - Mock Ollama HTTP responses:
     - Valid JSON response parsing and schema validation.
     - Truncated response rejection (`done_reason == "length"`).
     - Response where JSON is returned in the thinking field.
     - Malformed JSON and schema type mismatches (e.g. `type: "invalid_enum"`, non-boolean `relevant`).
     - Daemon connection error handling and model 404 handling.
   - Rendering and Temporary Directory cleanup:
     - Verify temp screenshot directory is deleted after run (and retained when `--keep-shots` is passed).
   - Sidecar atomic write and cache hit idempotency:
     - Verify sidecar file contents, `index_text` generation, and that unchanged entries are not rewritten.

## Verification & Acceptance

- `python3 agent-skills/docextract/scripts/docdescribe.py --help` runs cleanly.
- `python3 -m unittest agent-skills/docextract/tests/test_docdescribe.py` passes 100% offline without requiring a running Ollama daemon.
- Smoke verification with a real PDF against local Ollama (if available on the host).
