# Why these engines — the measurements

Benchmarked 2026-08-18 on an Apple M4 Max (macOS 15, arm64). Full write-up, method, and caveats:
`dotfiles/liteparse-exp/reports/macos-document-extraction.md`.

## Method in one paragraph

Two experiments, because a tool can be great at one and useless at the other. For **OCR**, five
pages whose text layer was already known were rendered to 300-DPI PNGs and rebuilt as **image-only
PDFs** (`pdftotext` on them returns 1 byte) — so every engine had to reconstruct, from pixels, text
already known exactly. For **born-digital** PDFs the text layer *is* the target; `pdftotext` was the
reference, so it scores 1.0 by construction — the cross-check that makes it fair is that MuPDF, a
fully independent engine, agrees with poppler to within 0.4%.

`F1` = token multiset overlap (markdown syntax stripped, so markdown emitters aren't penalized).
`order` = fraction of concordant pairs among tokens unique to both texts.

## OCR — image-only PDFs, independent ground truth (mean of 5 pages)

| tool | F1 | recall | precision | order | sec/doc |
|---|---|---|---|---|---|
| **docextract** (= Apple Vision) | **0.9712** | 0.9541 | 0.9892 | 0.9947 | 1.12 |
| unlimited-ocr (NVIDIA GB10, off-box) | 0.9638 | 0.9750 | 0.9543 | 0.9953 | ~15 |
| ocrmypdf | 0.9554 | 0.9489 | 0.9621 | 0.9930 | 3.84 |
| tesseract CLI | 0.9512 | 0.9444 | 0.9584 | 0.9928 | 1.45 |
| docling | 0.9501 | 0.9280 | 0.9747 | 0.9932 | 14.66 |
| liteparse `--dpi 300` | 0.9000 | 0.8415 | 0.9718 | 0.9919 | 1.29 |
| pymupdf4llm | 0.8784 | 0.8530 | 0.9105 | 0.9920 | 1.86 |
| liteparse (default 150 dpi) | 0.8611 | 0.7823 | 0.9735 | 0.9923 | 0.93 |

Vision is the only engine above 0.94 on all five pages. Per-page worst cases show the real gap —
on the dense IRS form liteparse missed **221** tokens where Vision missed **52**; on a numeric table
liteparse missed **111** where Vision missed **14**.

## Born-digital — recovering the text layer (mean of 4 documents)

| tool | F1 | recall | precision | sec/doc |
|---|---|---|---|---|
| pdftotext-raw *(reference, 1.0 by construction)* | 1.0000 | 1.0000 | 1.0000 | 0.04 |
| pdftotext -layout | 0.9997 | 0.9998 | 0.9996 | 0.04 |
| **docextract --text** | **0.9964** | 0.9956 | 0.9972 | **0.12** |
| mutool / pymupdf | 0.9964 | 0.9956 | 0.9972 | 0.16 / 0.41 |
| pypdf | 0.9928 | 0.9918 | 0.9939 | 0.48 |
| pdfplumber (`x_tolerance=1`) | 0.9842 | 0.9864 | 0.9820 | 0.44 |
| docextract (markdown mode) | 0.9568 | 0.9696 | 0.9447 | 1.97 |
| pymupdf4llm | 0.9385 | 0.9700 | 0.9123 | 2.38 |
| liteparse | 0.8677 | 0.9918 | 0.8278 | 0.93 |
| docling | 0.8511 | 0.9709 | 0.8167 | 38.03 |
| pdfplumber (defaults) / markitdown-on-PDF | 0.7338 | 0.6783 | 0.8416 | 0.6 / 0.55 |

## The point of the hybrid

| | born-digital | OCR |
|---|---|---|
| pymupdf / mutool / pdftotext | **0.9964–1.0** | cannot OCR |
| macos-vision | needs an image | **0.9712** |
| liteparse | 0.8677 | 0.9000 |
| docling | 0.8511 | 0.9501 (slow) |
| **docextract --text** | **0.9964** | **0.9712** |

Nothing else is top-tier on both, which is the whole reason this skill routes per page rather than
picking one engine.

## Round 2 — table cell binding (105 key->value pairs, real fee schedules)

Token overlap is blind to the failure that matters most in a table: a tool can emit every token
and still bind the wrong number to the wrong row. Row keys and values were taken from the PDF's
own word geometry, then each tool was asked whether the value stayed on its key's line.

| tool | cell binding |
|---|---|
| **docextract --text** | **1.0000** |
| docling | 1.0000 |
| liteparse | 1.0000 |
| pdftotext -layout | 1.0000 |
| docextract (markdown) | 0.9810 |
| pymupdf4llm | 0.9810 |
| pdfplumber (tuned) | 0.9619 |
| markitdown | 0.7905 |

This is why the skill says **use `--text` for tables**. It also caught a real bug here:
PyMuPDF's default `get_text()` emits block order, which scored **0.1429**; `get_text(sort=True)`
lifted it to 1.0000 and improved round-1 CER from 0.2498 to 0.1308 at unchanged token F1.

Independent vision graders (page screenshot + each tool's output) added three findings no metric
caught: rotated row-group labels are dropped, reversed or stranded mid-table by most tools
(docling and markitdown were the only ones correct); markdown emitters promote a multi-page
table's continuation row to a fake header, severing its section (8-9/20 vs 18/20 for plain-text
tools); and stacked multi-level headers invert that ranking (markdown 18/20, --text 9/20).
docextract now handles the first two explicitly.

## Mode selection

The two table shapes want opposite modes (row-per-record -> `--text` at cell binding 1.00;
stacked multi-level header -> markdown, graded 18/20 vs 9/20), so no fixed rule is right for a
document that contains both. `--probe` reports the page-level facts instead and recommends
`--text` as the base, listing which pages to re-check in markdown. The stacked-header detector is
a heuristic: it separated the stacked page (12 hits) from a simple 3-column table (3), a financial
statement (1) and a prose page (1), but it over-flags a wrapped single-level header -- confirmed
one false positive on a Gantt-style table -- so the skill tells you to confirm with a screenshot.

## Images inside PDFs

Three distinct cases, measured:

- **Page with no text layer** -> whole page rendered at 300 dpi and OCR'd with Apple Vision
  (F1 0.9712).
- **Page with a text layer plus a large image** -> by default only the text layer is read, so text
  baked into the picture is silently missed. Verified on a ticket PDF whose full-page JPEG carries
  real copy ("Picnic sul prato al tramonto...") that the default path does not return.
  `--image-ocr` renders just the image rectangles, OCRs them, drops lines already covered by the
  text layer, and appends the rest under an explicit marker. Off by default because it costs ~2 s
  per such page and drops token precision 0.996 -> 0.816 against a text-layer-only reference.
  `--probe` lists these pages as `image_text_pages`.
- **Charts and diagrams** are usually *vector*, not raster: `pdfimages` on the page holding a line
  chart returned only the header logos. Nothing can extract them as text -- render the page with
  `--screenshot` and look. `--probe` lists them as `figure_pages`.

## Things that will trip you up in other tools

- **liteparse** reports `fontSize: 1` and ~5×-too-small bounding boxes for WinAnsi-encoded fonts
  (100% of items on the IRS form), drops trailing periods (`U.S.` → `U.S`) on those documents, and
  **exits 0 with an empty file** when OCR fails.
- **markitdown on PDFs** and **pdfplumber at defaults** lose inter-word spaces on LaTeX PDFs
  (`Providedproperattributionisprovided,Google…`). pdfminer's default `x_tolerance=3` is too wide;
  `x_tolerance=1` fixes pdfplumber, but MarkItDown exposes no such knob. MarkItDown is still the
  best choice for Office formats, which is where this skill uses it.
- **liteparse and merged spreadsheet cells**: it places a merged label at the merge's *visual
  centre*, so a group spanning three rows gets bound to only the middle one -- silently wrong
  data. pandas-backed readers instead leave `NaN`, ambiguous with a genuinely empty cell.
  docextract reads .xlsx via openpyxl and repeats the anchor value across every covered cell.
- **pymupdf4llm writes progress banners to fd 1 from PyMuPDF's C layer**, which corrupts markdown
  on stdout. `contextlib.redirect_stdout` does not catch it; `os.dup2` does. Handled internally.

## Reproduce

```bash
cd dotfiles/liteparse-exp
python3 bench/run_macos.py              # every tool, records timings
.venv-tools/bin/python bench/score.py   # both tables
```

Per-document scores: `bench/scores.json`. Raw outputs: `bench/out/`.

## Caveats

Four born-digital documents and five scan pages, weighted toward LaTeX papers and one dense US tax
form. No handwriting, no non-Latin script, no photographed scans, no multi-column magazine layouts.
The scans are clean synthetic renders, so they measure transcription rather than robustness to
real-world scanning noise. Gaps of a few thousandths (0.9964 vs 0.9928) are inside the noise of a
corpus this size; the large gaps are the trustworthy signals.
