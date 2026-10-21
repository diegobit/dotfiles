# Design: Raindrop MCP proxy

Status: `todo`
Units: [01 proxy](20261021-raindrop-mcp-proxy-01-proxy.md), [02 integration](20261021-raindrop-mcp-proxy-02-integration.md)

## Problem

The official server at `https://api.raindrop.io/rest/v2/ai/mcp` exposes 21 tools, about 20,600 characters of schema, roughly 5,700 tokens in every session of every harness that injects native tool definitions. Three of those tools carry a `search` parameter that fails on the free plan with `Semantic search is only available to Pro users`; the parameter cannot be hidden, because harness permission rules act on whole tools.

Codex cannot use the server directly. After `initialize`, the server answers `notifications/initialized` with HTTP 200, `content-length: 0`, and no content type. Codex's MCP client treats the missing content type as fatal and drops the connection, which is why it currently runs through `npx mcp-remote`.

## Goals

1. One local stdio MCP server, no third-party dependency, that fronts the official one.
2. Expose exactly six tools: `find_bookmarks`, `find_collections`, `fetch_bookmark_content`, `create_bookmarks`, `update_bookmarks`, `delete_bookmarks`.
3. Remove the `search` property from the `find_bookmarks` and `find_collections` schemas, so the parameter no longer exists for the model.
4. Answer `notifications/initialized` locally, which removes the Codex transport failure and `mcp-remote` with it.
5. Keep the token out of harness configuration: read `~/.raindrop-token` or `RAINDROP_TOKEN`.

## Non-goals

- A keyword search tool backed by the REST `?search=` parameter. It works on free, but it is a seventh tool and the point of this change is fewer tools. Revisit only if absence hurts in practice.
- Caching, retries, or rate-limit queuing. The upstream allows 120 requests per minute and the proxy adds no load.
- MCP resources, prompts, or sampling. Only tools.
- Filtering writes beyond the allowlist. `delete_bookmarks` stays, as decided.

## Architecture

```
harness (stdio, line-delimited JSON-RPC)
    ↓
raindrop-mcp  ── allowlist ── schema rewrite ── stateless HTTP ─→ api.raindrop.io/rest/v2/ai/mcp
```

- Framing: one JSON-RPC message per line in both directions. stdout carries protocol frames only; every diagnostic goes to stderr.
- Upstream: `POST` with `Authorization`, `Content-Type: application/json`, `Accept: application/json, text/event-stream`. Parse a JSON body and an SSE body (`event:` / `data:` lines) the same way. An empty body is a valid answer, not an error.
- The server is stateless: it returned no `Mcp-Session-Id` in testing, so the proxy sends none. If one ever appears, forward it on subsequent calls.
- Notifications are never forwarded upstream. `notifications/initialized` and `notifications/cancelled` are accepted and dropped. This is deliberate: forwarding is what breaks Codex today.
- Unknown requests get `-32601`, malformed frames `-32700`, and the proxy keeps running. EOF on stdin exits 0.

## Tool allowlist and schema rewrite

| Tool | Exposed | Rewrite |
| --- | --- | --- |
| `find_bookmarks` | yes | delete `properties.search`; append to description: text search needs Pro, filter with tags, collection, url patterns, ids |
| `find_collections` | yes | delete `properties.search` |
| `fetch_bookmark_content` | yes | none |
| `create_bookmarks` | yes | none |
| `update_bookmarks` | yes | none |
| `delete_bookmarks` | yes | none |
| other 15 | no | absent from `tools/list`; a call returns `-32602 unknown tool` |

The allowlist is an allowlist, not a denylist: tools added upstream stay invisible until someone edits the list on purpose.

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

`RAINDROP_MCP_DEBUG=1` logs one line per request to stderr: method, tool, upstream status, duration. The token and bookmark content are never logged; request bodies are truncated to 200 characters.

## Testing

A fake upstream runs in a thread on `127.0.0.1` and serves canned JSON. The proxy is driven as a subprocess with JSON-RPC lines on stdin, so the tests cover the real framing rather than internal functions.

1. `tools/list` returns exactly the six names, and `find_bookmarks` has no `search` property.
2. `notifications/initialized` produces no stdout line and no upstream request.
3. `tools/call` on an allowed tool forwards arguments unchanged and returns the upstream payload.
4. A call to `merge_collections` is refused locally and never reaches the upstream.
5. SSE-encoded and plain-JSON upstream answers both parse.
6. 200 with an empty body is an error for a request, not a crash.
7. 401, 429, and a connection refusal map to the codes above.
8. A malformed line yields `-32700` and the process stays alive.
9. EOF on stdin exits 0.

## Rollout and rollback

Order: Codex first, because it removes a dependency; then OpenCode; then Claude Code; then Antigravity, which cannot be tested while its quota is exhausted. Each harness keeps the old entry in a comment for one day.

Rollback is one line per harness: point it back at the URL, or restore `mcp-remote` in Codex.

## Risks

- **Schema drift.** A renamed argument upstream breaks a call the allowlist still permits. The proxy forwards errors verbatim, so the failure is visible, and `--check` prints the upstream tool count to notice change.
- **SSE parsing.** A malformed event stream could swallow an answer. Covered by test 5 and by treating an unparsable body as an error rather than an empty result.
- **Single point of failure.** If the proxy crashes, the harness loses the tools until restart. It is a 300-line stdlib script with no state, so the failure mode is a clean exit, not corruption.
- **Duplicate maintenance.** Two places to update when Raindrop ships a new tool: the allowlist in the proxy and nothing else. That is the intended trade for a smaller catalog.
