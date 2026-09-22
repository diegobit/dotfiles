# Batch workflows

Run commands relative to this skill directory. Use a unique scratch directory for temporary output.

```bash
scripts/docextract.py INPUT_DIRECTORY -o OUTPUT_DIRECTORY
scripts/docdescribe.py FILE --pages "3,22"
scripts/docdescribe.py INPUT_DIRECTORY --summarize
scripts/docdescribe.py FILE --summary-only
```

Directory extraction mirrors the input tree. `--no-recursive` restricts it to the top level. Inspect exit status and per-file results before claiming complete coverage.

`docdescribe` creates `.describe.json` sidecars with cached captions and summaries. It requires a local Ollama or llama-server backend; consult its `--help` for the installed model/backend configuration. Choose it for batch ingest; targeted visual questions can be answered by inspecting rendered pages directly. Captions and summaries are model-generated interpretations, not verbatim extracted evidence.

If prerequisites are missing, report the missing component and use available extraction or targeted inspection. Model downloads and backend setup are separate work unless included in the user's request.

For execution checks, use `--force` to bypass cached model results and retain logs and sidecars outside the source directory with `--out DIR`. Inspect requested pages and `doc_summary.coverage`; a successful run can still summarize only part of the extracted text. `--summary-only` intentionally makes no image calls, and the default caption mode processes candidate figure pages rather than every page (`--all-pages` requests the latter).
