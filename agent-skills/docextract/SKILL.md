---
name: docextract
description: Extract text, markdown, or structured JSON from documents (PDF, DOCX, PPTX, XLSX, CSV, images, HTML, EPUB) locally on macOS — no cloud, no API key, no LLM. Routes each PDF page to the most accurate engine automatically: text layers via PyMuPDF, scanned/image pages via Apple's Vision OCR, Office files via MarkItDown. Use when asked to read/parse/extract/convert a document or image, to answer questions about a document's contents, or to turn a file or a whole directory into markdown.
license: MIT
metadata:
  benchmarked: "2026-08-18, macOS 15 arm64; see references/benchmark.md"
  wins: "best-in-class on BOTH born-digital text (F1 0.9964) and scanned OCR (F1 0.9712)"
---

# docextract

One command for any local document. It picks the best engine per page instead of making you
guess, because no single engine wins everywhere — that's a measured result, not a hunch
(`references/benchmark.md`).

| input | engine | why |
|---|---|---|
| PDF page with a text layer | PyMuPDF (`pymupdf4llm` for markdown) | F1 0.9964, tied best, fastest |
| PDF page with no text layer | **Apple Vision OCR** | F1 0.9712, beats tesseract 0.9512 and liteparse 0.9000 |
| image (png/jpg/heic/tiff…) | Apple Vision OCR | same |
| DOCX / PPTX / XLSX / CSV / HTML / EPUB | MarkItDown | emits real markdown tables |

Vision OCR is built into macOS: no model download, no network, no Python, and it is both the
most accurate *and* the fastest OCR on this platform.

## Run it

The script is self-contained — [PEP 723](https://peps.python.org/pep-0723/) inline dependencies,
so `uv` installs them on first run (~1s afterwards). Nothing to set up.

```bash
SK=~/.claude/skills/docextract/scripts        # adjust if invoked from another harness
$SK/docextract.py FILE                        # -> markdown on stdout
```

If `uv` is missing: `brew install uv`. The Swift Vision helper compiles itself on first use
(needs Xcode command line tools: `xcode-select --install`); it is a build artifact and is not
checked into the repo.

## Recipe 1 — answer questions about a document

Use `--text` (highest raw fidelity, no markdown decoration) and keep the page markers so you can
cite a page number:

```bash
$SK/docextract.py contract.pdf --text                  # whole doc
$SK/docextract.py contract.pdf --text --pages "1-3,12" # just some pages
```

For long documents, `--json` gives you per-page records — read only the pages you need, and check
`engine` to know whether a page was OCR'd (OCR'd pages deserve more caution on exact figures):

```bash
$SK/docextract.py report.pdf --json -o /tmp/report.json
```

```jsonc
{ "file": "report.pdf", "pages_total": 40, "pages_done": 40,
  "ocr_pages": [7, 8],                       // these pages had no text layer
  "chars": 91234,
  "pages": [ { "page": 1, "text": "...", "engine": "pymupdf", "text_layer_chars": 3670 } ] }
```

When the question is visual — "what does the chart show?", "is the box ticked?", "what's the
layout?" — extract *and look*. Text extraction cannot answer those:

```bash
$SK/docextract.py form.pdf --screenshot /tmp/shots --pages "1" --dpi 150
# then Read /tmp/shots/page_1.png
```

Reading the rendered page is also how you verify a suspicious extraction. Do that before
reporting a number that matters.

## Recipe 2 — turn a document or a directory into markdown

```bash
$SK/docextract.py paper.pdf -o paper.md          # one file
$SK/docextract.py ~/Documents/invoices -o ./md   # whole tree, recursively
```

Directory mode mirrors the input tree, writes one `.md` per document, and prints a line per file
with the character count and how many pages needed OCR:

```
invoices/2026-01.pdf -> md/2026-01.md  (4821 chars, 0 OCR page(s))
invoices/scans/old.pdf -> md/scans/old.md  (2210 chars, 3 OCR page(s))
```

Add `--no-recursive` to stay at the top level, `--no-page-marks` to drop the
`<!-- page N (engine) -->` comments.

## Options

| flag | meaning |
|---|---|
| `--text` | plain text, markdown decoration stripped — **highest fidelity** |
| `--json` | per-page structured records (implies max-fidelity text) |
| `--pages "1-5,10"` | page selection, 1-based (PDF only) |
| `--force-ocr` | OCR every page even where a text layer exists |
| `--screenshot DIR` | render pages to PNG instead of extracting |
| `--dpi N` | screenshot DPI (default 150); OCR always renders at 300 |
| `--no-page-marks` | omit the page-marker comments |
| `--no-recursive` | do not walk subdirectories |
| `-o PATH` | output file, or output directory when the input is a directory |

Exit codes: `0` ok, `1` hard failure, `3` ran but extracted no text at all. **Check for exit 3** —
it means the document defeated every engine, which is the signal to look at a screenshot.

## Choosing the mode

- Default (markdown) is for *humans and storage*: headings and tables are reconstructed, which
  costs a little raw fidelity (F1 0.9568 vs 0.9964).
- `--text` / `--json` are for *answering questions*: nothing is reformatted, so figures and
  identifiers survive verbatim. Prefer these when you will quote or compute from the output.

## Known limits

- Vision OCR normalizes some punctuation (an em-dash may come back as `-`). Don't treat OCR'd
  punctuation as byte-exact.
- A page holding a *text layer plus text baked into an image* is treated as a text page, so the
  in-image text is not OCR'd. Use `--force-ocr` if you need it (this costs the text layer's
  exactness, so prefer running both and comparing).
- Rotated/overlapping text in figures comes out garbled by every engine tested.
- Superscripts flatten (`10^20` → `1020`). If exponents matter, check a screenshot.
- The routing threshold is 80 chars of text layer per page. A page with a tiny caption and a big
  scanned body can fall on the wrong side of it; `--force-ocr` is the override.
- Encrypted PDFs are not handled; decrypt first (`qpdf --decrypt`).

## Why not the other tools

Measured on 4 born-digital PDFs and 5 image-only PDFs with exact ground truth
(`references/benchmark.md` has the full tables and how to reproduce):

- **liteparse** (`lit`): OCR F1 0.9000 — it *lost 221 tokens* on a dense form where Vision lost 52.
  It also silently reports `fontSize: 1` and ~5×-too-small bounding boxes on WinAnsi-encoded
  fonts, drops trailing periods (`U.S.` → `U.S`) on those documents, and exits 0 with an empty
  file when OCR fails.
- **tesseract** / **ocrmypdf**: solid (0.9512 / 0.9554) but slower and beaten by Vision.
- **docling**: good accuracy (0.9501) but 15–38 s/doc, ~100× slower.
- **pdfplumber** and **markitdown** on PDFs: pdfminer drops inter-word spaces on LaTeX PDFs
  (F1 0.7338 — `Providedproperattribution…`). Fixable with `x_tolerance=1`, but MarkItDown exposes
  no such knob, so it is only used here for Office formats, where it is excellent.
- **pdftotext** is genuinely excellent for born-digital text and is a good cross-check
  (`pdftotext -layout`), but it cannot OCR.
