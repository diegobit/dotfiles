#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "pymupdf>=1.24",
#   "pymupdf4llm>=0.0.17",
#   "markitdown[docx,pptx,xlsx]>=0.1",
# ]
# ///
"""docextract — local document -> text / markdown / structured JSON on macOS.

Routes each input to the most accurate engine available (benchmarked, see the skill's
report): PDF text layers via PyMuPDF, image-only pages via Apple's Vision OCR,
Office formats via MarkItDown.

  docextract FILE...                 -> markdown to stdout
  docextract FILE -o out.md          -> markdown to a file
  docextract DIR -o outdir/          -> mirror the tree as .md files
  docextract FILE --json             -> structured JSON (per page, with OCR flags)
  docextract FILE --text             -> plain text, no markdown decoration
  docextract FILE --screenshot DIR   -> render pages to PNG (for visual inspection)

Exit codes: 0 ok, 1 hard failure, 3 produced no text at all.
"""
from __future__ import annotations

import argparse
import contextlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
VISION = os.path.join(HERE, 'vision_ocr')

PDF_EXT = {'.pdf'}
IMG_EXT = {'.png', '.jpg', '.jpeg', '.tif', '.tiff', '.bmp', '.gif', '.webp', '.heic'}
OFFICE_EXT = {'.docx', '.doc', '.pptx', '.ppt', '.xlsx', '.xls', '.csv', '.tsv',
              '.odt', '.odp', '.ods', '.rtf', '.epub', '.html', '.htm', '.xml', '.json'}
SUPPORTED = PDF_EXT | IMG_EXT | OFFICE_EXT

# A page with fewer than this many extractable chars is treated as needing OCR.
TEXT_LAYER_MIN_CHARS = 80
OCR_DPI = 300


def warn(msg):
    print(f'docextract: {msg}', file=sys.stderr)


@contextlib.contextmanager
def captured_stdout_fd():
    """Redirect file descriptor 1 to a temp file.

    PyMuPDF/pymupdf4llm emit progress banners from their C layer straight to fd 1, so a
    Python-level contextlib.redirect_stdout does not catch them; that noise would corrupt
    markdown written to stdout.
    """
    sys.stdout.flush()
    saved = os.dup(1)
    tmp = tempfile.TemporaryFile(mode='w+')
    try:
        os.dup2(tmp.fileno(), 1)
        yield tmp
    finally:
        sys.stdout.flush()
        os.dup2(saved, 1)
        os.close(saved)


def die(msg, code=1):
    warn(msg)
    sys.exit(code)


# --------------------------------------------------------------------------- OCR
def have_vision():
    return os.path.exists(VISION) and os.access(VISION, os.X_OK)


def build_vision():
    """Compile the Swift helper on first use; it is a build artifact, not checked in."""
    src = VISION + '.swift'
    if not os.path.exists(src):
        die(f'Vision OCR source missing at {src}')
    if not shutil.which('swiftc'):
        die('swiftc not found — install Xcode command line tools: xcode-select --install')
    warn('building the Vision OCR helper (first run only)...')
    r = subprocess.run(['swiftc', '-O', '-o', VISION, src], capture_output=True)
    if r.returncode != 0 or not have_vision():
        die(f'failed to build {VISION}:\n{r.stderr.decode()[-500:]}')


def vision_ocr(png_path, as_json=False):
    """Apple Vision OCR. Highest-accuracy OCR available on macOS, no deps, no network."""
    if not have_vision():
        build_vision()
    cmd = [VISION, png_path] + (['--json'] if as_json else [])
    r = subprocess.run(cmd, capture_output=True)
    if r.returncode != 0:
        warn(f'vision OCR failed on {png_path}: {r.stderr.decode()[-200:]}')
        return None
    return r.stdout.decode('utf-8', 'replace')


# ----------------------------------------------------------------------- helpers
def md_escape_keep(s):
    """Collapse runs of >2 blank lines; keep content untouched otherwise."""
    return re.sub(r'\n{3,}', '\n\n', s).strip()


def parse_pages_arg(spec, npages):
    """'1-3,7' -> [0,1,2,6] (0-based). None -> all."""
    if not spec:
        return list(range(npages))
    out = []
    for part in spec.split(','):
        part = part.strip()
        if not part:
            continue
        if '-' in part:
            a, b = part.split('-', 1)
            out.extend(range(int(a) - 1, int(b)))
        else:
            out.append(int(part) - 1)
    return [p for p in out if 0 <= p < npages]


# --------------------------------------------------------------------------- PDF
def extract_pdf(path, pages_spec=None, force_ocr=False, want='md'):
    """Returns (list_of_page_dicts, meta). Each page: {page, text, engine, chars}."""
    try:
        import pymupdf
    except ImportError:
        die('PyMuPDF is required: pip install pymupdf pymupdf4llm')

    doc = pymupdf.open(path)
    idxs = parse_pages_arg(pages_spec, doc.page_count)
    if not idxs:
        die(f'no pages selected from {path} (document has {doc.page_count})')

    # classify each page
    text_pages, ocr_pages, chars = [], [], {}
    for i in idxs:
        n = 0 if force_ocr else len((doc[i].get_text() or '').strip())
        chars[i] = n
        (ocr_pages if n < TEXT_LAYER_MIN_CHARS else text_pages).append(i)

    md_by_page = {}
    if text_pages and want == 'md':
        try:
            import pymupdf4llm
            # pymupdf4llm chats to stdout ("Using Tesseract for OCR processing."), which
            # would corrupt our markdown; capture it and re-emit on stderr.
            with captured_stdout_fd() as buf:
                chunks = pymupdf4llm.to_markdown(doc, pages=text_pages, page_chunks=True)
                buf.seek(0)
                noise = buf.read().strip()
            if noise:
                warn('pymupdf4llm: ' + ' '.join(noise.split())[:200])
            # 1.28's page_chunks metadata carries no page number, but chunks come back
            # in the order we requested, so zip them back onto text_pages.
            for pno, chunk in zip(text_pages, chunks):
                md_by_page[pno] = chunk.get('text', '')
        except ImportError:
            warn('pymupdf4llm not installed; falling back to plain text for text pages')
        except Exception as e:  # noqa: BLE001 - never let markdown extras break extraction
            warn(f'pymupdf4llm failed ({e}); falling back to plain text')

    out = []
    tmpdir = None
    try:
        for i in idxs:
            if i in ocr_pages:
                if tmpdir is None:
                    tmpdir = tempfile.mkdtemp(prefix='docextract_')
                png = os.path.join(tmpdir, f'p{i+1}.png')
                zoom = OCR_DPI / 72.0
                doc[i].get_pixmap(matrix=pymupdf.Matrix(zoom, zoom)).save(png)
                t = vision_ocr(png) or ''
                out.append({'page': i + 1, 'text': t.strip(), 'engine': 'vision-ocr',
                            'text_layer_chars': chars[i]})
            else:
                t = md_by_page.get(i)
                if t is None:
                    t = doc[i].get_text() or ''
                out.append({'page': i + 1, 'text': t.strip(),
                            'engine': 'pymupdf4llm' if i in md_by_page else 'pymupdf',
                            'text_layer_chars': chars[i]})
    finally:
        if tmpdir:
            shutil.rmtree(tmpdir, ignore_errors=True)

    meta = {'pages_total': doc.page_count, 'pages_done': len(out),
            'ocr_pages': [p + 1 for p in ocr_pages]}
    doc.close()
    return out, meta


# ------------------------------------------------------------------------ images
def extract_image(path):
    t = vision_ocr(path) or ''
    return ([{'page': 1, 'text': t.strip(), 'engine': 'vision-ocr', 'text_layer_chars': 0}],
            {'pages_total': 1, 'pages_done': 1, 'ocr_pages': [1]})


# ------------------------------------------------------------------------ office
def extract_office(path):
    """MarkItDown handles Office natively and emits real markdown tables."""
    try:
        from markitdown import MarkItDown
    except ImportError:
        die("MarkItDown is required for Office formats: pip install 'markitdown[all]'")
    txt = MarkItDown().convert(path).text_content
    return ([{'page': 1, 'text': (txt or '').strip(), 'engine': 'markitdown',
              'text_layer_chars': len(txt or '')}],
            {'pages_total': 1, 'pages_done': 1, 'ocr_pages': []})


# --------------------------------------------------------------------- top level
def extract(path, pages=None, force_ocr=False, want='md'):
    ext = os.path.splitext(path)[1].lower()
    if ext in PDF_EXT:
        return extract_pdf(path, pages, force_ocr, want)
    if ext in IMG_EXT:
        return extract_image(path)
    if ext in OFFICE_EXT:
        return extract_office(path)
    die(f'unsupported extension {ext!r} for {path}')


def render_text(pages, want, with_page_marks):
    parts = []
    for p in pages:
        if not p['text']:
            continue
        if with_page_marks:
            parts.append(f'<!-- page {p["page"]} ({p["engine"]}) -->')
        parts.append(p['text'])
    body = '\n\n'.join(parts)
    if want == 'text':
        body = re.sub(r'^\s{0,3}#{1,6}\s*', '', body, flags=re.M)
        body = re.sub(r'[*_`]{1,3}', '', body)
    return md_escape_keep(body)


def screenshot(path, outdir, pages_spec=None, dpi=150):
    import pymupdf
    os.makedirs(outdir, exist_ok=True)
    doc = pymupdf.open(path)
    made = []
    for i in parse_pages_arg(pages_spec, doc.page_count):
        z = dpi / 72.0
        dst = os.path.join(outdir, f'page_{i+1}.png')
        doc[i].get_pixmap(matrix=pymupdf.Matrix(z, z)).save(dst)
        made.append(dst)
    doc.close()
    return made


def iter_inputs(targets, recursive=True):
    for t in targets:
        if os.path.isdir(t):
            for root, _dirs, files in os.walk(t):
                for f in sorted(files):
                    if os.path.splitext(f)[1].lower() in SUPPORTED:
                        yield os.path.join(root, f)
                if not recursive:
                    break
        elif os.path.isfile(t):
            yield t
        else:
            warn(f'not found: {t}')


def main():
    ap = argparse.ArgumentParser(
        prog='docextract',
        description='Extract text/markdown/JSON from documents locally (macOS).')
    ap.add_argument('inputs', nargs='+', help='files and/or directories')
    ap.add_argument('-o', '--output', help='output file, or output DIR when input is a dir')
    ap.add_argument('--json', action='store_true', help='structured JSON instead of markdown')
    ap.add_argument('--text', action='store_true', help='plain text instead of markdown')
    ap.add_argument('--pages', help='page selection, e.g. "1-5,10" (PDF only)')
    ap.add_argument('--force-ocr', action='store_true',
                    help='OCR every page even if a text layer exists')
    ap.add_argument('--screenshot', metavar='DIR',
                    help='render pages to PNG in DIR instead of extracting')
    ap.add_argument('--dpi', type=int, default=150, help='screenshot DPI (default 150)')
    ap.add_argument('--no-page-marks', action='store_true',
                    help='omit the "<!-- page N -->" comments')
    ap.add_argument('--no-recursive', action='store_true', help='do not walk subdirectories')
    args = ap.parse_args()

    want = 'json' if args.json else ('text' if args.text else 'md')

    if args.screenshot:
        for src in iter_inputs(args.inputs, not args.no_recursive):
            if os.path.splitext(src)[1].lower() not in PDF_EXT:
                continue
            made = screenshot(src, args.screenshot, args.pages, args.dpi)
            print(f'{src}: {len(made)} page(s) -> {args.screenshot}')
        return

    files = list(iter_inputs(args.inputs, not args.no_recursive))
    if not files:
        die('no supported input files found')

    dir_mode = len(args.inputs) == 1 and os.path.isdir(args.inputs[0]) and args.output
    produced_any = False
    results = []

    for src in files:
        try:
            pages, meta = extract(src, args.pages, args.force_ocr, want)
        except SystemExit:
            raise
        except Exception as e:  # noqa: BLE001 - one bad file must not kill a batch
            warn(f'FAILED {src}: {e}')
            continue
        total_chars = sum(len(p['text']) for p in pages)
        if total_chars:
            produced_any = True
        else:
            warn(f'no text extracted from {src}')

        if want == 'json':
            results.append({'file': src, **meta, 'chars': total_chars, 'pages': pages})
            continue

        body = render_text(pages, want, not args.no_page_marks)
        if dir_mode:
            rel = os.path.relpath(src, args.inputs[0])
            dst = os.path.join(args.output, os.path.splitext(rel)[0] + '.md')
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, 'w', encoding='utf-8') as f:
                f.write(f'# {os.path.basename(src)}\n\n{body}\n')
            print(f'{src} -> {dst}  ({total_chars} chars, '
                  f'{len(meta["ocr_pages"])} OCR page(s))')
        elif args.output and len(files) == 1:
            with open(args.output, 'w', encoding='utf-8') as f:
                f.write(body + '\n')
            print(f'{src} -> {args.output}  ({total_chars} chars, '
                  f'{len(meta["ocr_pages"])} OCR page(s))', file=sys.stderr)
        else:
            if len(files) > 1:
                print(f'\n<!-- ===== {src} ===== -->\n')
            print(body)

    if want == 'json':
        out = json.dumps(results if len(results) != 1 else results[0],
                         indent=1, ensure_ascii=False)
        if args.output:
            with open(args.output, 'w', encoding='utf-8') as f:
                f.write(out + '\n')
            print(f'-> {args.output}', file=sys.stderr)
        else:
            print(out)

    if not produced_any:
        sys.exit(3)


if __name__ == '__main__':
    main()
