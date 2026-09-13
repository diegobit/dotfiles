#!/usr/bin/env python3
"""Offline tests for docdescribe.py: no Ollama, no docextract, no network.

Run from the dotfiles repo root:
    python3 -m unittest agent-skills/docextract/tests/test_docdescribe.py
"""
from __future__ import annotations

import base64
import importlib.util
import io
import json
import os
import struct
import subprocess
import sys
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve()
SCRIPT = HERE.parents[1] / "scripts" / "docdescribe.py"

PNG_1x1 = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)

PAGE_PAYLOAD = {
    "relevant": True,
    "type": "chart",
    "summary": "A bar chart of contributions by year.",
    "key_information": ["2023: 1.2M", "2024: 1.5M"],
    "entities": ["FCRF"],
    "important_values": ["1.5M"],
    "skip_reason": "",
}

DOC_PAYLOAD = {
    "summary": "A funding request document.",
    "doc_type": "request",
    "entities": ["FCRF"],
    "key_information": ["request 53807"],
}


def load_module():
    spec = importlib.util.spec_from_file_location("docdescribe_under_test", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


DD = load_module()


class FakeResponse(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()
        return False


def ollama_body(content: dict, done_reason: str = "stop") -> bytes:
    return json.dumps({
        "done_reason": done_reason,
        "message": {"content": json.dumps(content)},
    }).encode("utf-8")


def extract_record(pages: int = 3, figure_pages=(2,), image_text_pages=(3,),
                   text: str | None = None) -> dict:
    body = text if text is not None else "page text about contributions."
    return {
        "file": "report.pdf",
        "pages_total": pages,
        "pages_done": pages,
        "ocr_pages": [],
        "figure_pages": list(figure_pages),
        "image_text_pages": list(image_text_pages),
        "chars": len(body) * pages,
        "pages": [
            {"page": n, "text": f"{body} (page {n})", "engine": "pymupdf",
             "figures": 1 if n in figure_pages else 0}
            for n in range(1, pages + 1)
        ],
    }


def make_fake_docextract(directory: Path, record: dict) -> Path:
    """A stand-in docextract: --json prints the record, --screenshot writes PNGs."""
    script = directory / "docextract.py"
    source = (
        "#!/usr/bin/env python3\n"
        "import json\n"
        "import sys\n"
        "from pathlib import Path\n"
        f"\nEXTRACT = {record!r}\n"
        f"PNG = {PNG_1x1!r}\n\n"
        "def main():\n"
        "    args = sys.argv[1:]\n"
        "    if '--screenshot' in args:\n"
        "        outdir = Path(args[args.index('--screenshot') + 1])\n"
        "        spec = args[args.index('--pages') + 1] if '--pages' in args else '1'\n"
        "        outdir.mkdir(parents=True, exist_ok=True)\n"
        "        for page in spec.split(','):\n"
        "            (outdir / f'page_{page}.png').write_bytes(PNG)\n"
        "        return 0\n"
        "    print(json.dumps(EXTRACT))\n"
        "    return 0\n\n"
        "raise SystemExit(main())\n"
    )
    script.write_text(source, encoding="utf-8")
    script.chmod(0o755)
    return script


class CasesWithTmp(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory(prefix="docdescribe_test_")
        self.tmp = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def write_extract(self, record: dict | None = None) -> Path:
        path = self.tmp / "extract.json"
        path.write_text(json.dumps(record or extract_record()), encoding="utf-8")
        return path

    def write_source(self, name: str = "report.pdf", data: bytes = b"%PDF-fake") -> Path:
        path = self.tmp / name
        path.write_bytes(data)
        return path


# ------------------------------------------------------------------- parsing


class PagesSpecTests(unittest.TestCase):
    def test_parses_ranges_and_deduplicates(self):
        self.assertEqual(DD.parse_pages_spec("1,3,5-8,3"), [1, 3, 5, 6, 7, 8])

    def test_rejects_zero_negative_reversed_and_garbage(self):
        for spec in ("0", "-2", "5-2", "a", "", "  "):
            with self.assertRaises(DD.PageSelectionError, msg=spec):
                DD.parse_pages_spec(spec)

    def test_bounds_are_enforced(self):
        self.assertEqual(DD.validate_pages("1-3", 3), [1, 2, 3])
        with self.assertRaises(DD.PageSelectionError):
            DD.validate_pages("4", 3)
        with self.assertRaises(DD.PageSelectionError):
            DD.validate_pages("2-4", 3)


class UrlAndThinkTests(unittest.TestCase):
    def test_normalize_ollama_url(self):
        self.assertEqual(DD.normalize_ollama_url("127.0.0.1:11434"),
                         "http://127.0.0.1:11434/api/chat")
        self.assertEqual(DD.normalize_ollama_url("http://host:1/api"),
                         "http://host:1/api/chat")
        self.assertEqual(DD.normalize_ollama_url("http://host:1/api/chat"),
                         "http://host:1/api/chat")
        self.assertEqual(DD.normalize_ollama_url("http://host:1/"),
                         "http://host:1/api/chat")

    def test_think_aliases_and_off(self):
        self.assertEqual(DD.DEFAULT_THINK, "off")
        self.assertEqual(DD.normalize_think("off"), "off")
        self.assertEqual(DD.normalize_think("none"), "off")
        self.assertEqual(DD.normalize_think("false"), "off")
        self.assertEqual(DD.normalize_think(False), "off")
        self.assertEqual(DD.normalize_think(True), "low")
        self.assertEqual(DD.normalize_think("low"), "low")
        self.assertEqual(DD.normalize_think("med"), "medium")
        self.assertEqual(DD.normalize_think("hi"), "high")
        with self.assertRaises(ValueError):
            DD.normalize_think("invalid_level")

    def test_resolve_backend_and_url_precedence(self):
        # 1. explicit llama-server with no url -> 8080
        b, u = DD.resolve_backend_and_url("llama-server", None)
        self.assertEqual(b, "llama-server")
        self.assertEqual(u, "http://127.0.0.1:8080/v1/chat/completions")

        # 2. explicit ollama with no url -> 11434
        b, u = DD.resolve_backend_and_url("ollama", None)
        self.assertEqual(b, "ollama")
        self.assertEqual(u, "http://127.0.0.1:11434/api/chat")

        # 3. auto with LLAMA_SERVER_URL in env
        with mock.patch.dict(os.environ, {"LLAMA_SERVER_URL": "http://gpu-host:9090"}, clear=True):
            b, u = DD.resolve_backend_and_url("auto", None)
            self.assertEqual(b, "llama-server")
            self.assertEqual(u, "http://gpu-host:9090/v1/chat/completions")

            # explicit ollama port overrides LLAMA_SERVER_URL under auto
            b, u = DD.resolve_backend_and_url("auto", "http://127.0.0.1:11434")
            self.assertEqual(b, "ollama")
            self.assertEqual(u, "http://127.0.0.1:11434/api/chat")

        # 4. port 80801 is not port 8080, falls back to ollama
        b, u = DD.resolve_backend_and_url("auto", "http://host:80801")
        self.assertEqual(b, "ollama")
        self.assertEqual(u, "http://host:80801/api/chat")


# --------------------------------------------------------------- ollama wire


class OllamaProtocolTests(unittest.TestCase):
    def test_request_payload_is_bounded_and_think_is_forwarded(self):
        captured = {}

        def respond(request, timeout):
            captured.update(json.loads(request.data))
            return FakeResponse(ollama_body({"ok": True}))

        with mock.patch.object(DD.urllib.request, "urlopen", respond):
            result = DD.ollama_chat("prompt", None, DD.JSON_SCHEMA,
                                    think="medium", model="m", url="http://x")
        self.assertEqual(result, {"ok": True})
        self.assertFalse(captured["stream"])
        self.assertEqual(captured["think"], "medium")
        self.assertEqual(captured["format"], DD.JSON_SCHEMA)
        self.assertEqual(captured["options"]["num_predict"], DD.NUM_PREDICT)
        self.assertEqual(captured["options"]["temperature"], DD.TEMPERATURE)
        self.assertEqual(captured["options"]["num_ctx"], DD.NUM_CTX)
        self.assertEqual(captured["model"], "m")
        self.assertEqual(captured["messages"][0]["role"], "user")

    def test_image_is_base64_encoded(self):
        captured = {}

        def respond(request, timeout):
            captured.update(json.loads(request.data))
            return FakeResponse(ollama_body({"ok": True}))

        with mock.patch.object(DD.urllib.request, "urlopen", respond):
            DD.ollama_chat("prompt", b"\x89PNG", DD.JSON_SCHEMA, think="low")
        self.assertEqual(base64.b64decode(captured["messages"][0]["images"][0]), b"\x89PNG")

    def test_truncated_output_is_rejected(self):
        body = json.dumps({"done_reason": "length", "message": {"content": "{}"}}).encode()
        with mock.patch.object(DD.urllib.request, "urlopen",
                               lambda request, timeout: FakeResponse(body)):
            with self.assertRaises(DD.TruncatedOutputError) as ctx:
                DD.ollama_chat("p", None, DD.JSON_SCHEMA, think="low")
        self.assertIn("token", str(ctx.exception))
        self.assertIsInstance(ctx.exception, RuntimeError)

    def test_json_in_thinking_field_is_a_documented_fallback(self):
        body = json.dumps({
            "done_reason": "stop",
            "message": {"content": "", "thinking": json.dumps(PAGE_PAYLOAD)},
        }).encode()
        with mock.patch.object(DD.urllib.request, "urlopen",
                               lambda request, timeout: FakeResponse(body)):
            self.assertEqual(DD.ollama_chat("p", None, DD.JSON_SCHEMA, think="low"),
                             PAGE_PAYLOAD)

    def test_malformed_json_is_rejected(self):
        body = json.dumps({"done_reason": "stop",
                           "message": {"content": "not json at all"}}).encode()
        with mock.patch.object(DD.urllib.request, "urlopen",
                               lambda request, timeout: FakeResponse(body)):
            with self.assertRaises(DD.InvalidResponseError):
                DD.ollama_chat("p", None, DD.JSON_SCHEMA, think="low")

    def test_ollama_malformed_envelope_is_rejected(self):
        bad_payloads = [
            {"message": None},
            {"message": "not a dict"},
            {"message": {"content": 42}},
            {"message": {"content": {}, "thinking": None}},
            {"message": {"content": "", "thinking": [1]}},
            {"message": {"content": "", "thinking": {"not": "str"}}},
            {"message": {"content": ""}},
            {"no_message": True},
        ]
        for payload in bad_payloads:
            with mock.patch.object(DD.urllib.request, "urlopen",
                                   lambda req, timeout: FakeResponse(json.dumps(payload).encode())):
                with self.assertRaises(DD.InvalidResponseError, msg=str(payload)):
                    DD.ollama_chat("p", None, DD.JSON_SCHEMA, backend="ollama")

    def test_unreachable_host_is_actionable(self):
        def refuse(request, timeout):
            raise urllib.error.URLError("connection refused")

        with mock.patch.object(DD.urllib.request, "urlopen", refuse):
            with self.assertRaises(DD.OllamaUnreachableError) as ctx:
                DD.ollama_chat("p", None, DD.JSON_SCHEMA, think="low")
        self.assertIn("ollama serve", str(ctx.exception))

    def test_model_404_is_actionable(self):
        def missing(request, timeout):
            raise urllib.error.HTTPError("http://x/api/chat", 404, "Not Found", {}, None)

        with mock.patch.object(DD.urllib.request, "urlopen", missing):
            with self.assertRaises(DD.ModelNotFoundError) as ctx:
                DD.ollama_chat("p", None, DD.JSON_SCHEMA, think="low", model="missing")
        self.assertIn("ollama pull missing", str(ctx.exception))

    def test_think_off_forwards_false_boolean(self):
        captured = {}

        def respond(request, timeout):
            captured.update(json.loads(request.data))
            return FakeResponse(ollama_body({"ok": True}))

        with mock.patch.object(DD.urllib.request, "urlopen", respond):
            result = DD.ollama_chat("prompt", None, DD.JSON_SCHEMA, think="off")
        self.assertEqual(result, {"ok": True})
        self.assertIs(captured["think"], False)


# --------------------------------------------------------- llama-server wire


class LlamaServerProtocolTests(unittest.TestCase):
    def test_llama_server_request_payload_and_thinking_off_default(self):
        captured_data = {}
        captured_url = ""

        def respond(request, timeout):
            nonlocal captured_url
            captured_url = request.full_url
            captured_data.update(json.loads(request.data))
            response_payload = {
                "choices": [{
                    "finish_reason": "stop",
                    "message": {"content": json.dumps(PAGE_PAYLOAD)},
                }]
            }
            return FakeResponse(json.dumps(response_payload).encode("utf-8"))

        # Test omitting think and url: verifies think='off' by default and url defaults to 8080
        with mock.patch.object(DD.urllib.request, "urlopen", respond):
            res = DD.ollama_chat("look at this", b"fake_png", DD.JSON_SCHEMA,
                                 backend="llama-server", model="qwen-gguf")
        self.assertEqual(res, PAGE_PAYLOAD)
        self.assertEqual(captured_url, "http://127.0.0.1:8080/v1/chat/completions")
        self.assertEqual(captured_data["model"], "qwen-gguf")
        self.assertEqual(captured_data["chat_template_kwargs"], {"enable_thinking": False})
        self.assertNotIn("reasoning_effort", captured_data)
        msg = captured_data["messages"][0]
        self.assertEqual(msg["role"], "user")
        self.assertEqual(msg["content"][0]["type"], "text")
        self.assertEqual(msg["content"][0]["text"], "look at this")
        self.assertEqual(msg["content"][1]["type"], "image_url")
        self.assertTrue(msg["content"][1]["image_url"]["url"].startswith("data:image/png;base64,"))

    def test_llama_server_thinking_on(self):
        captured_data = {}

        def respond(request, timeout):
            captured_data.update(json.loads(request.data))
            response_payload = {
                "choices": [{
                    "finish_reason": "stop",
                    "message": {"content": json.dumps(DOC_PAYLOAD)},
                }]
            }
            return FakeResponse(json.dumps(response_payload).encode("utf-8"))

        with mock.patch.object(DD.urllib.request, "urlopen", respond):
            res = DD.ollama_chat("summarize", None, DD.DOC_SCHEMA,
                                 backend="llama-server", think="low")
        self.assertEqual(res, DOC_PAYLOAD)
        self.assertEqual(captured_data["chat_template_kwargs"], {"enable_thinking": True})
        self.assertEqual(captured_data["reasoning_effort"], "low")

    def test_llama_server_truncation_is_rejected(self):
        response_payload = {
            "choices": [{
                "finish_reason": "length",
                "message": {"content": "{}"},
            }]
        }
        with mock.patch.object(DD.urllib.request, "urlopen",
                               lambda req, timeout: FakeResponse(json.dumps(response_payload).encode())):
            with self.assertRaises(DD.TruncatedOutputError) as ctx:
                DD.ollama_chat("p", None, DD.JSON_SCHEMA, backend="llama-server")
        self.assertIn("max_tokens", str(ctx.exception))

    def test_llama_server_malformed_envelope_is_rejected(self):
        bad_payloads = [
            {"choices": [None]},
            {"choices": [{"message": {"content": 42}}]},
            {"choices": [{"message": None}]},
            {"choices": []},
            {"no_choices": True},
        ]
        for payload in bad_payloads:
            with mock.patch.object(DD.urllib.request, "urlopen",
                                   lambda req, timeout: FakeResponse(json.dumps(payload).encode())):
                with self.assertRaises(DD.InvalidResponseError, msg=str(payload)):
                    DD.ollama_chat("p", None, DD.JSON_SCHEMA, backend="llama-server")


# ---------------------------------------------------------------- validation


class ValidationTests(unittest.TestCase):
    def test_valid_page_payload(self):
        parsed = DD.validate_page_payload(dict(PAGE_PAYLOAD))
        self.assertTrue(parsed["relevant"])
        self.assertEqual(parsed["type"], "chart")
        self.assertEqual(parsed["important_values"], ["1.5M"])

    def test_page_payload_type_failures(self):
        bad_payloads = [
            {**PAGE_PAYLOAD, "relevant": "true"},
            {**PAGE_PAYLOAD, "relevant": 1},
            {**PAGE_PAYLOAD, "type": "invalid_enum"},
            {**PAGE_PAYLOAD, "type": 3},
            {**PAGE_PAYLOAD, "summary": 5},
            {**PAGE_PAYLOAD, "key_information": "one string"},
            {**PAGE_PAYLOAD, "key_information": ["ok", 2]},
            {**PAGE_PAYLOAD, "important_values": [None]},
            {k: v for k, v in PAGE_PAYLOAD.items() if k != "key_information"},
        ]
        for payload in bad_payloads:
            with self.assertRaises(DD.InvalidResponseError, msg=payload):
                DD.validate_page_payload(payload)

    def test_valid_doc_payload_and_missing_summary(self):
        parsed = DD.validate_doc_payload(dict(DOC_PAYLOAD))
        self.assertEqual(parsed["doc_type"], "request")
        with self.assertRaises(DD.InvalidResponseError):
            DD.validate_doc_payload({"doc_type": "request"})

    def test_index_text(self):
        entry = {**PAGE_PAYLOAD, "index_text": ""}
        text = DD.index_text_for(entry, 7)
        self.assertTrue(text.startswith("[visual p.7 type=chart]\n"))
        self.assertIn("- 2023: 1.2M", text)
        self.assertEqual(DD.index_text_for({**PAGE_PAYLOAD, "relevant": False}, 7), "")


# ------------------------------------------------------------ cache, sidecar


class CacheAndSidecarTests(CasesWithTmp):
    def test_cache_hit_skips_inference_and_rewrites_nothing(self):
        sidecar_path = self.tmp / "a.pdf.describe.json"
        extract = {"pages": [{"page": 1, "text": "one"}]}
        with mock.patch.object(DD, "ollama_chat", return_value=dict(PAGE_PAYLOAD)):
            first = DD.describe_page(
                source_relpath="a.pdf", page=1, image_bytes=b"img", extract=extract,
                sidecar=DD.default_sidecar("a.pdf", "m", DD.PROMPT_VERSION),
                sidecar_path=sidecar_path)
        self.assertFalse(first["cached"])
        self.assertTrue(first["values_untrusted"])
        self.assertIn("bar chart", first["index_text"])
        os.utime(sidecar_path, (1000000000, 1000000000))
        before = sidecar_path.read_bytes()

        with mock.patch.object(DD, "ollama_chat",
                               side_effect=AssertionError("cache miss")):
            second = DD.describe_page(
                source_relpath="a.pdf", page=1, image_bytes=b"img", extract=extract,
                sidecar=DD.load_sidecar(sidecar_path, "a.pdf", "m", DD.PROMPT_VERSION),
                sidecar_path=sidecar_path)
        self.assertTrue(second["cached"])
        self.assertEqual(second["cache_key"], first["cache_key"])
        self.assertEqual(sidecar_path.read_bytes(), before)
        self.assertEqual(sidecar_path.stat().st_mtime, 1000000000)

    def test_force_bypasses_the_cache(self):
        sidecar_path = self.tmp / "a.pdf.describe.json"
        extract = {"pages": [{"page": 1, "text": "one"}]}
        with mock.patch.object(DD, "ollama_chat", return_value=dict(PAGE_PAYLOAD)):
            DD.describe_page(source_relpath="a.pdf", page=1, image_bytes=b"img",
                             extract=extract,
                             sidecar=DD.default_sidecar("a.pdf", "m", DD.PROMPT_VERSION),
                             sidecar_path=sidecar_path)
        changed = {**PAGE_PAYLOAD, "summary": "changed"}
        with mock.patch.object(DD, "ollama_chat", return_value=changed):
            entry = DD.describe_page(
                source_relpath="a.pdf", page=1, image_bytes=b"img", extract=extract,
                sidecar=DD.load_sidecar(sidecar_path, "a.pdf", "m", DD.PROMPT_VERSION),
                sidecar_path=sidecar_path, force=True)
        self.assertFalse(entry["cached"])
        self.assertEqual(entry["summary"], "changed")
        saved = json.loads(sidecar_path.read_text(encoding="utf-8"))
        self.assertEqual(saved["pages"][0]["summary"], "changed")

    def test_backend_switching_invalidates_page_and_summary_cache(self):
        key_ollama = DD.canonical_cache_key("page", b"img", "prompt", DD.JSON_SCHEMA,
                                            "v1", "model", "off", 0.0, 100, "ollama")
        key_llama = DD.canonical_cache_key("page", b"img", "prompt", DD.JSON_SCHEMA,
                                           "v1", "model", "off", 0.0, 100, "llama-server")
        self.assertNotEqual(key_ollama, key_llama)

        doc_key_ollama = DD.canonical_cache_key("doc_summary", b"", "prompt", DD.DOC_SCHEMA,
                                                "v1", "model", "off", 0.0, 100, "ollama")
        doc_key_llama = DD.canonical_cache_key("doc_summary", b"", "prompt", DD.DOC_SCHEMA,
                                               "v1", "model", "off", 0.0, 100, "llama-server")
        self.assertNotEqual(doc_key_ollama, doc_key_llama)

    def test_atomic_write_leaves_no_temporary_files(self):
        sidecar_path = self.tmp / "a.pdf.describe.json"
        DD.save_sidecar_atomic(sidecar_path, {"source_relpath": "a.pdf", "pages": []})
        self.assertTrue(sidecar_path.exists())
        self.assertEqual(list(self.tmp.glob("*.tmp")), [])

    def test_malformed_sidecar_is_ignored_not_fatal(self):
        sidecar_path = self.tmp / "a.pdf.describe.json"
        sidecar_path.write_text("{incomplete", encoding="utf-8")
        sidecar = DD.load_sidecar(sidecar_path, "a.pdf", "m", DD.PROMPT_VERSION)
        self.assertEqual(sidecar["source_relpath"], "a.pdf")
        self.assertEqual(sidecar["pages"], [])


class WorkdirTests(CasesWithTmp):
    def test_temporary_workdir_is_cleaned_up(self):
        with DD.screenshot_workdir(None, "a.pdf") as work:
            (work / "page_1.png").write_bytes(PNG_1x1)
            captured = work
        self.assertFalse(captured.exists())

    def test_keep_shots_retains_rendered_pngs(self):
        keep = self.tmp / "shots"
        with DD.screenshot_workdir(keep, "a.pdf") as work:
            self.assertEqual(work, keep / "a.pdf")
            (work / "page_1.png").write_bytes(PNG_1x1)
        self.assertTrue((keep / "a.pdf" / "page_1.png").exists())


# ---------------------------------------------------------- image inputs


class ImageInputTests(CasesWithTmp):
    def test_static_png_normalizes_to_page_1(self):
        source = self.write_source("shot.png", PNG_1x1)
        dest = DD.normalize_raster_image(source, self.tmp / "work")
        self.assertEqual(dest.name, "page_1.png")
        self.assertEqual(dest.read_bytes(), PNG_1x1)

    def test_animated_gif_is_rejected(self):
        frame = (b"\x2c\x00\x00\x00\x00\x01\x00\x01\x00\x00"
                 b"\x02\x02\x44\x01\x00")
        gif = (b"GIF89a" + b"\x01\x00\x01\x00\x80\x00\x00"
               + b"\x00\x00\x00\xff\xff\xff" + frame + frame + b"\x3b")
        source = self.write_source("anim.gif", gif)
        with self.assertRaises(DD.UnsupportedInputError):
            DD.normalize_raster_image(source, self.tmp / "work")

    def test_static_gif_is_accepted(self):
        frame = (b"\x2c\x00\x00\x00\x00\x01\x00\x01\x00\x00"
                 b"\x02\x02\x44\x01\x00")
        gif = (b"GIF89a" + b"\x01\x00\x01\x00\x80\x00\x00"
               + b"\x00\x00\x00\xff\xff\xff" + frame + b"\x3b")
        source = self.write_source("still.gif", gif)
        self.assertEqual(DD.gif_frame_count(source), 1)

    def test_multipage_tiff_is_rejected(self):
        entry = b"\x00" * 12
        ifd1 = struct.pack("<H", 1) + entry + struct.pack("<I", 30)
        ifd2 = struct.pack("<H", 1) + entry + struct.pack("<I", 0)
        tiff = b"II" + struct.pack("<H", 42) + struct.pack("<I", 8) + ifd1 + ifd2
        source = self.write_source("multi.tif", tiff)
        with self.assertRaises(DD.UnsupportedInputError):
            DD.normalize_raster_image(source, self.tmp / "work")

    def test_single_page_tiff_is_accepted(self):
        entry = b"\x00" * 12
        tiff = b"II" + struct.pack("<H", 42) + struct.pack("<I", 8) + \
            struct.pack("<H", 1) + entry + struct.pack("<I", 0)
        source = self.write_source("single.tif", tiff)
        self.assertEqual(DD.tiff_page_count(source), 1)


# -------------------------------------------------------------- pipelines


class PipelineTests(CasesWithTmp):
    def test_pdf_describe_and_summarize_writes_compatible_sidecar(self):
        record = extract_record()
        extract_path = self.write_extract(record)
        source = self.write_source()
        docextract = make_fake_docextract(self.tmp, record)
        shots = self.tmp / "shots"
        opts = DD.Options(extract_json=extract_path, summarize=True, keep_shots=shots)

        images = []

        def fake_chat(prompt, image=None, schema=None, **kwargs):
            images.append(image is not None)
            return dict(PAGE_PAYLOAD) if image is not None else dict(DOC_PAYLOAD)

        with mock.patch.object(DD, "ollama_chat", side_effect=fake_chat):
            report = DD.process_document(source, opts, docextract_path=docextract)

        self.assertEqual([p["page"] for p in report["pages"]], [2, 3])
        self.assertEqual(images, [True, True, False])
        sidecar_path = self.tmp / "report.pdf.describe.json"
        sidecar = json.loads(sidecar_path.read_text(encoding="utf-8"))
        self.assertEqual(sidecar["source_relpath"], "report.pdf")
        self.assertEqual(sidecar["model"], opts.model)
        self.assertIsNotNone(sidecar["updated_at"])
        page2 = next(p for p in sidecar["pages"] if p["page"] == 2)
        self.assertEqual(page2["type"], "chart")
        self.assertTrue(page2["relevant"])
        self.assertTrue(page2["values_untrusted"])
        self.assertIn("cache_key", page2)
        self.assertIn("described_at", page2)
        self.assertTrue(page2["index_text"].startswith("[visual p.2 type=chart]"))
        summary = sidecar["doc_summary"]
        self.assertEqual(summary["coverage"]["truncated"], False)
        self.assertEqual(summary["coverage"]["chars_extracted"],
                         summary["coverage"]["chars_summarized"])
        self.assertTrue((shots / "report.pdf" / "page_2.png").exists())
        self.assertTrue((shots / "report.pdf" / "page_3.png").exists())

    def test_second_run_hits_every_cache_without_inference_or_rewrite(self):
        record = extract_record(figure_pages=(2,), image_text_pages=())
        extract_path = self.write_extract(record)
        source = self.write_source()
        docextract = make_fake_docextract(self.tmp, record)
        opts = DD.Options(extract_json=extract_path, summarize=True)
        with mock.patch.object(DD, "ollama_chat", return_value=dict(PAGE_PAYLOAD)):
            DD.process_document(source, opts, docextract_path=docextract)
        sidecar_path = self.tmp / "report.pdf.describe.json"
        os.utime(sidecar_path, (1000000000, 1000000000))
        before = sidecar_path.read_bytes()

        with mock.patch.object(DD, "ollama_chat",
                               side_effect=AssertionError("cache miss")):
            report = DD.process_document(source, opts, docextract_path=docextract)
        self.assertTrue(all(p["cached"] for p in report["pages"]))
        self.assertTrue(report["doc_summary"]["cached"])
        self.assertEqual(sidecar_path.read_bytes(), before)
        self.assertEqual(sidecar_path.stat().st_mtime, 1000000000)

    def test_temporary_screenshot_dir_is_removed_after_the_run(self):
        record = extract_record(figure_pages=(2,), image_text_pages=())
        extract_path = self.write_extract(record)
        source = self.write_source()
        docextract = make_fake_docextract(self.tmp, record)
        opts = DD.Options(extract_json=extract_path)
        created = []
        real_tempdir = tempfile.TemporaryDirectory

        def tracking(*args, **kwargs):
            ctx = real_tempdir(*args, **kwargs)
            created.append(Path(ctx.name))
            return ctx

        with mock.patch.object(DD.tempfile, "TemporaryDirectory", tracking), \
                mock.patch.object(DD, "ollama_chat", return_value=dict(PAGE_PAYLOAD)):
            DD.process_document(source, opts, docextract_path=docextract)
        self.assertTrue(created)
        self.assertFalse(created[0].exists())

    def test_pages_selection_is_strict_and_respected(self):
        record = extract_record()
        extract_path = self.write_extract(record)
        source = self.write_source()
        docextract = make_fake_docextract(self.tmp, record)
        with mock.patch.object(DD, "ollama_chat", return_value=dict(PAGE_PAYLOAD)):
            report = DD.process_document(
                source, DD.Options(extract_json=extract_path, pages="1"), docextract)
        self.assertEqual([p["page"] for p in report["pages"]], [1])
        with self.assertRaises(DD.PageSelectionError):
            DD.process_document(
                source, DD.Options(extract_json=extract_path, pages="9"), docextract)

    def test_summary_only_skips_rendering_and_pages(self):
        record = extract_record()
        extract_path = self.write_extract(record)
        source = self.write_source()

        def no_render(*args, **kwargs):
            raise AssertionError("summary-only must not render")

        with mock.patch.object(DD, "render_page_images", no_render), \
                mock.patch.object(DD, "ollama_chat", return_value=dict(DOC_PAYLOAD)):
            report = DD.process_document(
                source, DD.Options(extract_json=extract_path, summary_only=True))
        self.assertEqual(report["pages"], [])
        self.assertIsNotNone(report["doc_summary"])
        sidecar = json.loads((self.tmp / "report.pdf.describe.json").read_text(encoding="utf-8"))
        self.assertEqual(sidecar["pages"], [])
        self.assertEqual(sidecar["doc_summary"]["summary"], DOC_PAYLOAD["summary"])

    def test_summary_truncation_records_coverage(self):
        record = extract_record(pages=2, figure_pages=(), image_text_pages=(),
                                text="x" * 3000)
        extract_path = self.write_extract(record)
        source = self.write_source()
        with mock.patch.object(DD, "ollama_chat", return_value=dict(DOC_PAYLOAD)):
            report = DD.process_document(
                source,
                DD.Options(extract_json=extract_path, summary_only=True,
                           doc_context_chars=1000))
        coverage = report["doc_summary"]["coverage"]
        self.assertTrue(coverage["truncated"])
        self.assertGreater(coverage["chars_summarized"], 0)
        self.assertLessEqual(coverage["chars_summarized"], 1000)
        self.assertGreater(coverage["chars_extracted"], 1000)

    def test_no_text_skips_the_summary_with_a_warning(self):
        record = extract_record(pages=2, figure_pages=(), image_text_pages=(), text="")
        for page in record["pages"]:
            page["text"] = ""
        extract_path = self.write_extract(record)
        source = self.write_source()
        with mock.patch.object(DD, "ollama_chat",
                               side_effect=AssertionError("no text to summarize")):
            report = DD.process_document(
                source, DD.Options(extract_json=extract_path, summary_only=True))
        self.assertIsNone(report["doc_summary"])
        self.assertIn("no extracted text; document summary skipped", report["warnings"])

    def test_office_visual_is_rejected_but_summary_only_works(self):
        record = extract_record(figure_pages=(), image_text_pages=())
        extract_path = self.write_extract(record)
        source = self.write_source("notes.docx", b"fake docx")
        with self.assertRaises(DD.UnsupportedInputError):
            DD.process_document(source, DD.Options(extract_json=extract_path))
        with mock.patch.object(DD, "ollama_chat", return_value=dict(DOC_PAYLOAD)):
            report = DD.process_document(
                source, DD.Options(extract_json=extract_path, summary_only=True))
        self.assertIsNotNone(report["doc_summary"])

    def test_raster_image_describes_logical_page_1(self):
        record = {"file": "shot.png", "pages_total": 1, "pages_done": 1, "ocr_pages": [1],
                  "figure_pages": [1], "image_text_pages": [],
                  "pages": [{"page": 1, "text": "ocr text", "engine": "vision-ocr"}]}
        extract_path = self.write_extract(record)
        source = self.write_source("shot.png", PNG_1x1)
        with mock.patch.object(DD, "ollama_chat", return_value=dict(PAGE_PAYLOAD)):
            report = DD.process_document(source, DD.Options(extract_json=extract_path))
        self.assertEqual([p["page"] for p in report["pages"]], [1])

    def test_extraction_exit_3_is_accepted_when_json_is_valid(self):
        record = extract_record(pages=1, figure_pages=(), image_text_pages=())
        record["pages"][0]["text"] = ""
        script = self.tmp / "docextract.py"
        script.write_text(
            "#!/usr/bin/env python3\n"
            "import json, sys\n"
            f"print(json.dumps({record!r}))\n"
            "raise SystemExit(3)\n",
            encoding="utf-8")
        script.chmod(0o755)
        source = self.write_source()
        with mock.patch.object(DD, "ollama_chat",
                               side_effect=AssertionError("no candidates")):
            report = DD.process_document(source, DD.Options(), docextract_path=script)
        self.assertEqual(report["pages"], [])

    def test_dry_run_plans_without_writing_or_inferring(self):
        record = extract_record()
        extract_path = self.write_extract(record)
        source = self.write_source()
        with mock.patch.object(DD, "ollama_chat",
                               side_effect=AssertionError("dry run must not infer")):
            plan = DD.process_document(
                source,
                DD.Options(extract_json=extract_path, summarize=True, dry_run=True))
        self.assertEqual(plan["candidate_pages"], [2, 3])
        self.assertEqual(plan["cache"]["pages"], {"2": "miss", "3": "miss"})
        self.assertEqual(plan["cache"]["doc_summary"], "miss")
        self.assertTrue(plan["inference"]["doc_summary"])
        self.assertFalse((self.tmp / "report.pdf.describe.json").exists())


class CliTests(CasesWithTmp):
    def test_help_runs_cleanly_with_plain_python3(self):
        cp = subprocess.run([sys.executable, str(SCRIPT), "--help"],
                            capture_output=True, text=True)
        self.assertEqual(cp.returncode, 0)
        self.assertIn("--think", cp.stdout)
        self.assertIn("--summary-only", cp.stdout)

    def test_think_invalid_is_a_parser_error(self):
        cp = subprocess.run([sys.executable, str(SCRIPT), "x.pdf", "--think", "invalid_choice"],
                            capture_output=True, text=True)
        self.assertEqual(cp.returncode, 2)
        self.assertIn("invalid choice", cp.stderr)

    def test_think_off_is_accepted_cli_arg(self):
        record = extract_record()
        extract_path = self.write_extract(record)
        source = self.write_source()
        cp = subprocess.run(
            [sys.executable, str(SCRIPT), str(source),
             "--extract-json", str(extract_path), "--think", "off", "--dry-run"],
            capture_output=True, text=True)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        plan = json.loads(cp.stdout)
        self.assertEqual(plan["inference"]["think"], "off")

    def test_dry_run_cli_emits_json_plan(self):
        record = extract_record()
        extract_path = self.write_extract(record)
        source = self.write_source()
        cp = subprocess.run(
            [sys.executable, str(SCRIPT), str(source),
             "--extract-json", str(extract_path), "--dry-run"],
            capture_output=True, text=True)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        plan = json.loads(cp.stdout)
        self.assertEqual(plan["candidate_pages"], [2, 3])


if __name__ == "__main__":
    unittest.main()
