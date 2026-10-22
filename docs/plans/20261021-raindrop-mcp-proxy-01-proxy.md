# Work Unit 01: the `raindrop-mcp` adapter and its tests

Status: `todo`
Depends on: none
Design: [Raindrop MCP adapter](20261021-raindrop-mcp-proxy-00-design.md)

## Deliverable

`bin/raindrop-mcp.py`, executable, Python 3.9+, standard library only, plus `bin/tests/test_raindrop_mcp.py`. No package, no virtual environment, no dependency file: it runs from a checkout and from `~/.local/bin`.

## Detailed Specifications

1. **Entry point and configuration:**
   - Shebang `#!/usr/bin/env python3`; on a Python older than 3.9 print one line to stderr and exit 2.
   - Token: `RAINDROP_TOKEN` if set and non-empty, else `~/.raindrop-token`; strip whitespace. Missing or empty exits 2 with one stderr line.
   - Endpoints: `https://api.raindrop.io/rest/v1` and `https://api.raindrop.io/rest/v2/ai/mcp`, overridable with `RAINDROP_REST_URL` and `RAINDROP_MCP_URL` (tests and `--check` against a fake).
   - `--list-tools`: print the six names, one per line, no network.
   - `--declarations`: print each tool name and the JSON length of its declaration, plus the total. Must total under 8,000 characters.
   - `--check`: token present; MCP `initialize` plus `tools/list` reachable; REST reachable with a one-word query. Report tool count, declaration size, and whether the REST answer carried a `count` field. An empty result set is healthy. Exit 0 if all transports answered, 1 otherwise. `--check` is a smoke test, not proof that every advertised operator still behaves.
   - No other CLI surface.

2. **Framing:**
   - Read stdin line by line, ignore blank lines, write one compact JSON object plus `\n` per response, flush.
   - Error ladder: unparsable line → `-32700`; parseable JSON that is not an object with `jsonrpc` and `method` → `-32600`; unknown method → `-32601`; unknown tool or malformed arguments → `-32602`. Keep running after each.
   - Valid notifications, including ones whose method is unknown, produce no output and no error.
   - Never write anything but protocol frames to stdout. `SIGINT` and `SIGTERM` exit 0 without a traceback.
   - One request at a time; no threads.

3. **Lifecycle:**
   - Support `2025-06-18` only. `initialize` receives one `protocolVersion`; if it is not supported, answer `2025-06-18`. Never echo an unknown version. `capabilities: {"tools": {}}`, `serverInfo: {"name": "raindrop-mcp", "version": "1.0.0"}`.
   - `notifications/initialized`, `notifications/cancelled`: consume locally, emit nothing, never forward. This is the Codex fix.
   - `ping`: `{}`. `resources/list`, `prompts/list`: empty arrays. EOF: exit 0.

4. **`tools/list` and `tools/call`:**
   - `tools/list` returns the six declarations from the module constants. No upstream call, no rewriting.
   - `tools/call` dispatches on the tool name. Names outside the six → `-32602`, no network call.
   - Argument validation runs before any request, against the literal schema including `additionalProperties: false`: wrong type, unknown top-level or nested property, `limit` outside 1–50, `page` below 0, more than 25 ids, more than 100 items, empty required array → `-32602` naming the argument.
   - `relevance` without `query` is **not** a validation error: it is a cross-field refusal and returns `isError: true`.
   - Success answer: `{"content": [{"type": "text", "text": "<compact json>"}], "structuredContent": <same object>, "isError": false}`.
   - Execution failure (upstream 4xx/5xx, timeout, unreachable, cross-field refusal): `{"content": [{"type": "text", "text": "<message>"}], "isError": true}`. No `structuredContent`. Never a JSON-RPC error.
   - A write that partially succeeds returns `isError: true` **and** the four-bucket object, so the caller keeps the per-item outcome.

5. **HTTP layer:**
   - One `urlopen` per request, `timeout=60`, headers `Authorization: Bearer <token>`, `Accept: application/json` for REST and `Accept: application/json, text/event-stream` for MCP, `Content-Type: application/json` when a body is sent.
   - REST answers JSON only. MCP answers either JSON or `text/event-stream`: parse events, ignore leading notifications, return the message whose `id` matches, stop reading. An empty body on a request is an error; on a notification it is ignored.
   - Map status codes to `isError` messages exactly as the design table. Never retry.

6. **Upstream MCP session:**
   - On first use: `initialize` with `protocolVersion: "2025-06-18"`, `capabilities: {}`, `clientInfo: {"name": "raindrop-mcp", "version": "1.0.0"}`, then `notifications/initialized` whose empty 200 answer is ignored.
   - Store `Mcp-Session-Id` from the initialize response headers when present, and send it on later requests. Send `MCP-Protocol-Version: 2025-06-18` on requests after initialization.
   - Decode a tool result by preferring `structuredContent`, else parsing the first `content` item of type `text` as JSON. An upstream `isError` becomes an `isError` result carrying its text.
   - On a session-invalid response, mark the session dead, report the failure once, and reconnect on the next call. Never replay the failed call.

7. **Tool implementations:**
   - `find_bookmarks`: `limit` 1–50 default 20, `page` 0-based default 0, `collection` default 0, `sort` default `newest`. Path `/raindrops/{collection}`, query `search`, `sort`, `perpage`, `page`. Map `count`→`total`; items→`{id, title, url, tags, collection_id, created, type, excerpt?, note?}` with `_id`→`id`, `collection.$id`→`collection_id`, `link`→`url`, dropping empty `excerpt`/`note`.
   - `find_collections`: `GET /collections` and `GET /collections/childrens`, merge by id, keep `{id, title, parent_id, count}`; return the system ids `-1` and `-99` in a separate object.
   - `create_bookmarks`: one `POST /raindrops` with `items` (1–100). Wire mapping: `url`→`link`, `collection`→`{"$id": n}`, `title`/`note`/`tags` unchanged. Bucket by input index: `created: [{index, url, id}]`, `failed: [{index, url, error}]`, `uncertain: [{index, url}]` for entries whose answer was lost. No retry.
   - `update_bookmarks`: per id, `PUT /raindrop/{id}` — **singular**. Send only the supplied fields; `favorite`→`important` (keep `false`), `collection`→`{"$id": n}`, `tags` replaces the list. Sequential, maximum 25, in the given order. Stop at the first 429 and mark the remainder `unattempted`. Bucket results into `updated`, `failed`, `unattempted`, `uncertain`; a timeout or unreadable answer goes to `uncertain` and is not retried.
   - `delete_bookmarks`: per id, `PUT /raindrop/{id}` with `{"collection": {"$id": -99}}` — a move to Trash. Never `DELETE`. Same cap, order, 429 stop rule and four buckets. Before relying on it, verify once with a disposable bookmark that the resource lands in `-99`.
   - `fetch_bookmark_content`: lazy upstream session, then `tools/call` with `{"bookmark_id": n}`. Map the returned `bookmark.body` to `text`, plus `title` and `link`. A failure marks only this tool as failed; the other five keep working. Missing or empty `body` → `isError` "no saved content for this bookmark".

8. **Constants:**
   - Six schema literals with descriptions written for a model: what the tool does, its limits, that `query` accepts Raindrop operators, that page-body search needs Pro, that `delete_bookmarks` moves to Trash and never deletes permanently, that tag updates replace the list, that `create_bookmarks` accepts at most 100 items.
   - One module-level tuple of the six names, used by validation, `--list-tools`, and the dispatch table.

9. **Logging:**
   - Off by default. `RAINDROP_MCP_DEBUG=1` writes one stderr line per request: method, tool, backend, status, duration. No bodies, no bookmark text, no notes, no token.

10. **Tests (`bin/tests/test_raindrop_mcp.py`):**
    - `python3 -m unittest discover -s bin/tests`, no network beyond `127.0.0.1`.
    - Three fake upstreams on `ThreadingHTTPServer`: REST with canned `raindrops`, `collections`, `childrens`, and scripted statuses; MCP with `initialize`, `tools/list`, `tools/call`, in JSON and SSE modes; a session-mode MCP that rejects requests missing the session id or version header. All record every request.
    - The adapter runs as a subprocess; tests write JSON-RPC lines and read one line back.
    - Cover the eighteen cases in the design, plus `--list-tools`, `--declarations`, `--check` against the fakes, and the missing-token exit 2.
    - Assert no upstream request for: a notification, an unknown tool, and a call rejected by argument validation.
    - Assert the singular update route and the absence of `DELETE` in every write test.

## Acceptance

- `bin/raindrop-mcp.py --declarations` totals under 8,000 characters.
- `bin/raindrop-mcp.py --check` exits 0 against the live API, reporting the upstream tool count and a REST `count`.
- `python3 -m unittest discover -s bin/tests` passes.
- No third-party import anywhere in the script.
