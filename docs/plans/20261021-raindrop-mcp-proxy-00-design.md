# Design: Raindrop MCP Worker

Status: `todo`
Units: [01 worker](20261021-raindrop-mcp-proxy-01-proxy.md), [02 integration](20261021-raindrop-mcp-proxy-02-integration.md)

## Problem

Raindrop's official MCP server exposes 21 tools. Three carry a `search` parameter that fails on the free plan with `Semantic search is only available to Pro users`, and a parameter cannot be hidden by harness permission rules, which act on whole tools. The server is also unusable by Codex natively: it answers `notifications/initialized` with HTTP 200, `content-length: 0`, and no content type, which Codex's MCP client treats as fatal. Four harnesses currently reach it through three different configurations and, for Codex, through `npx mcp-remote`.

## Decision

Host a six-tool Raindrop MCP server on **Cloudflare Workers**, modeled on `~/code/icloud-mail-proxy`, which already runs an authenticated remote MCP from a Worker with `agents/mcp`, the official TypeScript SDK, zod, vitest, and wrangler deploy profiles.

The tool contract from the previous local-adapter design survives unchanged: six frozen tools, one backend each, REST for five and the official MCP server only for saved page text.

Rejected alternatives:

- **Local Python adapter in dotfiles.** Works, but requires a per-machine install, a symlink, and a config entry per harness; the Worker needs a URL and a header. The Python plan is superseded, not merged.
- **Keeping the 21-tool server.** Leaves broken search, reachable destructive tools, and the Codex bridge.
- **Transparent proxy with filter translation.** Reimplementing Raindrop's filter vocabulary in search operators is subtle work for filters that are Pro-only or marginal here.
- **This repository, or a branch of it.** `raindrop-rss` is a deployed service with a `cloudflare` worktree branch for its multi-user variant. A third unrelated product inside it would share history, AGENTS.md, and CI with nothing in common. Undoing that later costs more than a new repo costs now.
- **A `raindrop-tools` monorepo with `rss-service/` and `mcp-server/`.** Coherent only as an umbrella for deployables that share code; these share none. The move touches compose paths, the Dockerfile, the Geekom checkout, and the `cloudflare` worktree branch, which would have to be restructured and rebased. Deferred as its own migration, not part of this work.

## Deployment location

New private repository `diegobit/raindrop-mcp`, structured like `icloud-mail-proxy`:

```
wrangler.base.jsonc        portable defaults, no account id, no routes
deploy-profiles.jsonc      production route: raindrop-mcp.diegobit.com
DEPLOY.md                  secrets, deploy, verification
src/index.ts               fetch handler: auth, /mcp route, no-store
src/auth.ts                bearer extraction and constant-time compare
src/mcp.ts                 six tools on McpServer, zod schemas
src/rest.ts                Raindrop REST v1 client
src/content.ts             official MCP client for saved page text
src/types.ts               Env and shared shapes
test/*.test.ts             vitest, fetch stubbed
```

dotfiles keeps only the harness entries: URL plus bearer.

## Architecture

```
harness ──HTTPS + bearer──→ Worker /mcp (agents/mcp handler, SDK, zod)
                              ├── REST /rest/v1          (find, collections, create, update, Trash move)
                              └── MCP /rest/v2/ai/mcp    (saved page text only)
```

- The MCP transport, sessions, SSE framing, and notification handling come from `createMcpHandler`, not from our code. Native Codex support is the target; it is verified by an early probe before any harness is touched, and the documented fallback is `npx mcp-remote` if that probe fails.
- A fresh `McpServer` is built per request, as in `icloud-mail-proxy`; no module-level server object.
- The Worker holds no bookmark state. The only retained state is a per-isolate promise for the upstream content session.

## Auth

Two secrets, never one:

| Secret | Where it lives | Used for |
| --- | --- | --- |
| `RAINDROP_TOKEN` | Worker secret only | Calls to Raindrop REST and to the official MCP |
| `MCP_TOKEN` | Worker secret, and each harness's local config (600 file, `~/.raindrop-mcp-token`) | What clients present to the Worker |

`Authorization: Bearer <MCP_TOKEN>` is compared against the secret by SHA-256 digest with a constant-time compare, as in `icloud-mail-proxy/src/auth.ts`. A missing or wrong token gets `401` with `WWW-Authenticate: Bearer` and no detail. Every response carries `Cache-Control: no-store`.

Rotating the client token does not touch the Raindrop account token, and a leaked harness config does not expose the account token.

## Transport and limits

- Only `POST`/`GET`/`DELETE /mcp` are routed; anything else is `404`.
- The handler answers `notifications/initialized` to harnesses with **202, empty body, no content type**, which satisfies the protocol. That is a different response from the official server's empty **200** described in the Problem.
- A Workers rate-limit binding keyed by the token digest gives **approximate burst protection**. It is not a global quota: one `update_bookmarks` call can issue up to 25 REST requests, so one admitted MCP request can fan out well past the binding's nominal limit. The binding is location-local and best-effort; Raindrop's own 429 handling remains the real ceiling.
- Outbound calls use `fetch` with `AbortSignal.timeout`, 60 s for REST and 30 s for content.
- No queue, no retry, no replay. A write that may have arrived is reported `uncertain`.

## Tool contract (frozen)

Schemas are zod objects with `.strict()`, so unknown arguments are rejected by the SDK before the handler runs.

### `find_bookmarks`

`query?` (Raindrop search syntax, operators included), `collection?` (default 0), `sort?` (`relevance` requires `query`, `newest` default, `oldest`), `limit?` (1–50, default 20), `page?` (0-based, default 0).

Backend `GET /rest/v1/raindrops/{collection}?search=&sort=&perpage=&page=`, sort map `relevance→score`, `newest→-created`, `oldest→created`. One page per call. Answer `{total, page, items: [{id, title, url, tags, collection_id, created, type, excerpt?, note?}]}`.

### `find_collections`

No arguments. `GET /collections` plus `GET /collections/childrens`, merged by id. Answer `{items: [{id, title, parent_id, count}], system: {unsorted: -1, trash: -99}}`.

### `fetch_bookmark_content`

`bookmark_id` (integer). Backend: official MCP `tools/call`. Answer `{id, title, url, text}`. Missing or empty body is an error result ("no saved content"), never an empty success, and never a substitute web fetch.

### `create_bookmarks`

`items` 1–100 of `{url, title?, note?, tags?, collection?}`. Wire mapping `url→link`, `collection→{"$id": n}`. Answer `{created: [{index, url, id}], failed: [{index, url, error}], uncertain: [{index, url}]}`.

### `update_bookmarks`

`bookmark_ids` 1–25, plus `title?`, `note?`, `tags?` (replaces), `favorite?` (wire `important`, `false` preserved), `collection?` (wire `{"$id": n}`). Backend `PUT /rest/v1/raindrop/{id}` — singular; the plural route is collection-scoped and must never be used per item. Sequential, stop at the first 429 and mark the rest `unattempted`. Answer `{updated, failed, unattempted, uncertain}`.

### `delete_bookmarks`

`bookmark_ids` 1–25. Backend `PUT /rest/v1/raindrop/{id}` with `{"collection": {"$id": -99}}`, a move to Trash. `DELETE` is not used: on an already-trashed bookmark it deletes permanently. Permanent deletion is not exposed. Same cap, order, 429 rule and buckets.

## Results and errors

- Success: `content: [{type: "text", text: "<compact json>"}]`, plus `structuredContent` when the payload is an object.
- Execution failure (upstream 4xx/5xx, timeout, unreachable, cross-field refusal): `isError: true` with a short message. Zod rejects unknown or malformed arguments before the handler, and SDK 1.29.0 surfaces that as `isError: true` too, not as a JSON-RPC error.
- Partial write: `isError: true` **and** the full bucket object, so per-item outcomes survive.
- Status mapping: 401/403 `raindrop token rejected`; 429 `raindrop rate limit, retry after <n>s`; 5xx `raindrop upstream error <status>`.

## Content backend details

- `initialize` once per isolate with `protocolVersion: "2025-06-18"`, empty capabilities, a named `clientInfo`; keep the promise, not the object, and clear it when it rejects so a single transient failure does not poison the isolate.
- Send `notifications/initialized` once and ignore its **200, empty body, no content type** answer: never attempt to parse it as JSON. This is the official server's behaviour, the same response that breaks Codex; our own client must tolerate it.
- Decode `structuredContent` first, else parse the first `content` item of type `text` as JSON; `bookmark.body` is the text. The envelope is confirmed against one captured sanitized response before the decoder is written, not assumed.
- A failure leaves the other five tools untouched.

## Observability

One structured `console.log` per tool call: tool name, backend, upstream status, duration. Never the token, headers, notes, or bookmark text. Workers Logs retains it; `wrangler tail` during rollout.

## Testing

- `vitest run`, fetch stubbed with `vi.stubGlobal`; no network.
- `rest.ts`: URL and query construction, wire mappings (`url→link`, `favorite→important` including `false`, `collection→{"$id"}`), error mapping, 429 stop rule, four buckets, per-index results for create.
- `content.ts`: `structuredContent`, text-JSON, `isError`, empty body, timeout.
- `mcp.ts`: build the server, drive it over `InMemoryTransport`, assert the six names, the total declaration size under 8,000 characters, and that `relevance` without `query` returns `isError` rather than a protocol error.
- `auth.ts`: constant-time compare, malformed header, wrong token, absent secret.
- Integration: `wrangler dev` plus curl for `initialize` and `tools/list`, asserting the six names and a **202 with an empty body** for `notifications/initialized`.

## Deployment

- `wrangler.base.jsonc` holds portable defaults; `deploy-profiles.jsonc` maps `production` to `raindrop-mcp.diegobit.com` with `workers_dev: false`, mirroring `icloud-mail-proxy`.
- `npm run check:bundle` (dry-run) must not create routes or secrets.
- Generate the production config with `npm run config -- --profile production` and upload both secrets against it: `wrangler secret put RAINDROP_TOKEN -c <generated-config>` and `wrangler secret put MCP_TOKEN -c <generated-config>`. A bare `wrangler secret put` does not discover `wrangler.base.jsonc` and can target the wrong Worker.
- `DEPLOY.md` records the order: bundle check, secrets, deploy, curl verification, harness wiring.

## Risks

- **Workers Free CPU.** Free allows 10 ms of CPU per invocation; network waiting is excluded but server construction, zod validation, parsing a large article, and serialization count. This is a **gate before any harness is switched**, measured from Workers Logs invocation CPU (dashboard or Logs, not `wrangler tail` duration) on synthetic payloads: 50 results, 100 creates, 25 updates, one large article, cold and warm. If it exceeds the allowance, Workers Paid ($5/month) is required before cutover.
- **Credential recovery.** Worker secrets are write-only: the account token cannot be read back. Keep a local copy at `~/.raindrop-token` (600) until the Worker is verified, because rollback to the official URL needs it. Neither copy belongs in a repository.
- **New deploy surface.** The Worker is one more thing that can be down; if it is, all four harnesses lose bookmarks, while the previous local design only depended on Raindrop.
- **Token in Cloudflare.** The account token now lives in a secret on a public endpoint. Mitigated by two secrets, constant-time compare, a rate-limit binding, and no token in responses or logs.
- **Upstream content service.** Raindrop documents its MCP as a Pro beta while it answers free-account tokens. Only `fetch_bookmark_content` depends on it.
- **SDK and handler drift.** `agents/mcp` and the MCP SDK are versioned dependencies; pin them, and re-run the integration test after upgrades.
- **Cold starts.** First request after idle is slower; acceptable for occasional bookmark use.

## Non-goals

- Multi-user accounts, per-user tokens, OAuth. One deployment, one library.
- Semantic or page-body search over `query`; both are Pro at the account level.
- Duplicate, broken-link, highlight filters, multi-collection OR, random ordering.
- Local index, cache, queue, retries, replay.
- Permanent deletion.
- MCP resources, prompts, sampling.
