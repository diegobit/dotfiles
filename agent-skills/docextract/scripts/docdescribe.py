#!/usr/bin/env python3
"""docdescribe — visual page descriptions and document summaries via local Ollama.

Companion to `docextract.py`. Extraction stays deterministic and CPU-bound;
this script asks a local vision model about the pages text extraction cannot
answer (charts, diagrams, photos, screenshots) and summarizes extracted text.
It writes `*.describe.json` sidecars with retrieval-ready `index_text`,
request-level caching, and explicit summary coverage.

  docdescribe FILE                     describe candidate figure pages
  docdescribe FILE --pages "3,22"      describe explicit pages
  docdescribe FILE --summarize         describe pages and summarize the document
  docdescribe FILE --summary-only      summarize extracted text, no page rendering
  docdescribe DIR -o OUT               batch over a directory, mirroring the tree
  docdescribe FILE --dry-run           print the plan without inference or writes

Thinking is disabled by default (`--think off` / `--no-think`) for 4x faster
inference (~11s/page) and reliable structured output. It can be enabled
explicitly via `--think {low,medium,high}` when chain-of-thought is needed.

Exit codes: 0 ok, 1 failure.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import io
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from contextlib import contextmanager
from dataclasses import dataclass, replace
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator

# ------------------------------------------------------------------- constants

SIDECAR_SUFFIX = ".describe.json"
PROMPT_VERSION = "2026-09-13-v1"

DEFAULT_MODEL = os.environ.get("DOCDESCRIBE_MODEL") or os.environ.get("OLLAMA_MODEL") or "qwen3.5:9b"
DEFAULT_OLLAMA_URL = os.environ.get("DOCDESCRIBE_URL") or os.environ.get("OLLAMA_HOST") or "http://127.0.0.1:11434"
DEFAULT_BACKEND = os.environ.get("DOCDESCRIBE_BACKEND", "auto")
DEFAULT_THINK = os.environ.get("DOCDESCRIBE_THINK", "off")
THINK_ALIASES = {
    "off": "off",
    "none": "off",
    "false": "off",
    "no": "off",
    "0": "off",
    "low": "low",
    "med": "medium",
    "medium": "medium",
    "hi": "high",
    "high": "high",
}
THINK_LEVELS = ("off", "low", "medium", "high")
BACKEND_CHOICES = ("auto", "ollama", "llama-server")

TEMPERATURE = 0.1
NUM_CTX = 16384
NUM_PREDICT = 4096
PAGE_CONTEXT_CHARS = 2500
DOC_CONTEXT_CHARS = 12000
DEFAULT_TIMEOUT = 180.0
EXTRACT_TIMEOUT = 600
RENDER_TIMEOUT = 180
SCREENSHOT_DPI = 150
RENDER_BATCH_SIZE = 12
MAX_IMAGE_DIM = 4096

PDF_EXT = {".pdf"}
RASTER_EXT = {".png", ".jpg", ".jpeg", ".webp", ".tif", ".tiff", ".gif", ".bmp", ".heic"}
OFFICE_EXT = {".docx", ".doc", ".pptx", ".ppt", ".xlsx", ".xls", ".csv", ".tsv",
              ".odt", ".odp", ".ods", ".rtf", ".epub", ".html", ".htm", ".xml", ".json"}
SUPPORTED_EXT = PDF_EXT | RASTER_EXT | OFFICE_EXT

VISUAL_TYPES = ("chart", "diagram", "table", "photo", "screenshot",
                "signature", "decorative", "other")

JSON_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "relevant": {"type": "boolean"},
        "type": {
            "type": "string",
            "enum": list(VISUAL_TYPES),
        },
        "summary": {"type": "string"},
        "key_information": {"type": "array", "items": {"type": "string"}},
        "entities": {"type": "array", "items": {"type": "string"}},
        "important_values": {"type": "array", "items": {"type": "string"}},
        "skip_reason": {"type": "string"},
    },
    "required": ["relevant", "type", "summary", "key_information"],
}

DOC_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "summary": {"type": "string"},
        "doc_type": {"type": "string"},
        "entities": {"type": "array", "items": {"type": "string"}},
        "key_information": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["summary"],
}

IMAGE_PROMPT = """Describe the information conveyed by this page image for a document retrieval system.

Focus on information that would help answer questions about the document: relationships, trends, components, labels, quantities and conclusions.

Use the provided document context to disambiguate the image. Do not invent information that is not supported by either the image or the context.

Do not describe visual styling unless it carries meaning.
Do not repeat surrounding text unless it helps explain the image.
Do not use this pass as generic OCR: extracted text is already in context. Read labels or values that exist only in the image when they are needed to understand it.

Logo, letterhead, or decoration with no information: relevant=false, type=decorative.
Photo: short semantic summary only.
Screenshot of software/UI: what it shows, states, dates, actors.
Diagram: components and relations.
Chart: axes, series, trends, comparisons, apparent values/conclusions.
Table already extracted as text: relevant=false, type=table, skip_reason=structured_text_already_extracted — unless the image adds structure the text lost.

important_values are apparent readings from the image. They are for retrieval, not verified facts.

Reply with JSON only, matching the schema."""

DOC_PROMPT = """Summarize this extracted document for a retrieval system.

5–8 sentences: document type, organization, request/practice ids if present, dates, what the document is for.
Do not invent amounts. If a figure appears in the extract, you may mention it only as stated in the text, with the page if known.
Ignore letterhead noise.

Reply with JSON only, matching the schema."""


def warn(msg: str) -> None:
    print(f"docdescribe: {msg}", file=sys.stderr)


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def normalize_think(value: Any) -> str:
    """Map CLI spellings onto supported thinking levels (off, low, medium, high)."""
    if isinstance(value, bool):
        return "low" if value else "off"
    level = THINK_ALIASES.get(str(value).strip().lower())
    if level is None:
        raise ValueError(
            f"unsupported thinking level {value!r}; use one of: {', '.join(THINK_LEVELS)}")
    return level


DEFAULT_LLAMA_SERVER_URL = os.environ.get("LLAMA_SERVER_URL", "http://127.0.0.1:8080")


def resolve_backend_and_url(
    backend: str | None = None,
    url: str | None = None,
) -> tuple[str, str]:
    """Resolve backend ('ollama' | 'llama-server') and full chat endpoint together."""
    raw_b = (backend or os.environ.get("DOCDESCRIBE_BACKEND") or "auto").strip().lower()
    candidate_url = (url or os.environ.get("DOCDESCRIBE_URL") or "").strip().rstrip("/")

    explicit_backend: str | None = None
    if raw_b in ("ollama", "llama-server"):
        explicit_backend = raw_b
    elif raw_b in ("llama.cpp", "llama_server", "llamacpp", "v1"):
        explicit_backend = "llama-server"

    target_backend = explicit_backend
    if candidate_url:
        import urllib.parse
        parsed = urllib.parse.urlsplit(candidate_url if "://" in candidate_url else "//" + candidate_url)
        path = parsed.path.rstrip("/")
        try:
            port = parsed.port
        except ValueError:
            port = None
        if target_backend is None:
            if port == 8080 or path.endswith("/v1") or path.endswith("/chat/completions") or "/v1/" in path:
                target_backend = "llama-server"
            elif port == 11434 or path.endswith("/api") or path.endswith("/api/chat") or "/api/" in path:
                target_backend = "ollama"

    if target_backend is None:
        if os.environ.get("LLAMA_SERVER_URL"):
            target_backend = "llama-server"
        else:
            target_backend = "ollama"

    chosen_url = candidate_url
    if not chosen_url:
        if target_backend == "llama-server":
            chosen_url = os.environ.get("LLAMA_SERVER_URL") or DEFAULT_LLAMA_SERVER_URL
        else:
            chosen_url = os.environ.get("OLLAMA_HOST") or DEFAULT_OLLAMA_URL

    if "://" not in chosen_url:
        chosen_url = "http://" + chosen_url
    chosen_url = chosen_url.rstrip("/")

    if target_backend == "llama-server":
        if chosen_url.endswith("/chat/completions"):
            endpoint = chosen_url
        elif chosen_url.endswith("/v1"):
            endpoint = chosen_url + "/chat/completions"
        else:
            endpoint = chosen_url + "/v1/chat/completions"
    else:
        if chosen_url.endswith("/api/chat"):
            endpoint = chosen_url
        elif chosen_url.endswith("/api"):
            endpoint = chosen_url + "/chat"
        else:
            endpoint = chosen_url + "/api/chat"

    return target_backend, endpoint


def normalize_backend(backend: str | None, url: str | None = None) -> str:
    """Resolve backend selection ('ollama' vs 'llama-server')."""
    return resolve_backend_and_url(backend, url)[0]


def normalize_ollama_url(url: str | None = None, backend: str = "ollama") -> str:
    """Accept a host, base URL, or full chat endpoint; return the appropriate endpoint URL."""
    return resolve_backend_and_url(backend, url)[1]


# -------------------------------------------------------------------- errors


class DocDescribeError(RuntimeError):
    """Base class; RuntimeError so callers can treat failures generically."""


class UnsupportedInputError(DocDescribeError):
    pass


class PageSelectionError(DocDescribeError):
    pass


class ExtractionError(DocDescribeError):
    pass


class RenderError(DocDescribeError):
    pass


class SidecarError(DocDescribeError):
    pass


class OllamaUnreachableError(DocDescribeError):
    pass


class ModelNotFoundError(DocDescribeError):
    pass


class TruncatedOutputError(DocDescribeError):
    pass


class InvalidResponseError(DocDescribeError):
    pass


# ------------------------------------------------------------------ caching


def schema_digest(schema: dict[str, Any]) -> str:
    canonical = json.dumps(schema, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256_bytes(canonical.encode("utf-8"))


def canonical_cache_key(
    task_kind: str,
    image_bytes: bytes | None,
    messages_text: str,
    schema: dict[str, Any],
    prompt_version: str,
    model: str,
    think: str,
    temperature: float,
    context_chars: int,
    backend: str = "ollama",
) -> str:
    """SHA256 over the canonical request parameters (design §7)."""
    canonical = {
        "task_kind": task_kind,
        "image_sha256": sha256_bytes(image_bytes) if image_bytes else "",
        "messages_text": messages_text,
        "schema_digest": schema_digest(schema),
        "prompt_version": prompt_version,
        "model_tag": model,
        "think": think,
        "temperature": temperature,
        "context_chars": context_chars,
        "backend": backend,
    }
    blob = json.dumps(canonical, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256_bytes(blob.encode("utf-8"))


# ---------------------------------------------------------------- extraction


def locate_docextract() -> Path:
    """Sibling script first; PATH only when the sibling is absent (design §2)."""
    sibling = Path(__file__).resolve().parent / "docextract.py"
    if sibling.exists():
        return sibling
    found = shutil.which("docextract")
    if found:
        return Path(found)
    raise DocDescribeError(
        f"docextract.py not found next to {Path(__file__).name} and no 'docextract' on PATH")


def _run(argv: list[str], timeout: float) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        raise DocDescribeError(f"timed out after {timeout:g}s: {' '.join(argv)}") from exc
    except OSError as exc:
        raise DocDescribeError(f"failed to run {argv[0]}: {exc}") from exc


def run_extraction(docextract: Path, source: Path, timeout: float = EXTRACT_TIMEOUT) -> dict[str, Any]:
    """`docextract FILE --json`; exit 3 (no text) still yields a valid record."""
    cp = _run([str(docextract), str(source), "--json"], timeout)
    if cp.returncode not in (0, 3):
        raise ExtractionError(
            f"docextract failed ({cp.returncode}) for {source}: {(cp.stderr or '').strip()[-400:]}")
    out = (cp.stdout or "").strip()
    if not out:
        raise ExtractionError(f"docextract produced no JSON for {source}: {(cp.stderr or '').strip()[-400:]}")
    try:
        data = json.loads(out)
    except json.JSONDecodeError as exc:
        raise ExtractionError(f"docextract JSON is not parseable for {source}: {exc}") from exc
    return validate_extract_record(data, source)


def load_extract_file(path: Path) -> dict[str, Any]:
    path = Path(path)
    if not path.is_file():
        raise ExtractionError(f"extract JSON not found: {path}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ExtractionError(f"extract JSON is not parseable: {path}: {exc}") from exc
    return validate_extract_record(data, path)


def validate_extract_record(data: Any, origin: Path) -> dict[str, Any]:
    if not isinstance(data, dict) or not isinstance(data.get("pages"), list):
        raise ExtractionError(f"not a docextract document record: {origin}")
    for page in data["pages"]:
        if not isinstance(page, dict) or not isinstance(page.get("page"), int):
            raise ExtractionError(f"malformed page record in {origin}")
    if data.get("pages_total") is None:
        data["pages_total"] = len(data["pages"])
    return data


# -------------------------------------------------------------------- pages


def parse_pages_spec(spec: str) -> list[int]:
    """'1,3,5-8' -> [1,3,5,6,7,8]; strict, deduplicated, sorted, 1-indexed."""
    if spec is None or not str(spec).strip():
        raise PageSelectionError("empty page selection")
    pages: list[int] = []
    for part in str(spec).split(","):
        part = part.strip()
        if not part:
            continue
        try:
            if "-" in part:
                a, b = part.split("-", 1)
                start, end = int(a), int(b)
                if start < 1 or end < 1:
                    raise ValueError
                if start > end:
                    raise ValueError
                pages.extend(range(start, end + 1))
            else:
                value = int(part)
                if value < 1:
                    raise ValueError
                pages.append(value)
        except ValueError as exc:
            raise PageSelectionError(f"invalid page selection {part!r}") from exc
    if not pages:
        raise PageSelectionError(f"empty page selection {spec!r}")
    return sorted(set(pages))


def validate_pages(spec: str, pages_total: int) -> list[int]:
    pages = parse_pages_spec(spec)
    out_of_range = [p for p in pages if p > pages_total]
    if out_of_range:
        raise PageSelectionError(
            f"page(s) {out_of_range} out of range (document has {pages_total} page(s))")
    return pages


def page_record(extract: dict[str, Any] | None, page: int) -> dict[str, Any]:
    for item in (extract or {}).get("pages") or []:
        if item.get("page") == page:
            return item
    return {}


def surrounding_text(extract: dict[str, Any] | None, page: int,
                     context_chars: int = PAGE_CONTEXT_CHARS) -> str:
    """Target page plus neighbours, trimmed to the context budget."""
    pages = (extract or {}).get("pages") or []
    by_number = {p.get("page"): p for p in pages}
    chunks: list[str] = []
    for n in (page - 1, page, page + 1):
        text = ((by_number.get(n) or {}).get("text") or "").strip()
        if text:
            chunks.append(f"[page {n}]\n{text}")
    joined = "\n\n".join(chunks)
    if len(joined) <= context_chars:
        return joined
    target = ((by_number.get(page) or {}).get("text") or "").strip()
    return f"[page {page}]\n{target[: max(0, context_chars - 80)]}"


def document_text_blob(extract: dict[str, Any] | None,
                       context_chars: int = DOC_CONTEXT_CHARS) -> tuple[str, dict[str, Any]]:
    """Full-page text blob plus explicit coverage metadata (design §6)."""
    parts: list[str] = []
    extracted = 0
    summarized = 0
    budget = context_chars
    truncated = False
    for item in (extract or {}).get("pages") or []:
        text = (item.get("text") or "").strip()
        if not text:
            continue
        extracted += len(text)
        if truncated:
            continue
        marker = f"[page {item.get('page')}]\n"
        separator = "\n\n" if parts else ""
        block = marker + text
        if len(separator) + len(block) <= budget:
            parts.append(block)
            budget -= len(separator) + len(block)
            summarized += len(text)
        else:
            room = budget - len(separator) - len(marker)
            if room > 0:
                parts.append(marker + text[:room])
                summarized += room
            truncated = True
            budget = 0
    blob = "\n\n".join(parts)
    coverage = {
        "chars_extracted": extracted,
        "chars_summarized": summarized,
        "truncated": truncated,
    }
    return blob, coverage


def text_blob(text: str, context_chars: int = DOC_CONTEXT_CHARS) -> tuple[str, dict[str, Any]]:
    stripped = (text or "").strip()
    used = stripped[:context_chars]
    coverage = {
        "chars_extracted": len(stripped),
        "chars_summarized": len(used),
        "truncated": len(stripped) > context_chars,
    }
    return used, coverage


# ---------------------------------------------------------------- rendering


@contextmanager
def screenshot_workdir(keep_dir: Path | None, source_relpath: str) -> Iterator[Path]:
    """Per-document screenshot directory; removed on exit unless retained."""
    if keep_dir:
        work = Path(keep_dir) / source_relpath
        work.mkdir(parents=True, exist_ok=True)
        yield work
    else:
        with tempfile.TemporaryDirectory(prefix="docdescribe_") as tmp:
            yield Path(tmp)


def render_page_images(docextract: Path, source: Path, pages: list[int], outdir: Path,
                       dpi: int = SCREENSHOT_DPI, timeout: float = RENDER_TIMEOUT) -> dict[int, Path]:
    """Render all requested pages in bounded batches through `docextract --screenshot`."""
    outdir.mkdir(parents=True, exist_ok=True)
    order = sorted(set(pages))
    for start in range(0, len(order), RENDER_BATCH_SIZE):
        batch = order[start:start + RENDER_BATCH_SIZE]
        spec = ",".join(str(p) for p in batch)
        cp = _run([str(docextract), str(source), "--screenshot", str(outdir),
                   "--pages", spec, "--dpi", str(dpi)], timeout)
        if cp.returncode != 0:
            raise RenderError(
                f"docextract --screenshot failed ({cp.returncode}) for {source} pages {spec}: "
                f"{(cp.stderr or '').strip()[-400:]}")
    rendered: dict[int, Path] = {}
    for page in order:
        path = outdir / f"page_{page}.png"
        if not path.exists():
            raise RenderError(f"docextract did not render page {page} of {source}")
        rendered[page] = path
    return rendered


def gif_frame_count(path: Path) -> int:
    """Count image descriptors in a GIF; >1 means animated (rejected in v1)."""
    data = path.read_bytes()
    if len(data) < 13 or not data.startswith(b"GIF8"):
        return 1
    i = 13
    if data[10] & 0x80:  # global color table present
        i += 3 * (2 ** ((data[10] & 0x07) + 1))
    frames = 0
    while i < len(data):
        block = data[i]
        if block == 0x3B:  # trailer
            break
        if block == 0x21:  # extension: label + sub-blocks
            i += 2
            while i < len(data):
                size = data[i]
                i += 1
                if size == 0:
                    break
                i += size
        elif block == 0x2C:  # image descriptor
            frames += 1
            if frames > 1:
                return frames
            flags = data[i + 9] if i + 9 < len(data) else 0
            i += 10  # descriptor (9 bytes) + packed flags
            if flags & 0x80:  # local color table
                i += 3 * (2 ** ((flags & 0x07) + 1))
            i += 1  # LZW minimum code size
            while i < len(data):
                size = data[i]
                i += 1
                if size == 0:
                    break
                i += size
        else:
            break
    return max(frames, 1)


def tiff_page_count(path: Path) -> int:
    """Follow the TIFF IFD chain; >1 means multipage (rejected in v1)."""
    data = path.read_bytes()
    if len(data) < 8:
        return 1
    if data[:2] == b"II":
        endian = "<"
    elif data[:2] == b"MM":
        endian = ">"
    else:
        return 1
    if struct.unpack(endian + "H", data[2:4])[0] != 42:
        return 1
    offset = struct.unpack(endian + "I", data[4:8])[0]
    count = 0
    seen: set[int] = set()
    while offset and offset not in seen and offset + 2 <= len(data):
        seen.add(offset)
        count += 1
        if count > 1:
            return count
        entries = struct.unpack(endian + "H", data[offset:offset + 2])[0]
        next_pos = offset + 2 + entries * 12
        if next_pos + 4 > len(data):
            break
        offset = struct.unpack(endian + "I", data[next_pos:next_pos + 4])[0]
    return max(count, 1)


def normalize_raster_image(source: Path, workdir: Path) -> Path:
    """Logical page 1 for a raster input: validate frame/page count, normalize format."""
    ext = source.suffix.lower()
    if ext == ".gif" and gif_frame_count(source) > 1:
        raise UnsupportedInputError(
            f"animated GIF is not supported in v1 ({source}); export a still frame as PNG")
    if ext in (".tif", ".tiff") and tiff_page_count(source) > 1:
        raise UnsupportedInputError(
            f"multipage TIFF is not supported in v1 ({source}); export the page as PNG")
    workdir.mkdir(parents=True, exist_ok=True)
    dest = workdir / "page_1.png"
    if ext == ".png":
        shutil.copyfile(source, dest)
        return dest
    try:
        from PIL import Image  # type: ignore[import-not-found]
    except ImportError:
        Image = None
    if Image is not None:
        with Image.open(source) as image:
            image.convert("RGB").save(dest, format="PNG")
        return dest
    if _convert_with_sips(source, dest):
        return dest
    if ext in (".jpg", ".jpeg"):
        raw = workdir / "page_1.jpg"
        shutil.copyfile(source, raw)
        return raw
    raise UnsupportedInputError(
        f"cannot normalize {ext} without Pillow or sips; convert it to PNG first")


def _convert_with_sips(source: Path, dest: Path) -> bool:
    sips = shutil.which("sips")
    if not sips:
        return False
    cp = _run([sips, "-s", "format", "png", str(source), "--out", str(dest)], timeout=60)
    return cp.returncode == 0 and dest.exists()


def load_image_bytes(path: Path, max_dim: int = MAX_IMAGE_DIM) -> bytes:
    """Read an image, capping the long edge to bound VLM memory spikes."""
    try:
        from PIL import Image  # type: ignore[import-not-found]
    except ImportError:
        Image = None
    if Image is not None:
        with Image.open(path) as image:
            image = image.convert("RGB")
            image.thumbnail((max_dim, max_dim))
            buf = io.BytesIO()
            image.save(buf, format="PNG")
            return buf.getvalue()
    sips = shutil.which("sips")
    if sips:
        capped = path.with_name(path.stem + ".capped.png")
        cp = _run([sips, "--resampleHeightWidthMax", str(max_dim),
                   "-s", "format", "png", str(path), "--out", str(capped)], timeout=120)
        if cp.returncode == 0 and capped.exists():
            data = capped.read_bytes()
            capped.unlink(missing_ok=True)
            return data
    return path.read_bytes()


def page_image(source: Path, page: int, workdir: Path, docextract: Path | None = None) -> Path:
    """Rendered or normalized page image for one logical page."""
    if classify_input(source) == "raster":
        if page != 1:
            raise PageSelectionError(f"raster images only have logical page 1 ({source})")
        return normalize_raster_image(source, workdir)
    return render_page_images(docextract or locate_docextract(), source, [page], workdir)[page]


# -------------------------------------------------------------------- ollama


def ollama_chat(
    prompt: str,
    image: bytes | None = None,
    schema: dict[str, Any] | None = None,
    *,
    think: str = DEFAULT_THINK,
    model: str = DEFAULT_MODEL,
    url: str | None = None,
    backend: str = DEFAULT_BACKEND,
    timeout: float = DEFAULT_TIMEOUT,
    temperature: float = TEMPERATURE,
) -> dict[str, Any]:
    """One non-streaming chat call; returns the parsed JSON object across Ollama or llama-server."""
    resolved_backend, endpoint = resolve_backend_and_url(backend, url)
    try:
        think_level = normalize_think(think)
    except ValueError as exc:
        raise DocDescribeError(str(exc)) from exc

    effective_schema = schema if schema is not None else JSON_SCHEMA

    if resolved_backend == "llama-server":
        user_content: Any
        if image is not None:
            b64_img = base64.b64encode(image).decode("ascii")
            user_content = [
                {"type": "text", "text": prompt},
                {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{b64_img}"}},
            ]
        else:
            user_content = prompt

        body: dict[str, Any] = {
            "model": model,
            "messages": [{"role": "user", "content": user_content}],
            "response_format": {
                "type": "json_object",
                "schema": effective_schema,
            },
            "temperature": temperature,
            "max_tokens": NUM_PREDICT,
            "chat_template_kwargs": {"enable_thinking": think_level != "off"},
        }
        if think_level != "off":
            body["reasoning_effort"] = think_level
    else:  # ollama
        message: dict[str, Any] = {"role": "user", "content": prompt}
        if image is not None:
            message["images"] = [base64.b64encode(image).decode("ascii")]
        body = {
            "model": model,
            "think": False if think_level == "off" else think_level,
            "stream": False,
            "format": effective_schema,
            "options": {
                "temperature": temperature,
                "num_ctx": NUM_CTX,
                "num_predict": NUM_PREDICT,
            },
            "messages": [message],
        }

    request = urllib.request.Request(
        endpoint,
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            if resolved_backend == "llama-server":
                raise ModelNotFoundError(
                    f"Model '{model}' or endpoint not found at {endpoint}") from exc
            raise ModelNotFoundError(
                f"Model '{model}' not found at {endpoint}. Pull it with: ollama pull {model}") from exc
        raise DocDescribeError(f"HTTP {exc.code} at {endpoint}: {exc.reason}") from exc
    except urllib.error.URLError as exc:
        if resolved_backend == "llama-server":
            raise OllamaUnreachableError(
                f"llama-server is not reachable at {endpoint}. Start it or verify URL") from exc
        raise OllamaUnreachableError(
            f"Ollama is not reachable at {endpoint}. Start it with: ollama serve") from exc
    except json.JSONDecodeError as exc:
        raise InvalidResponseError(f"Server returned malformed HTTP JSON: {exc}") from exc

    if not isinstance(payload, dict):
        raise InvalidResponseError("Server response is not a JSON object")

    if resolved_backend == "llama-server":
        choices = payload.get("choices")
        if not isinstance(choices, list) or not choices:
            raise InvalidResponseError(f"llama-server response missing choices: {json.dumps(payload)[:300]}")
        choice = choices[0]
        if not isinstance(choice, dict):
            raise InvalidResponseError(f"llama-server choice is not an object: {json.dumps(payload)[:300]}")
        if choice.get("finish_reason") == "length":
            raise TruncatedOutputError(
                f"llama-server output reached the token limit (max_tokens={NUM_PREDICT}); "
                "description rejected as truncated")
        response_message = choice.get("message")
        if not isinstance(response_message, dict):
            raise InvalidResponseError(f"llama-server message is not an object: {json.dumps(payload)[:300]}")
        content = response_message.get("content")
        if not isinstance(content, str):
            raise InvalidResponseError(f"llama-server message content is not a string: {json.dumps(payload)[:300]}")
        content = content.strip()
        if not content:
            raise InvalidResponseError(f"empty llama-server response: {json.dumps(payload)[:300]}")
    else:  # ollama
        if payload.get("done_reason") == "length":
            raise TruncatedOutputError(
                f"Ollama output reached the token limit (num_predict={NUM_PREDICT}); "
                "description rejected as truncated")
        response_message = payload.get("message")
        if not isinstance(response_message, dict):
            raise InvalidResponseError(f"Ollama message is not an object: {json.dumps(payload)[:300]}")
        content = response_message.get("content")
        if content is not None and not isinstance(content, str):
            raise InvalidResponseError(f"Ollama message content is not a string: {json.dumps(payload)[:300]}")
        content = (content or "").strip()
        if not content:
            # Documented fallback: some vision models emit the JSON in `thinking` when
            # thinking is active and leave `content` empty.
            thinking = response_message.get("thinking")
            if isinstance(thinking, str):
                content = thinking.strip()
        if not content:
            raise InvalidResponseError(f"empty Ollama response: {json.dumps(payload)[:300]}")

    return parse_json_object(content)


def parse_json_object(content: str) -> dict[str, Any]:
    text = content.strip()
    if text.startswith("```"):
        text = re.sub(r"^```[A-Za-z0-9_-]*\s*", "", text)
        text = re.sub(r"\s*```$", "", text).strip()
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError as exc:
        raise InvalidResponseError(f"non-JSON Ollama output: {content[:300]}") from exc
    if not isinstance(parsed, dict):
        raise InvalidResponseError(f"Ollama output is not a JSON object: {content[:300]}")
    return parsed


# ---------------------------------------------------------------- validation


def _require(payload: dict[str, Any], key: str, kind: str) -> Any:
    if key not in payload:
        raise InvalidResponseError(f"missing required field {key!r}")
    return _check_type(payload[key], key, kind)


def _optional(payload: dict[str, Any], key: str, kind: str, default: Any) -> Any:
    if key not in payload:
        return default
    return _check_type(payload[key], key, kind)


def _check_type(value: Any, key: str, kind: str) -> Any:
    if kind == "bool":
        if type(value) is not bool:
            raise InvalidResponseError(f"field {key!r} must be a boolean, got {type(value).__name__}")
    elif kind == "str":
        if not isinstance(value, str):
            raise InvalidResponseError(f"field {key!r} must be a string, got {type(value).__name__}")
    elif kind == "str_list":
        if not isinstance(value, list) or any(not isinstance(item, str) for item in value):
            raise InvalidResponseError(f"field {key!r} must be a list of strings")
    return value


def validate_page_payload(payload: Any) -> dict[str, Any]:
    """Strict application-side validation of the page schema."""
    if not isinstance(payload, dict):
        raise InvalidResponseError("page response is not a JSON object")
    relevant = _require(payload, "relevant", "bool")
    visual_type = _require(payload, "type", "str")
    if visual_type not in VISUAL_TYPES:
        raise InvalidResponseError(
            f"invalid visual type {visual_type!r}; expected one of: {', '.join(VISUAL_TYPES)}")
    return {
        "relevant": relevant,
        "type": visual_type,
        "summary": _require(payload, "summary", "str"),
        "key_information": list(_require(payload, "key_information", "str_list")),
        "entities": list(_optional(payload, "entities", "str_list", [])),
        "important_values": list(_optional(payload, "important_values", "str_list", [])),
        "skip_reason": _optional(payload, "skip_reason", "str", ""),
    }


def validate_doc_payload(payload: Any) -> dict[str, Any]:
    """Strict application-side validation of the document schema."""
    if not isinstance(payload, dict):
        raise InvalidResponseError("document response is not a JSON object")
    return {
        "summary": _require(payload, "summary", "str"),
        "doc_type": _optional(payload, "doc_type", "str", ""),
        "entities": list(_optional(payload, "entities", "str_list", [])),
        "key_information": list(_optional(payload, "key_information", "str_list", [])),
    }


def index_text_for(entry: dict[str, Any], page: int) -> str:
    if not entry.get("relevant"):
        return ""
    lines = [f"[visual p.{page} type={entry.get('type')}]", entry.get("summary") or ""]
    for item in entry.get("key_information") or []:
        lines.append(f"- {item}")
    return "\n".join(line for line in lines if line and line.strip())


# ------------------------------------------------------------------- sidecar


def default_sidecar(source_relpath: str, model: str, prompt_version: str) -> dict[str, Any]:
    return {
        "source_relpath": source_relpath,
        "model": model,
        "prompt_version": prompt_version,
        "doc_summary": None,
        "pages": [],
    }


def load_sidecar(path: Path | None, source_relpath: str, model: str,
                 prompt_version: str) -> dict[str, Any]:
    if path is None or not Path(path).is_file():
        return default_sidecar(source_relpath, model, prompt_version)
    path = Path(path)
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        warn(f"ignoring malformed sidecar {path}: {exc}")
        return default_sidecar(source_relpath, model, prompt_version)
    if not isinstance(data, dict):
        warn(f"ignoring sidecar with non-object JSON: {path}")
        return default_sidecar(source_relpath, model, prompt_version)
    data.setdefault("pages", [])
    data.setdefault("doc_summary", None)
    data["source_relpath"] = data.get("source_relpath") or source_relpath
    data.setdefault("model", model)
    data.setdefault("prompt_version", prompt_version)
    return data


def page_entry(sidecar: dict[str, Any], page: int) -> dict[str, Any] | None:
    for item in sidecar.get("pages") or []:
        if item.get("page") == page:
            return item
    return None


def upsert_page(sidecar: dict[str, Any], entry: dict[str, Any]) -> None:
    pages = sidecar.setdefault("pages", [])
    for i, existing in enumerate(pages):
        if existing.get("page") == entry["page"]:
            pages[i] = entry
            return
    pages.append(entry)
    pages.sort(key=lambda item: item.get("page") or 0)


def save_sidecar_atomic(path: Path, data: dict[str, Any]) -> None:
    """Temporary sibling + os.replace; partial files never reach readers."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=2, ensure_ascii=False)
            handle.write("\n")
        os.replace(tmp_name, path)
    except BaseException:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise


def resolve_sidecar_path(source: Path, out_dir: Path | None, base_dir: Path | None) -> Path:
    name = source.name + SIDECAR_SUFFIX
    if out_dir is None:
        return source.with_name(name)
    if base_dir is not None:
        try:
            rel = source.relative_to(base_dir)
        except ValueError:
            rel = Path(source.name)
    else:
        rel = Path(source.name)
    return Path(out_dir) / (str(rel) + SIDECAR_SUFFIX)


# ------------------------------------------------------------------ prompts


def build_image_prompt(source_relpath: str, page: int, context: str) -> str:
    return (
        f"{IMAGE_PROMPT}\n\n"
        f"Document filename: {Path(source_relpath).name}\n"
        f"Source path: {source_relpath}\n"
        f"Page: {page}\n\n"
        f"Extracted text near this page:\n{context.strip() or '(no extracted text)'}\n"
    )


def build_doc_prompt(source_relpath: str, blob: str) -> str:
    return (
        f"{DOC_PROMPT}\n\n"
        f"Filename: {Path(source_relpath).name}\n"
        f"Source path: {source_relpath}\n\n"
        f"Extract:\n{blob.strip() or '(no extracted text)'}\n"
    )


# ------------------------------------------------------------- per-document


def describe_page(
    *,
    source_relpath: str,
    page: int,
    image_bytes: bytes,
    extract: dict[str, Any] | None,
    sidecar: dict[str, Any],
    sidecar_path: Path | None = None,
    model: str = DEFAULT_MODEL,
    think: str = DEFAULT_THINK,
    backend: str = DEFAULT_BACKEND,
    ollama_url: str | None = None,
    timeout: float = DEFAULT_TIMEOUT,
    prompt_version: str = PROMPT_VERSION,
    temperature: float = TEMPERATURE,
    context_chars: int = PAGE_CONTEXT_CHARS,
    force: bool = False,
) -> dict[str, Any]:
    """Describe one page, updating the sidecar only on a cache miss."""
    resolved_backend = normalize_backend(backend, ollama_url)
    context = surrounding_text(extract, page, context_chars)
    prompt = build_image_prompt(source_relpath, page, context)
    key = canonical_cache_key("page", image_bytes, prompt, JSON_SCHEMA, prompt_version,
                              model, think, temperature, context_chars, resolved_backend)
    existing = page_entry(sidecar, page)
    if existing and existing.get("cache_key") == key and not force:
        return {"cached": True, "wall_seconds": 0.0, **existing}

    started = time.perf_counter()
    parsed = ollama_chat(prompt, image_bytes, JSON_SCHEMA, think=think, model=model,
                         url=ollama_url, backend=resolved_backend, timeout=timeout,
                         temperature=temperature)
    wall = round(time.perf_counter() - started, 3)
    fields = validate_page_payload(parsed)
    entry: dict[str, Any] = {
        "page": page,
        "cache_key": key,
        "image_sha256": sha256_bytes(image_bytes),
        **fields,
        "values_untrusted": True,
        "model": model,
        "prompt_version": prompt_version,
        "think": think,
        "wall_seconds": wall,
        "described_at": utc_now(),
    }
    if entry["type"] == "table" and not entry["relevant"] and not entry["skip_reason"]:
        entry["skip_reason"] = "structured_text_already_extracted"
    entry["index_text"] = index_text_for(entry, page)
    upsert_page(sidecar, entry)
    sidecar["model"] = model
    sidecar["prompt_version"] = prompt_version
    if sidecar_path is not None:
        sidecar["updated_at"] = utc_now()
        save_sidecar_atomic(sidecar_path, sidecar)
    return {"cached": False, "wall_seconds": wall, **entry}


def summarize_document(
    *,
    source_relpath: str,
    sidecar: dict[str, Any],
    sidecar_path: Path | None = None,
    extract: dict[str, Any] | None = None,
    text: str | None = None,
    model: str = DEFAULT_MODEL,
    think: str = DEFAULT_THINK,
    backend: str = DEFAULT_BACKEND,
    ollama_url: str | None = None,
    timeout: float = DEFAULT_TIMEOUT,
    prompt_version: str = PROMPT_VERSION,
    temperature: float = TEMPERATURE,
    context_chars: int = DOC_CONTEXT_CHARS,
    force: bool = False,
) -> dict[str, Any] | None:
    """Summarize the extracted text; None when there is no text to summarize."""
    resolved_backend = normalize_backend(backend, ollama_url)
    if extract is not None:
        blob, coverage = document_text_blob(extract, context_chars)
    else:
        blob, coverage = text_blob(text or "", context_chars)
    if coverage["chars_extracted"] == 0:
        return None
    prompt = build_doc_prompt(source_relpath, blob)
    key = canonical_cache_key("doc_summary", b"", prompt, DOC_SCHEMA, prompt_version,
                              model, think, temperature, context_chars, resolved_backend)
    existing = sidecar.get("doc_summary") or {}
    if existing.get("cache_key") == key and not force:
        return {"cached": True, "wall_seconds": 0.0, **existing}

    started = time.perf_counter()
    parsed = ollama_chat(prompt, None, DOC_SCHEMA, think=think, model=model,
                         url=ollama_url, backend=resolved_backend, timeout=timeout,
                         temperature=temperature)
    wall = round(time.perf_counter() - started, 3)
    fields = validate_doc_payload(parsed)
    summary = {
        "cache_key": key,
        **fields,
        "coverage": coverage,
        "model": model,
        "prompt_version": prompt_version,
        "think": think,
        "wall_seconds": wall,
        "described_at": utc_now(),
    }
    sidecar["doc_summary"] = summary
    sidecar["model"] = model
    sidecar["prompt_version"] = prompt_version
    if sidecar_path is not None:
        sidecar["updated_at"] = utc_now()
        save_sidecar_atomic(sidecar_path, sidecar)
    return {"cached": False, "wall_seconds": wall, **summary}


# ------------------------------------------------------------------ top level


@dataclass
class Options:
    out: Path | None = None
    pages: str | None = None
    summarize: bool = False
    summary_only: bool = False
    all_pages: bool = False
    extract_json: Path | None = None
    keep_shots: Path | None = None
    model: str = DEFAULT_MODEL
    think: str = DEFAULT_THINK
    backend: str = DEFAULT_BACKEND
    ollama_url: str | None = None
    timeout: float = DEFAULT_TIMEOUT
    force: bool = False
    dry_run: bool = False
    page_context_chars: int = PAGE_CONTEXT_CHARS
    doc_context_chars: int = DOC_CONTEXT_CHARS
    input_base: Path | None = None


def classify_input(source: Path) -> str:
    ext = source.suffix.lower()
    if ext in PDF_EXT:
        return "pdf"
    if ext in RASTER_EXT:
        return "raster"
    if ext in OFFICE_EXT:
        return "office"
    return "unsupported"


def compute_source_relpath(source: Path, base: Path | None) -> str:
    if base is not None:
        try:
            rel = source.relative_to(base)
        except ValueError:
            rel = Path(source.name)
    else:
        try:
            rel = source.resolve().relative_to(Path.cwd().resolve())
        except ValueError:
            rel = Path(source.name)
    return str(rel).replace(os.sep, "/")


def candidate_pages(kind: str, extract: dict[str, Any], opts: Options,
                    pages_total: int) -> list[int]:
    if opts.summary_only:
        return []
    if opts.pages:
        return validate_pages(opts.pages, pages_total)
    if opts.all_pages:
        return list(range(1, pages_total + 1))
    if kind == "raster":
        return [1]
    return sorted(set(extract.get("figure_pages") or []) |
                  set(extract.get("image_text_pages") or []))


def build_plan(source: Path, kind: str, source_relpath: str, sidecar_path: Path,
               opts: Options, extract: dict[str, Any], pages_total: int,
               page_list: list[int], summary_needed: bool,
               sidecar: dict[str, Any]) -> dict[str, Any]:
    page_cache = {str(p): ("cached" if page_entry(sidecar, p) else "miss") for p in page_list}
    summary_cache = "n/a"
    if summary_needed:
        blob, _ = document_text_blob(extract, opts.doc_context_chars)
        prompt = build_doc_prompt(source_relpath, blob)
        resolved_backend = normalize_backend(opts.backend, opts.ollama_url)
        key = canonical_cache_key("doc_summary", b"", prompt, DOC_SCHEMA, PROMPT_VERSION,
                                  opts.model, opts.think, TEMPERATURE, opts.doc_context_chars,
                                  resolved_backend)
        summary_cache = "cached" if (sidecar.get("doc_summary") or {}).get("cache_key") == key else "miss"
    if kind == "raster":
        render: dict[str, Any] | None = (
            {"engine": "image-normalize", "pages": page_list} if page_list else None)
    elif kind == "pdf":
        render = {"engine": "docextract --screenshot", "dpi": SCREENSHOT_DPI, "pages": page_list} \
            if page_list else None
    else:
        render = None
    return {
        "document": str(source),
        "kind": kind,
        "source_relpath": source_relpath,
        "sidecar": str(sidecar_path),
        "extract": {
            "source": str(opts.extract_json) if opts.extract_json else "docextract --json",
            "pages_total": pages_total,
        },
        "candidate_pages": page_list,
        "render": render,
        "inference": {
            "backend": opts.backend,
            "model": opts.model,
            "think": opts.think,
            "temperature": TEMPERATURE,
            "pages": page_list,
            "doc_summary": summary_needed,
        },
        "cache": {
            "pages": page_cache,
            "doc_summary": summary_cache,
            "note": "page cache state is based on existing sidecar entries; exact keys need rendered bytes",
        },
        "would_write_sidecar": bool(page_list or summary_needed),
    }


def process_document(source: Path, opts: Options,
                     docextract_path: Path | None = None) -> dict[str, Any]:
    source = Path(source)
    if not source.is_file():
        raise DocDescribeError(f"input not found: {source}")
    kind = classify_input(source)
    if kind == "unsupported":
        raise UnsupportedInputError(f"unsupported input format {source.suffix!r} for {source}")
    if kind == "office" and not opts.summary_only:
        raise UnsupportedInputError(
            f"visual description is not supported for {source.suffix} in v1 "
            f"({source}); use --summary-only for text summarization")

    source_relpath = compute_source_relpath(source, opts.input_base)
    sidecar_path = resolve_sidecar_path(source, opts.out, opts.input_base)
    docextract = docextract_path

    if opts.extract_json:
        extract = load_extract_file(opts.extract_json)
    else:
        docextract = docextract or locate_docextract()
        extract = run_extraction(docextract, source)

    pages_total = int(extract.get("pages_total") or len(extract.get("pages") or []))
    if kind == "raster":
        pages_total = max(1, pages_total)
    page_list = candidate_pages(kind, extract, opts, pages_total)
    summary_needed = opts.summary_only or opts.summarize

    sidecar = load_sidecar(sidecar_path, source_relpath, opts.model, PROMPT_VERSION)

    if opts.dry_run:
        return build_plan(source, kind, source_relpath, sidecar_path, opts, extract,
                          pages_total, page_list, summary_needed, sidecar)

    result: dict[str, Any] = {
        "document": str(source),
        "source_relpath": source_relpath,
        "sidecar": str(sidecar_path),
        "kind": kind,
        "pages": [],
        "doc_summary": None,
        "warnings": [],
    }
    if page_list:
        with screenshot_workdir(opts.keep_shots, source_relpath) as work:
            if kind == "raster":
                images = {1: normalize_raster_image(source, work)}
            else:
                docextract = docextract or locate_docextract()
                images = render_page_images(docextract, source, page_list, work)
            for page in page_list:
                entry = describe_page(
                    source_relpath=source_relpath,
                    page=page,
                    image_bytes=load_image_bytes(images[page]),
                    extract=extract,
                    sidecar=sidecar,
                    sidecar_path=sidecar_path,
                    model=opts.model,
                    think=opts.think,
                    backend=opts.backend,
                    ollama_url=opts.ollama_url,
                    timeout=opts.timeout,
                    prompt_version=PROMPT_VERSION,
                    temperature=TEMPERATURE,
                    context_chars=opts.page_context_chars,
                    force=opts.force,
                )
                result["pages"].append({
                    key: entry[key]
                    for key in ("page", "cached", "type", "relevant", "wall_seconds")
                })
    if summary_needed:
        summary = summarize_document(
            source_relpath=source_relpath,
            sidecar=sidecar,
            sidecar_path=sidecar_path,
            extract=extract,
            model=opts.model,
            think=opts.think,
            backend=opts.backend,
            ollama_url=opts.ollama_url,
            timeout=opts.timeout,
            prompt_version=PROMPT_VERSION,
            temperature=TEMPERATURE,
            context_chars=opts.doc_context_chars,
            force=opts.force,
        )
        if summary is None:
            result["warnings"].append("no extracted text; document summary skipped")
        else:
            result["doc_summary"] = {
                key: summary[key] for key in ("cached", "wall_seconds", "coverage")
            }
    return result


# ----------------------------------------------------------------------- CLI


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="docdescribe",
        description="Describe figures and summarize documents with a local Ollama model "
                    "(companion to docextract).",
    )
    parser.add_argument("inputs", nargs="+", metavar="INPUT",
                        help="files and/or directories")
    parser.add_argument("-o", "--out", metavar="DIR",
                        help="target directory for durable sidecars "
                             "(default: beside each source file)")
    parser.add_argument("--pages", metavar="SPEC",
                        help='explicit page selection, e.g. "1,3,5-8"')
    parser.add_argument("--summarize", action="store_true",
                        help="also generate a document-level summary")
    parser.add_argument("--summary-only", action="store_true",
                        help="generate the document summary only; no rendering or image calls")
    parser.add_argument("--all-pages", action="store_true",
                        help="inspect every page, not just candidate figure pages")
    parser.add_argument("--extract-json", metavar="PATH",
                        help="use pre-extracted docextract JSON instead of running extraction")
    parser.add_argument("--keep-shots", metavar="DIR",
                        help="retain rendered page PNGs under DIR/<source_relpath>/")
    parser.add_argument("--backend", default=DEFAULT_BACKEND,
                        choices=list(BACKEND_CHOICES),
                        help=f"inference backend (default: {DEFAULT_BACKEND}; env DOCDESCRIBE_BACKEND)")
    parser.add_argument("--model", default=DEFAULT_MODEL,
                        help=f"model tag (default: {DEFAULT_MODEL}; env OLLAMA_MODEL/DOCDESCRIBE_MODEL)")
    parser.add_argument("--think", default=DEFAULT_THINK,
                        choices=list(THINK_ALIASES.keys()),
                        help=f"thinking budget (default: {DEFAULT_THINK}; 'off' disables thinking)")
    parser.add_argument("--no-think", action="store_true",
                        help="disable model thinking (shorthand for --think off)")
    parser.add_argument("--ollama-url", "--url", dest="ollama_url", default=None,
                        help="server endpoint URL (default: http://127.0.0.1:11434 for ollama, "
                             "http://127.0.0.1:8080 for llama-server; env OLLAMA_HOST/DOCDESCRIBE_URL/LLAMA_SERVER_URL)")
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT,
                        help=f"inference timeout in seconds (default: {DEFAULT_TIMEOUT:g})")
    parser.add_argument("--force", action="store_true", help="bypass the sidecar cache")
    parser.add_argument("--dry-run", action="store_true",
                        help="print the plan as JSON without inference or sidecar writes")
    args = parser.parse_args()
    if args.pages and args.all_pages:
        parser.error("--pages and --all-pages are mutually exclusive")
    if args.summary_only and (args.pages or args.all_pages):
        parser.error("--summary-only cannot be combined with --pages or --all-pages")
    return parser


def iter_input_files(token: str) -> list[Path]:
    path = Path(token)
    if path.is_dir():
        return sorted(
            p for p in path.rglob("*")
            if p.is_file() and p.suffix.lower() in SUPPORTED_EXT and p.name != ".DS_Store"
        )
    return [path]


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    think = "off" if args.no_think else normalize_think(args.think)
    base_opts = Options(
        out=Path(args.out) if args.out else None,
        pages=args.pages,
        summarize=args.summarize,
        summary_only=args.summary_only,
        all_pages=args.all_pages,
        extract_json=Path(args.extract_json) if args.extract_json else None,
        keep_shots=Path(args.keep_shots) if args.keep_shots else None,
        model=args.model,
        think=think,
        backend=args.backend,
        ollama_url=args.ollama_url,
        timeout=args.timeout,
        force=args.force,
        dry_run=args.dry_run,
    )

    jobs: list[tuple[Path, Options]] = []
    for token in args.inputs:
        path = Path(token)
        if not path.exists():
            warn(f"not found: {token}")
            return 1
        files = iter_input_files(token)
        input_base = path if path.is_dir() else None
        for file in files:
            jobs.append((file, replace(base_opts, input_base=input_base)))
    if not jobs:
        warn("no supported input files found")
        return 1
    if args.extract_json and len(jobs) != 1:
        warn("--extract-json accepts exactly one input document")
        return 1

    docextract_path = None
    if not base_opts.extract_json:
        try:
            docextract_path = locate_docextract()
        except DocDescribeError as exc:
            warn(str(exc))
            return 1

    failures = 0
    plans: list[dict[str, Any]] = []
    for source, opts in jobs:
        try:
            report = process_document(source, opts, docextract_path)
        except DocDescribeError as exc:
            warn(f"{source}: {exc}")
            failures += 1
            continue
        except Exception as exc:  # noqa: BLE001 - one bad file must not kill the batch
            warn(f"{source}: unexpected error: {exc}")
            failures += 1
            continue
        if opts.dry_run:
            plans.append(report)
            continue
        for message in report["warnings"]:
            warn(f"{source}: {message}")
        described = [p for p in report["pages"] if not p["cached"]]
        cached = len(report["pages"]) - len(described)
        summary = "yes" if report["doc_summary"] else "no"
        print(f"{source} -> {report['sidecar']}  "
              f"({len(report['pages'])} visual page(s), {cached} cached, summary={summary})")

    if base_opts.dry_run:
        payload: Any = plans if len(plans) != 1 else plans[0]
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
