# Design: Raindrop MCP adapter

Status: `todo`
Units: [01 adapter](20261021-raindrop-mcp-proxy-01-proxy.md), [02 integration](20261021-raindrop-mcp-proxy-02-integration.md)

## Problem

Raindrop's official MCP server exposes 21 tools. In harnesses that inject native tool definitions that is a large fixed cost per session (measured: 20,570 characters of raw schema, roughly 5,700 tokens; harnesses that transform declarations may charge less). Three of those tools carry a `search` parameter that fails on the free plan with `Semantic search is only available to Pro users`, and a parameter cannot be hidden by permission rules, which act on whole tools.

The same server cannot be used by Codex natively: it answers `notifications/initialized` with HTTP 200, `content-length: 0`, and no content type, which Codex's MCP client treats as fatal. Codex currently reaches it through `npx mcp-remote`.

## Decision

Build a local stdio MCP server that is an **adapter with its own contract**, not a transparent proxy. Six frozen tool definitions, each with exactly one backend: REST v1 for five, the official MCP server for saved page content only.

Alternatives rejected:

- **Transparent proxy with filter-translation.** Reimplementing Raindrop's filter vocabulary in search operators is subtle work — arrays with OR semantics, `match:OR` interactions, inclusive versus exclusive dates — for filters that are Pro-only or marginal here.
- **All REST, dropping `fetch_bookmark_content`.** Measured: 125 of 193 bookmarks are x.com links; `fetch_bookmark_content` returned their saved text, while direct web fetches returned 403. A generic fetch is not a replacement.
- **Keeping the 21-tool server.** Leaves broken search, forbidden tools reachable, and the Codex bridge.
- **A CLI plus a skill.** Viable only if native MCP tools are negotiable; it does not meet "every harness, every session".

## Goals

1. Six tools, our schemas, ~250 lines of Python standard library, no third-party dependency.
2. Working keyword search on the free plan, through REST.
3. Saved page text available through MCP, isolated behind one tool.
4. Codex works without `mcp-remote`.
5. Token never in a committed file: `RAINDROP_TOKEN`, else `~/.raindrop-token`.

## Non-goals

- Semantic search and page-body search inside the query. Both need Pro at the account level.
- Duplicate, broken-link, highlight filters, and multi-collection OR. Not exposed.
- Random ordering, wildcard URL patterns, creation-date ranges as parameters. The search operators in `query` cover most of it (`created:`, `link:`), and the tool description says so.
- Local index, cache, synchronisation, daemon, retries, background queue.
- MCP resources, prompts, sampling.
- Permanent deletion. `delete_bookmarks` moves to Trash and nothing removes from Trash.
- The official Python MCP SDK. Rationale: no global Python environment in this repo's tooling; a pinned virtualenv for a command launched by four harnesses is more fragile than the protocol subset below. The protocol corrections it would buy are implemented explicitly and tested.

## Architecture

```
harness ──stdio JSON-RPC──→ raindrop-mcp ──┬── REST /rest/v1  (find, collections, create, update, delete)
                                           └── MCP /rest/v2/ai/mcp (content only, lazy)
```

- stdout carries protocol frames only; diagnostics go to stderr.
- The MCP backend is connected lazily on the first `fetch_bookmark_content` call, with its own `initialize` and its own id. Its absence never degrades the other five tools.
- The adapter keeps no bookmark state and no cache. The only retained state is the upstream MCP session: negotiated protocol version, and `Mcp-Session-Id` when the server issues one.
- No queue, no retry, no replay after a timeout.

## Tool contract (frozen)

Schemas are literals in the code. There is no upstream discovery and no rewriting: what the file says is what the harnesses see. Every schema sets `additionalProperties: false`, and an unknown argument is rejected rather than ignored.

### `find_bookmarks`

| Argument | Type | Notes |
| --- | --- | --- |
| `query` | string, optional | Raw Raindrop search syntax, operators included: `"exact phrase"`, `-word`, `#tag`, `-#tag`, `title:`, `link:`, `note:`, `type:`, `created:`, `match:OR` |
| `collection` | integer, optional | Collection id; `0` all (default), `-1` Unsorted, `-99` Trash |
| `sort` | enum, optional | `relevance` (requires `query`), `newest` (default), `oldest` |
| `limit` | integer, optional | 1–50, default 20 |
| `page` | integer, optional | 0-based, default 0 |

Backend: `GET /rest/v1/raindrops/{collection}?search=&sort=&perpage=&page=`. Sort map: `relevance`→`score`, `newest`→`-created`, `oldest`→`created`. `relevance` without `query` is an `isError` result: a cross-field refusal, not malformed input. Single page per call; the answer carries `total` so the agent can page itself.

Answer: `{total, page, items: [{id, title, url, tags, collection_id, created, type, excerpt?, note?}]}`, `created` in ISO 8601, empty `excerpt`/`note` omitted.

### `find_collections`

No arguments. Backend: `GET /rest/v1/collections` plus `GET /rest/v1/collections/childrens`, merged and deduplicated by id.

Answer: `{items: [{id, title, parent_id, count}], system: {unsorted: -1, trash: -99}}`.

### `fetch_bookmark_content`

| Argument | Type |
| --- | --- |
| `bookmark_id` | integer, required |

Backend: MCP `fetch_bookmark_content`. Answer: `{id, title, url, text}`. On failure the result has `isError: true` and a message; the adapter never substitutes a fresh web fetch. Missing or empty `body` is an `isError` result ("no saved content"), not an empty success.

### `create_bookmarks`

| Argument | Type | Notes |
| --- | --- | --- |
| `items` | array, 1–100 | `{url, title?, note?, tags?, collection?}`; 100 is the documented batch limit |

Backend: one `POST /rest/v1/raindrops`. Wire mapping: `url`→`link`, `collection`→`{"$id": n}`, `title`, `note`, `tags` passed through. Answer: `{created: [{index, url, id}], failed: [{index, url, error}], uncertain: [{index, url}]}` where `index` is the position in the input array. No replay after a timeout: an entry whose answer was lost is `uncertain`, because a replay can duplicate.

### `update_bookmarks`

| Argument | Type | Notes |
| --- | --- | --- |
| `bookmark_ids` | array of integers, 1–25 | |
| `title` | string, optional | |
| `note` | string, optional | |
| `tags` | array of strings, optional | Replaces the tag list |
| `favorite` | boolean, optional | Wire field `important`, `false` preserved |
| `collection` | integer, optional | Wire field `{"$id": n}`; moving a bookmark |

Backend: `PUT /rest/v1/raindrop/{id}` — **singular**, so it addresses one bookmark. The plural `/raindrops/{id}` route is collection-scoped and must never be used for per-item writes. Sequential, 25 maximum, in the order given. Processing stops at the first 429; the remainder is `unattempted`. Answer: `{updated: [ids], failed: [{id, error}], unattempted: [ids], uncertain: [ids]}`. `uncertain` means the request may have arrived and must not be retried blindly.

### `delete_bookmarks`

| Argument | Type | Notes |
| --- | --- | --- |
| `bookmark_ids` | array of integers, 1–25 | |

Backend: `PUT /rest/v1/raindrop/{id}` with `{"collection": {"$id": -99}}` — a move to Trash. `DELETE /raindrop/{id}` is **not** used: on a bookmark already in Trash it deletes permanently, so it cannot promise Trash-only behaviour. The move is idempotent and safe to repeat, and it is the reason permanent deletion is not exposed. Sequential, 25 maximum, same four buckets and the same 429 stop rule as `update_bookmarks`. Verify the wire behaviour once with a disposable bookmark in unit 01 before relying on it.

## Protocol subset

- **Version:** support `2025-06-18` only. `initialize` supplies one version, not a list; if the client requests something else, answer `2025-06-18` and let the client decide. `2025-03-26` is not advertised, because it would require JSON-RPC batching.
- **Results:** `tools/call` answers with the MCP envelope, `content: [{type: "text", text: "<json>"}]` plus `structuredContent`, and `isError` when the operation failed. Execution failures (upstream 4xx/5xx, timeouts, refused arguments) are tool results with `isError: true`, not JSON-RPC errors.
- **JSON-RPC errors** are reserved for protocol problems: `-32700` unparsable JSON, `-32600` valid JSON but invalid request, `-32601` unknown method, `-32602` unknown tool or malformed arguments. Valid notifications, including unknown methods, produce no output.
- **Upstream MCP:** `initialize` with `protocolVersion: "2025-06-18"`, empty capabilities, `clientInfo` naming this adapter; store `Mcp-Session-Id` when returned and send it on later calls; send `MCP-Protocol-Version: 2025-06-18` on requests after initialization. Decode results by preferring `structuredContent`, else parsing the first `content` item of type `text` as JSON; an upstream `isError` becomes an `isError` result with its text. If the session is invalidated, report the failure once and reconnect on the next call; never replay the failed call.
- **Upstream SSE:** parse events, ignore leading notifications, return the message whose `id` matches, stop reading.
- **Timeouts:** one `urlopen` timeout of 60 s. It bounds individual blocking socket operations, not the total request duration, and it is documented that way; there is no separate connect timeout because the standard library does not expose one.

## Error mapping

| Upstream | Tool result |
| --- | --- |
| unreachable, DNS, timeout | `isError: true`, `raindrop upstream unreachable` / `timed out` |
| 401, 403 | `isError: true`, `raindrop token rejected` |
| 429 | `isError: true`, `raindrop rate limit, retry after <n>s` |
| 5xx | `isError: true`, `raindrop upstream error <status>` |

## Observability

`RAINDROP_MCP_DEBUG=1` writes one stderr line per request: method, tool, backend (`rest` or `mcp`), status, duration. No request bodies, no notes, no bookmark text, no token.

## Testing

Fake upstreams run on `127.0.0.1`: one REST server, one MCP server with SSE and JSON modes, and a session-mode variant that only accepts requests carrying the session id and version header. The adapter is driven as a subprocess with JSON-RPC lines.

1. `tools/list` returns exactly six names and totals under 8,000 characters of declarations.
2. `notifications/initialized` produces no stdout line and no upstream request.
3. `find_bookmarks` builds the expected path and query string; `total` preserved; dates normalized.
4. `relevance` without `query` is an `isError` result, not a silent fallback and not `-32602`.
5. `page` is forwarded 0-based; `limit` outside 1–50 is `-32602`.
6. Unknown top-level and nested arguments are rejected with `-32602`.
7. `find_collections` merges roots and children without duplicates.
8. `create_bookmarks` maps 100 items in one call, converts `url`→`link` and `collection`→`{"$id"}`, and reports per-index `created`/`failed`/`uncertain`.
9. `update_bookmarks` calls the **singular** route, maps `favorite`→`important` including `false`, caps at 25, stops at 429, and reports `unattempted`.
10. `delete_bookmarks` moves to Trash through `PUT` with collection `-99`, never calls `DELETE`, and is idempotent across repeated calls.
11. A timeout during an update lands in `uncertain` and is not retried.
12. `fetch_bookmark_content` connects lazily, decodes `structuredContent` and text-JSON envelopes, and a failure leaves the other five tools working.
13. An unknown tool returns `-32602` and makes no network call.
14. SSE with a leading notification and the real answer second parses; the session-mode fake proves the version header and session id are sent.
15. `initialize` requesting an unsupported version answers `2025-06-18` rather than echoing it.
16. Unparsable JSON gives `-32700`; valid JSON with a bad shape gives `-32600`; the process survives both.
17. 401, 429, and connection refused become `isError` results.
18. EOF on stdin exits 0.

## Rollout

Codex first (it removes `mcp-remote`), then OpenCode, Claude Code, Antigravity when its quota returns. Verification is a completed turn per harness, not a configuration line.

## Risks

- **Raindrop documents the MCP server as a Pro beta** while it currently answers free-account tokens. Content retrieval is the only thing that depends on it, and its failure is isolated to one tool.
- **REST response changes** (fields, operators) break normalization and search. Canned tests do not detect changed operators; `--check` performs one live query as a smoke test, and a real change needs a manual probe. This is accepted, not covered.
- **Partial writes.** A write can commit before its answer is lost; the `uncertain` bucket exists for that, and nothing is replayed automatically. Process death after a commit is reported to nobody — the adapter promises no durable or exactly-once behaviour.
- **Launch path.** The command is registered by absolute script path so GUI-launched harnesses do not depend on `PATH` for the script; the interpreter is still resolved by `#!/usr/bin/env python3`, which does depend on `PATH`.
- **Protocol drift.** A future MCP revision requires a code change; the plan advertises one version and never claims compatibility it does not implement.
