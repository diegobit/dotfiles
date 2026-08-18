---
name: docextract
description: Extract text, markdown, or structured JSON from documents (PDF, DOCX, PPTX, XLSX, CSV, images, HTML, EPUB) locally on macOS — no cloud, no API key, no LLM. Routes each PDF page to the most accurate engine automatically: text layers via PyMuPDF, scanned/image pages via Apple's Vision OCR, Office files via MarkItDown. Use when asked to read/parse/extract/convert a document or image, to answer questions about a document's contents, or to turn a file or a whole directory into markdown.
license: MIT
metadata:
  benchmarked: "2026-08-18, macOS 15 arm64; see references/benchmark.md"
  wins: "best-in-class on born-digital text (F1 0.9964), scanned OCR (F1 0.9712) and table cell-binding (1.00)"
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
  "ocr_pages": [7, 8],          // no text layer -> OCR'd; treat exact figures with care
  "figure_pages": [3, 22],      // hold a chart/diagram -> --screenshot and look
  "chars": 91234,
  "pages": [ { "page": 1, "text": "...", "engine": "pymupdf",
               "text_layer_chars": 3670,
               "figures": 0,
               "row_groups": [ { "label": "LAVORI", "covers": ["A1", "A2"] } ] } ] }
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
| `--image-ocr` | also OCR large images on pages that *do* have a text layer, to recover text baked into a picture (off by default — it adds lower-confidence text beside the exact text layer) |
| `--probe` | report what the document contains and which mode suits it, then exit |
| `--screenshot DIR` | render pages to PNG instead of extracting |
| `--dpi N` | screenshot DPI (default 150); OCR always renders at 300 |
| `--no-page-marks` | omit the page-marker comments |
| `--no-recursive` | do not walk subdirectories |
| `-o PATH` | output file, or output directory when the input is a directory |

Exit codes: `0` ok, `1` hard failure, `3` ran but extracted no text at all. **Check for exit 3** —
it means the document defeated every engine, which is the signal to look at a screenshot.

## Choosing the mode — don't guess, ask the document

The two table shapes want opposite modes, so a fixed rule would be wrong half the time.
Rather than remember that, **run `--probe` once** and let the document tell you:

```bash
$SK/docextract.py report.pdf --probe
```

```jsonc
{ "pages": 7,
  "scanned_pages": [],              // no text layer -> OCR'd either way
  "table_pages": [1,3,4,5,6,7],
  "stacked_header_pages": [6,7],    // markdown likely better on THESE pages
  "row_group_pages": [],            // sideways group labels -> read the row-group comments
  "figure_pages": [1],              // only vision can answer about these
  "image_text_pages": [],           // add --image-ocr to read text baked into a picture
  "recommend": "--text",
  "then_recheck_pages_with_markdown": [6,7],
  "because": ["6 ruled table page(s): --text keeps every row bound to its own value …"] }
```

The decision procedure:

1. **Start with `--text`.** It is best or tied-best on every axis measured — born-digital 0.9949,
   OCR 0.9712, table cell-binding 1.0000 — and it is the fastest. When in doubt, this is the answer.
2. **Use the default markdown mode** when you are converting *for storage or for a human*, or for
   the pages `--probe` lists in `stacked_header_pages`. Re-extract just those:
   `--pages "6,7"` without `--text`.
3. **Use `--json`** when the document is long and you want to read only some pages, or you need
   `engine` / `row_groups` / `figures` per page. Its text is the same max-fidelity text as `--text`.
4. **Use `--screenshot` and look** for anything in `figure_pages`, to confirm a
   `stacked_header_pages` flag, or whenever a row reads oddly. No text mode substitutes for this.
5. **Add `--image-ocr`** for pages in `image_text_pages` if the answer might be inside a picture.

`--probe` is a heuristic and says so: `stacked_header_pages` over-flags (a wrapped single-level
header can trip it), which is why step 2 says confirm with a screenshot rather than trusting it.

## Tables: what you get

**Rotated row-group labels.** Financial tables often print a group name sideways in the left
column, spanning the rows it governs. Every other tool tested either drops it, reverses it into
single characters, or strands it mid-table — which actively misleads, because the rows then read
as belonging to the previous group. docextract states the grouping explicitly:

```
<!-- row-group "LAVORI" covers rows: A1, A2, A) -->
<!-- row-group "SOMME A DISPOSIZIONE DELL'AMMINISTRAZIONE" covers rows: B1, B2.2, ..., B) -->
```

`--json` exposes the same thing as `row_groups` per page. **When a table has sideways labels,
read this comment before attributing any row to a group.**

**Tables spanning a page break** get an explicit `<!-- table continues from page N -->` marker in
markdown mode, and the continuation's first row is kept as data rather than being promoted to a
header.

**Spreadsheets with merged cells** are read natively (openpyxl): every cell covered by a merge
repeats its anchor's value, so each row stands alone and stacked headers stay column-aligned.
This matters — pandas-backed readers leave `NaN` (ambiguous with a genuinely empty cell) and
spatial extractors put the label at the merge's visual centre, silently binding it to the *wrong*
row (liteparse attributes an `EMEA` block spanning three rows to only its middle row).

## Figures

Pages holding a chart, diagram or photo are flagged, because text extraction cannot answer a
question about them:

```
<!-- page 22 (pymupdf4llm) — 1 figure(s), inspect with --screenshot -->
```

`--json` lists them as `figure_pages`. Charts in office documents are usually **vector graphics,
not embedded images**, so `pdfimages` finds nothing — render the page instead:

```bash
$SK/docextract.py report.pdf --screenshot /tmp/shots --pages "22" --dpi 150
# then Read /tmp/shots/page_22.png and describe the chart yourself
```

## Performance and platform

Measured on an Apple M4 Max (16 cores), warm. Directory mode fans out across processes
(`-j`, default CPU-2); single files are single-threaded.

| workload | `--text` | markdown |
|---|---|---|
| 100-page born-digital PDF | **4.8 s** (0.05 s/page) | 19.5 s (0.2 s/page) |
| real 103-page technical doc | 4.4 s (0.043 s/page) | — |
| scanned pages (every page OCR'd) | **0.86 s/page** | same |
| 1000 mixed documents / ~5 100 pages / 230 MB | **29 s** | 299 s (5 min) |
| `--probe` on a 100-page PDF | 2.9 s | — |

Process startup is ~0.03 s, so per-file overhead is negligible. Parallelism gives ~7.8× on
this machine (100 docs: 26.8 s serial → 3.4 s with 14 workers) and the output is byte-identical
to serial. Rule of thumb: **born-digital ≈ 0.05 s/page, scanned ≈ 0.9 s/page**; OCR dominates
whenever it is involved.

**Platform.** PDF text, Office formats and markdown conversion are plain Python and portable.
**OCR is macOS-only** — it uses Apple's Vision framework through a small Swift helper. On a
non-macOS host, born-digital documents work unchanged and scanned pages fail with an explicit
error rather than returning silence; supporting them elsewhere would mean wiring in `tesseract`,
which measured 0.9512 against Vision's 0.9712 on the same pages.

## Known limits

- Vision OCR normalizes some punctuation (an em-dash may come back as `-`). Don't treat OCR'd
  punctuation as byte-exact.
- A page holding a *text layer plus text baked into an image* keeps only the text layer by
  default. `--image-ocr` recovers the in-image text and appends it under an explicit
  `<!-- text found inside an image on this page (OCR) -->` marker, keeping the exact text layer
  intact; lines already covered by the text layer are dropped so the page is not duplicated.
  It is off by default because it mixes OCR guesses in beside exact text (it costs ~2 s per page
  with a full-page image, and drops token precision from 0.996 to 0.816 against a text-layer-only
  reference — the added text is real, but it is not in the reference).
- Rotated/overlapping text in figures comes out garbled by every engine tested.
- Superscripts flatten (`10^20` → `1020`). If exponents matter, check a screenshot.
- Stacked multi-level column headers (a group header over sub-columns) survive better in
  markdown mode than in `--text`; formula-ish header labels (`∑(Qi)`, `V*G*P*∑Qi`) may lose
  symbols. If the header hierarchy is the point, check a screenshot.
- Row-group detection needs ruled cells; a table that groups rows by whitespace alone will not
  produce a `row-group` comment. Detection is gated to ruled tables and to labels in the left
  quarter of the page, so rotated text in a figure is not mistaken for one.
- In `--text`, two short table rows sitting side by side can end up on one output line. Cell
  binding still holds (each value stays with its key), but check a screenshot before reading such
  a line as a single row.
- Markdown mode inherits a `pymupdf4llm` defect on wrapped table cells: words can run together
  (`direzionelavori`) and a row code can lose its dot. `--text` does not have this — another
  reason to prefer it for tables.
- The routing threshold is 80 chars of text layer per page. A page with a tiny caption and a big
  scanned body can fall on the wrong side of it; `--force-ocr` is the override.
- Encrypted PDFs are not handled; decrypt first (`qpdf --decrypt`).
- **A table pasted in as a low-resolution image is only partly recoverable.** `--image-ocr`
  returns the words but not the row-to-value binding: a 783×274 px matrix embedded in a table
  cell came back as fragments in jumbled order (`request by / by SCP / YES / failure / YES`).
  For those, `--screenshot` the page and read it. Rendering the page region at 300 dpi was
  measured to beat extracting the embedded image at native resolution, so that is what it does.
- Technical drawings yield their label text in roughly spatial order, which is usable for finding
  a tag number but not for understanding the drawing — that needs the screenshot.

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
