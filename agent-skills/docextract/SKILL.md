---
name: docextract
description: "Extract text, markdown, structured JSON, visual figure descriptions, or executive summaries from documents (PDF, DOCX, PPTX, XLSX, CSV, images, HTML, EPUB) locally. Fast hybrid routing: PyMuPDF for text, Apple Vision OCR for scans, and local VLM (docdescribe with Ollama/llama-server) for visual captions and summaries. Use when asked to read, parse, extract, describe, or summarize a document, image, or whole directory."
---

# Document extraction

Extract text, tables, and visual structure from local documents using hybrid engine routing: PyMuPDF for born-digital text, Apple Vision OCR for scans, and MarkItDown for Office formats. Use local VLM (`docdescribe.py`) for captions and summaries. Resolve paths relative to this skill directory, including when reached through a harness symlink.

## Extract and inspect

```bash
scripts/docextract.py FILE --text                                # text content & page markers
scripts/docextract.py FILE --json -o /tmp/document.json          # per-page text, OCR flags, tables
scripts/docextract.py FILE --probe                               # detect layout and stacked headers
scripts/docextract.py FILE --screenshot /tmp/pages --pages "1,3" # visual verification
```

- Use `--text` for questions about content; keep page markers for citations. Use `--json` for per-page text, OCR provenance, figures, and row groups.
- Use default markdown output for conversion or storage. For complex tables, run `--probe`; re-extract indicated stacked-header pages in markdown and inspect their rendered headers. Probe recommendations are heuristics.
- Render and inspect pages for charts, drawings, checkboxes, layout, ambiguous table bindings, and consequential values that look suspicious. Extraction alone does not establish visual meaning.
- Mixed pages omit text inside images by default. Add `--image-ocr` when the answer may be in an image; distinguish OCR guesses from the existing text layer.
- Read `row_groups` or row-group comments before attributing table rows to a spanning label. Check rendered pages when exponents, symbols, or multi-level headers matter.
- Exit `0` means extraction completed, `1` is a hard failure, and `3` means no text was extracted. An empty extraction calls for visual inspection, not an assertion that the document is empty.

## Visual captions and summaries (`docdescribe`)

Use `docdescribe.py` for batch captions, summary sidecars, or explicitly requested local-model processing. For a targeted question, extract the relevant content and inspect rendered pages as needed. Captions and summaries are model-generated interpretations, not verbatim extracted evidence.

`docdescribe.py` requires local Ollama or llama-server with `qwen3.5:9b` by default:

```bash
scripts/docdescribe.py FILE                           # captions for candidate figure pages
scripts/docdescribe.py FILE --pages "3,22"            # target specific pages
scripts/docdescribe.py FILE --summarize               # figure captions + executive summary
scripts/docdescribe.py FILE --summary-only            # executive summary only (no image calls)
```

Writes `.describe.json` sidecar files containing cached descriptions. Inspect the requested page records and summary text, not just the exit code. Check `doc_summary.coverage`: when `truncated` is true, label the summary as partial-source coverage. Flag incomplete captions and verify important values against rendered pages; `values_untrusted` means the caption is not reliable numeric evidence. For bulk directory conversion and advanced backend options, read [batch workflows](references/batch.md).

---

PDF text and Office conversion are portable; Apple Vision OCR requires macOS and Xcode command line tools. Python dependencies are declared inline and run through `uv`; the Swift helper builds on first use. For measured engine comparisons, consult [benchmark](references/benchmark.md).
