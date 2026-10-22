# Work Unit 01: `raindrop-mcp` proxy and its tests

Status: `todo`
Depends on: none
Design: [Raindrop MCP proxy](20261021-raindrop-mcp-proxy-00-design.md)

## Deliverable

`bin/raindrop-mcp.py`, executable, Python 3 standard library only, plus `bin/tests/test_raindrop_mcp.py`. No package, no virtual environment, no dependency file: the script runs from a checkout and from `~/.local/bin`.

## Detailed Specifications

1. **Entry point and configuration:**
   - Shebang `#!/usr/bin/env python3`; require Python 3.9 or newer and fail with a clear message otherwise.
   - Token resolution order: `RAINDROP_TOKEN`, then `~/.raindrop-token`. Strip surrounding whitespace. A missing or empty token prints one line to stderr and exits 2.
   - Endpoints: MCP at `https://api.raindrop.io/rest/v2/ai/mcp`, REST at `https://api.raindrop.io/rest/v1`. Both overridable with `RAINDROP_MCP_URL` and `RAINDROP_REST_URL` for tests.
   - `--check`: resolve the token, call `initialize` and `tools/list` upstream, print the upstream tool count, the six exposed names, whether `search` survived the rewrite, and whether a one-word REST query returns results. Exit non-zero on any failure. This is the rollout gate.
   - `--list-tools`: print the exposed names one per line without contacting the upstream.

2. **Transport and framing:**
   - Read stdin line by line. Blank lines are ignored. Each line must parse as JSON with a `jsonrpc` field, or the proxy answers `-32700` with `id: null`.
   - Write exactly one compact JSON object plus `\n` per response to stdout, then flush. Never write anything else to stdout.
   - Handle `SIGTERM` and `SIGINT` by exiting 0 without a traceback.
   - Threads are unnecessary: one request at a time is correct for this workload.

3. **Method handling:**
   - `initialize`: answer locally with `protocolVersion` echoed from the client when present, `capabilities: {"tools": {}}`, and `serverInfo: {"name": "raindrop-proxy", "version": "1.0.0"}`. Do not call upstream.
   - `notifications/initialized`, `notifications/cancelled`: consume, emit nothing, never forward. This is the Codex fix.
   - `ping`: answer `{}` locally.
   - `tools/list`: fetch upstream once per process and cache in memory; apply the allowlist and the schema rewrite; return `{"tools": [...]}`.
   - `tools/call`: reject names outside the allowlist with `-32602` `unknown tool '<name>'` before any network call. For `find_bookmarks` with a `query` argument, take the REST path. Everything else forwards `name` and `arguments` unchanged and returns the upstream result verbatim, `isError` included.
   - `resources/list`, `prompts/list`: answer with empty arrays locally.
   - Anything else with an `id`: `-32601` `method not found`.

4. **MCP upstream client:**
   - `urllib.request` with a 5 s connect timeout and a 60 s read timeout, `POST`, headers `Authorization`, `Content-Type: application/json`, `Accept: application/json, text/event-stream`.
   - Parse `Content-Type` containing `text/event-stream` as SSE: concatenate `data:` lines of the first complete event and parse that. Otherwise parse the body as JSON.
   - An empty body is valid only for notifications; for a request it maps to `-32603` `empty upstream response`.
   - Never retry. Map status codes per the design table.

5. **REST query path (`find_bookmarks` with `query`):**
   - Build the search string with the exact translations in the design table, in a fixed order: `query`, then `exclude`, then `has_tags`, then `lacks_tags`, then `type`, then favorite, then `is_tagged: false`, then the `created` bounds.
   - Quote a tag containing whitespace as `#"two words"`. Strip a leading `#` from incoming tags so `#coffee` and `coffee` produce one operator, not two.
   - Collection: one id becomes the URL path, `0` when absent. Several ids, an unsupported `url_pattern`, or `is_duplicate`, `has_broken_link`, `has_highlights` produce `-32602` with a message naming the offending argument, before any request.
   - Request `perpage=50`, `page` starting at 0, and `sort` mapped as in the design. For `random`, fetch a single page of 50 and shuffle locally.
   - Loop pages until the requested `limit` (default 30, cap 150) is filled or a page comes back empty. Apply `bookmark_ids`, `exclude_ids`, and the local shuffle after collection.
   - Normalize each item: `_id`→`bookmark_id`, `collection.$id`→`collection_id`, keep `title`, `link`, `tags`, `created`, `type`, and include `excerpt` and `note` only when non-empty. Return `{"bookmarks": [...]}`.
   - The REST client shares the headers, timeout, and error mapping with the MCP client, but not the SSE parsing: REST answers JSON only.

6. **Allowlist and rewrite constants:**
   - One module-level list of six names, in the design's order, so the list is readable and testable.
   - `find_bookmarks`: delete `properties.search`; add `properties.query` with the design's description; append one sentence to the tool description explaining that `query` searches title, URL, description, tags and notes, that page content needs Pro, and that filters combine with it.
   - `find_collections`: remove `properties.search` from `inputSchema`.
   - If an expected tool is absent upstream, drop it silently and log one stderr line; do not fail the whole catalog.

7. **Logging:**
   - Off by default. With `RAINDROP_MCP_DEBUG=1`, one line per request: method, tool name, backend (`mcp` or `rest`), upstream status, duration in milliseconds.
   - Never log the token, the `Authorization` header, bookmark content, or full request bodies. Truncate anything else to 200 characters.

8. **Tests (`bin/tests/test_raindrop_mcp.py`):**
   - Run with `python3 -m unittest discover -s bin/tests`. No network beyond `127.0.0.1`.
   - A fake upstream built on `http.server.ThreadingHTTPServer` in a background thread, with canned `initialize` and `tools/list` payloads, a REST raindrops payload, a switch for SSE versus JSON, and scripted status codes. It records every request path so tests can assert what was called.
   - Drive the proxy with `subprocess.Popen`, write JSON-RPC lines, read one line back, assert on the parsed object.
   - Cover the thirteen cases listed in the design, plus `--list-tools` and a missing-token exit 2.
   - One test asserts the proxy never sends a request upstream for `notifications/initialized`, by counting hits on the fake server.
   - One test asserts a refused `query` combination produces no HTTP request at all.

## Acceptance

- `bin/raindrop-mcp.py --check` prints six tools, no `search`, a working REST query, exit 0.
- `python3 -m unittest discover -s bin/tests` passes.
- No third-party import anywhere in the script.
