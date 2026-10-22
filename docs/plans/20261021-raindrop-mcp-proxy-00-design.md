# Design: Raindrop MCP proxy

Status: `todo`
Units: [01 proxy](20261021-raindrop-mcp-proxy-01-proxy.md), [02 integration](20261021-raindrop-mcp-proxy-02-integration.md)

## Problem

The official server at `https://api.raindrop.io/rest/v2/ai/mcp` exposes 21 tools, about 20,600 characters of schema, roughly 5,700 tokens in every session of every harness that injects native tool definitions. Three of those tools carry a `search` parameter that fails on the free plan with `Semantic search is only available to Pro users`; the parameter cannot be hidden, because harness permission rules act on whole tools.

Codex cannot use the server directly. After `initialize`, the server answers `notifications/initialized` with HTTP 200, `content-length: 0`, and no content type. Codex's MCP client treats the missing content type as fatal and drops the connection, which is why it currently runs through `npx mcp-remote`.

## Goals

1. One local stdio MCP server, no third-party dependency, that fronts the official one.
2. Expose exactly six tools: `find_bookmarks`, `find_collections`, `fetch_bookmark_content`, `create_bookmarks`, `update_bookmarks`, `delete_bookmarks`.
3. Replace the broken `search` parameter with a `query` parameter implemented by the proxy over the REST API, so keyword search actually works on the free plan.
4. Answer `notifications/initialized` locally, which removes the Codex transport failure and `mcp-remote` with it.
5. Keep the token out of harness configuration: read `~/.raindrop-token` or `RAINDROP_TOKEN`.

## Non-goals

- Semantic search and page-body search. Both require Pro at the account level; no proxy can change that. The tool description says so instead of failing at call time.
- Caching, retries, or rate-limit queuing. The upstream allows 120 requests per minute and the proxy adds no load.
- MCP resources, prompts, or sampling. Only tools.
- Filtering writes beyond the allowlist. `delete_bookmarks` stays, as decided.

## Architecture

```
harness (stdio, line-delimited JSON-RPC)
    ↓
raindrop-mcp  ── allowlist ── schema rewrite ──┬── MCP upstream (structured filters, writes)
                                               └── REST /rest/v1 (keyword query)
```

- Framing: one JSON-RPC message per line in both directions. stdout carries protocol frames only; every diagnostic goes to stderr.
- Upstream MCP: `POST` with `Authorization`, `Content-Type: application/json`, `Accept: application/json, text/event-stream`. Parse a JSON body and an SSE body (`event:` / `data:` lines) the same way. An empty body is a valid answer, not an error.
- The MCP endpoint is stateless: it returned no `Mcp-Session-Id` in testing, so the proxy sends none. If one ever appears, forward it on subsequent calls.
- Notifications are never forwarded upstream. `notifications/initialized` and `notifications/cancelled` are accepted and dropped. This is deliberate: forwarding is what breaks Codex today.
- Unknown requests get `-32601`, malformed frames `-32700`, and the proxy keeps running. EOF on stdin exits 0.

## Tool allowlist and schema rewrite

| Tool | Exposed | Rewrite |
| --- | --- | --- |
| `find_bookmarks` | yes | delete `properties.search`; add `properties.query` (see below); append the search scope to the description |
| `find_collections` | yes | delete `properties.search` |
| `fetch_bookmark_content` | yes | none |
| `create_bookmarks` | yes | none |
| `update_bookmarks` | yes | none |
| `delete_bookmarks` | yes | none |
| other 15 | no | absent from `tools/list`; a call returns `-32602 unknown tool` |

The allowlist is an allowlist, not a denylist: tools added upstream stay invisible until someone edits the list on purpose.

## The `query` parameter

`find_bookmarks` gains one string parameter:

> Keyword query over title, URL, description, tags, and notes. Supports Raindrop operators: `"exact phrase"`, `-exclude`, `#tag`, `-#tag`, `title:`, `link:`, `note:`, `type:`, `created:`, `match:OR`. Page-body and meaning search need Pro and are not available.

Two paths:

- **No `query`:** the call is forwarded to the MCP upstream unchanged. Every existing filter keeps working as it does today.
- **`query` present:** the proxy answers it, by translating the call into `GET /rest/v1/raindrops/{collectionId}?search=...`:

| Argument | Translation |
| --- | --- |
| `query` | the search string, verbatim, operators included |
| `exclude` | one `-word` per entry, appended |
| `has_tags` | `#tag`, quoted as `#"two words"` when needed |
| `lacks_tags` | `-#tag`, quoted the same way |
| `type` | `type:<value>` |
| `is_favorite: true` | `❤️` |
| `is_tagged: false` | `notag:true` |
| `created.gte` / `created.lte` | `created:>YYYY-MM-DD` / `created:<YYYY-MM-DD` |
| `collection_ids` with one id | collection in the URL path |
| `collection_ids` with several ids | refused: `-32602`, the operator cannot express OR over collections |
| `sort` | `relevance`→`score`, `created_desc`→`-created`, `created_asc`→`created`, `random`→fetch then shuffle locally |
| `url_pattern` | a single `*text*` becomes `link:text`; any other wildcard is refused with `-32602` |
| `bookmark_ids`, `exclude_ids` | applied locally to the returned page |
| `is_duplicate`, `has_broken_link`, `has_highlights` | refused with `-32602` and a message to retry without `query`; these need backend computation |

Refusals are deliberate. Silently ignoring a filter would return wrong results, which is worse than a clear error.

- Pagination: REST caps `perpage` at 50. The proxy loops pages until `limit` (default 30, cap 150) is satisfied or the result set ends, then stops. `page` in the arguments shifts the window.
- Result shape: REST items are normalized to the MCP bookmark shape — `bookmark_id`, `title`, `link`, `tags`, `collection_id`, `created`, `type`, plus `excerpt` and `note` when present, because the search may have matched them. The response is `{"bookmarks": [...]}` like the upstream tool, so the model sees one shape.

## Error mapping

| Upstream | Proxy answer |
| --- | --- |
| unreachable, DNS, connect timeout | `-32603` `raindrop upstream unreachable: <reason>` |
| read timeout (60 s) | `-32603` `raindrop upstream timed out` |
| 401, 403 | `-32001` `raindrop token rejected` |
| 429 | `-32002` `raindrop rate limit, retry after <n>s` |
| 5xx | `-32603` `raindrop upstream error <status>` |
| 200 with an empty body on a request | `-32603` `empty upstream response` |

## Observability

`RAINDROP_MCP_DEBUG=1` logs one line per request to stderr: method, tool, backend (mcp or rest), upstream status, duration. The token and bookmark content are never logged; request bodies are truncated to 200 characters.

## Testing

A fake upstream runs in a thread on `127.0.0.1` and serves canned MCP and REST answers. The proxy is driven as a subprocess with JSON-RPC lines on stdin, so the tests cover the real framing rather than internal functions.

1. `tools/list` returns exactly the six names, `find_bookmarks` has `query` and no `search`.
2. `notifications/initialized` produces no stdout line and no upstream request.
3. `tools/call` on an allowed tool without `query` forwards arguments unchanged to the MCP upstream.
4. A call to `merge_collections` is refused locally and never reaches the upstream.
5. SSE-encoded and plain-JSON MCP answers both parse.
6. 200 with an empty body is an error for a request, not a crash.
7. 401, 429, and a connection refusal map to the codes above.
8. A malformed line yields `-32700` and the process stays alive.
9. `query` alone hits `/rest/v1/raindrops/0?search=<query>` and the answer is normalized.
10. `query` with `has_tags`, `lacks_tags`, `exclude`, `type`, `created`, and one `collection_id` builds the expected search string and path.
11. `query` with several `collection_ids`, an unsupported `url_pattern`, or `has_broken_link` is refused with `-32602` and no network call.
12. Pagination stops at `limit` and at the end of the result set.
13. EOF on stdin exits 0.

## Rollout and rollback

Order: Codex first, because it removes a dependency; then OpenCode; then Claude Code; then Antigravity, which cannot be tested while its quota is exhausted. Each harness keeps the old entry in a comment for one day.

Rollback is one line per harness: point it back at the URL, or restore `mcp-remote` in Codex.

## Risks

- **Schema drift.** A renamed argument upstream breaks a call the allowlist still permits. The proxy forwards errors verbatim, so the failure is visible, and `--check` prints the upstream tool count to notice change. The `query` translation depends on Raindrop's search operators, which are documented but not versioned; a change there is caught by the translation tests.
- **Two result shapes.** `query` results come from REST and the rest from MCP. Normalization makes them look alike, but a field added upstream will appear only on the MCP path until the normalizer is updated.
- **SSE parsing.** A malformed event stream could swallow an answer. Covered by test 5 and by treating an unparsable body as an error rather than an empty result.
- **Single point of failure.** If the proxy crashes, the harness loses the tools until restart. It is a 350-line stdlib script with no state, so the failure mode is a clean exit, not corruption.
