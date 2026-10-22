# Work Unit 01: the Raindrop MCP Worker

Status: `todo`
Depends on: none
Design: [Raindrop MCP Worker](20261021-raindrop-mcp-proxy-00-design.md)

## Deliverable

New private repository `diegobit/raindrop-mcp` with a Worker exposing six MCP tools on `/mcp`, plus its vitest suite. Structure and deployment machinery are copied from `~/code/icloud-mail-proxy`, the working precedent.

## Detailed Specifications

1. **Scaffolding:**
   - `gh repo create diegobit/raindrop-mcp --private --clone` under `~/code/raindrop-mcp`.
   - Dependencies pinned to the versions proven in the precedent: `agents@0.17.4`, `@modelcontextprotocol/sdk@1.29.0`, `zod@4`. Dev: `wrangler@4`, `typescript@5`, `vitest@3`, `@cloudflare/workers-types@4`. Node 24, `npm ci`.
   - Scripts copied from the precedent: `test`, `typecheck`, `dev`, `check:bundle`, `setup`, `deploy`, `deploy:production`, `config` (`scripts/deploy.mjs --print-config`).
   - `wrangler.base.jsonc`: no `account_id`, no `routes`; `main: src/index.ts`, a `compatibility_date`, `nodejs_compat`, `workers_dev: true`, vars `RAINDROP_REST_URL` and `RAINDROP_MCP_URL`, and the rate-limit binding below.
   - Copy `scripts/deploy.mjs` and `scripts/lib/*.mjs` (config composer, target resolution, wrangler adapter). `deploy-profiles.jsonc` is a repository convention consumed by that script, not by wrangler directly; do not claim otherwise.
   - `deploy-profiles.jsonc`: `production` → `raindrop-mcp.diegobit.com`, `workers_dev: false`, `custom_domain: true`.

2. **Rate-limit binding**, top-level in `wrangler.base.jsonc`:
   ```jsonc
   "ratelimits": [{ "name": "MCP_LIMITER", "namespace_id": "2001", "simple": { "limit": 60, "period": 60 } }]
   ```
   `namespace_id` must be unique in the account. The design explains why this is burst protection, not a global quota: one `update_bookmarks` call can fan out to 25 REST requests.

3. **`src/auth.ts`:**
   - `extractBearer(request)` with the precedent's `^Bearer (.+)$` rule.
   - `tokenMatches(presented, secret)`: SHA-256 both values, compare with `crypto.subtle.timingSafeEqual`; an empty secret never matches.
   - `json()` and `withNoStore()` helpers.

4. **`src/index.ts`:**
   - Route `POST|GET|DELETE /mcp` only; everything else `404`.
   - Verify the bearer before building a server; on failure `401` with `WWW-Authenticate: Bearer` and no detail.
   - Then the rate limit keyed by the token digest: `env.MCP_LIMITER.limit({ key })`; on failure `429` with `Retry-After: 60`.
   - Build a fresh server per request and pass the **instance**:
     `createMcpHandler(buildServer(env), { route: "/mcp" })`. The installed `agents@0.17.4` signature takes a `McpServer`, not a factory; a function fails typechecking and has no `.connect()`.
   - Every response through `withNoStore`.

5. **`src/rest.ts`:**
   - `call(env, path, init)` with base `env.RAINDROP_REST_URL`, `Authorization: Bearer env.RAINDROP_TOKEN`, `Accept: application/json`, and `Content-Type: application/json` plus a JSON-serialized body on every write; `AbortSignal.timeout(60_000)`.
   - Typed helpers: `listRaindrops(collection, params)`, `listCollections()`, `listChildren()`, `createRaindrops(items)`, `updateRaindrop(id, body)`, `moveToTrash(id)`.
   - One error type carrying a short, user-safe message per the design's status mapping; Raindrop's own `errorMessage` truncated to 200 characters.
   - No retries.

6. **`src/content.ts`:**
   - Per-isolate `let session: Promise<void> | null`. On rejection, **clear it** so the next call initializes afresh; a transient failure must not poison the isolate.
   - `initialize` with `protocolVersion: "2025-06-18"`, empty capabilities, a named `clientInfo`; then `notifications/initialized`, whose **202 with an empty body and no content type** is the expected answer and is ignored.
   - `fetchContent(env, bookmarkId)`: `tools/call` for `fetch_bookmark_content`; decode `structuredContent` first, else the first `content` item of type `text` parsed as JSON; read `bookmark.body`, `title`, `link`.
   - Before implementing the decoder, capture one sanitized real response into `test/fixtures/content.json` (fields only, no personal bookmark text in a committed fixture; replace text with a placeholder). The envelope is therefore verified, not assumed.
   - `AbortSignal.timeout(30_000)`; missing or empty `body` throws "no saved content for this bookmark".

7. **`src/mcp.ts`:** six tools on `McpServer` with zod objects. Keep the strict objects whole when registering; passing only `.shape` loses strictness.
   - `find_bookmarks({query?, collection?, sort?, limit?, page?})`: defaults 0/`newest`/20/0, `limit` 1–50, `page` ≥ 0. Path `/raindrops/{collection}` with `search`, `sort`, `perpage`, `page`; map `count→total`, `_id→id`, `collection.$id→collection_id`, `link→url`; drop empty `excerpt`/`note`. `relevance` without `query` → `errorResult`.
   - `find_collections()`: merge `/collections` and `/collections/childrens`, add `system: {unsorted: -1, trash: -99}`.
   - `fetch_bookmark_content({bookmark_id})`: delegates to `content.ts`.
   - `create_bookmarks({items})` 1–100: one `POST /raindrops`, `url→link`, `collection→{"$id": n}`. Correlate results conservatively: match returned items to inputs by `link`; an input with no returned item is `uncertain`, never `failed`; a returned `{"result": false}` entry is `failed` with its `errorMessage`.
   - `update_bookmarks({bookmark_ids, title?, note?, tags?, favorite?, collection?})` 1–25: sequential `PUT /raindrop/{id}` (singular), `favorite→important` preserving `false`, `tags` replacing. Stop at the first 429, remainder `unattempted`. Transport failure → `uncertain` for that id and stop.
   - `delete_bookmarks({bookmark_ids})` 1–25: sequential `PUT /raindrop/{id}` with `{"collection": {"$id": -99}}`. Never `DELETE`. Same stop rule and buckets.
   - Every handler is wrapped by a guard turning the shared error type into `errorResult`; a partial write returns the bucket object **and** `isError`.

8. **Tests (`test/`):**
   - `vitest.config.ts` copies the precedent's `setupFiles: ["test/support/workers-crypto.ts"]` and the shim: Node's WebCrypto has no `timingSafeEqual`, Workers does.
   - `auth.test.ts`: missing, malformed, wrong, correct bearer; empty secret.
   - `rest.test.ts` with `vi.stubGlobal("fetch")`: URL and query construction, wire mappings, `Content-Type` on writes, status mapping, timeout signal, 429 stop rule.
   - `content.test.ts`: `structuredContent`, text-JSON, `isError`, empty body, timeout, session reuse, and **failure then recovery** (rejected promise cleared).
   - `mcp.test.ts` over `InMemoryTransport`: six names, declaration total under 8,000 characters, `relevance` without `query` is `isError`, unknown argument yields `isError: true` (SDK 1.29.0 returns a tool error for schema violations, not a JSON-RPC error), a partial write returns buckets with `isError`.
   - `create.test.ts`: correlation by `link`, unmatched input → `uncertain`, `result: false` → `failed`.
   - No test touches the network; no test reads a real token.

9. **Docs in the repo:** `README.md` (what it is, the six tools, the two secrets), `DEPLOY.md` (config composition, secret upload with the generated production config, deploy, curl verification).

## Acceptance

- `npm test`, `npm run typecheck`, `npm run check:bundle` pass.
- `wrangler dev` plus curl: `initialize`, `tools/list` (six names), and `notifications/initialized` answering **202 with an empty body**; a `tools/call` returns `content` with JSON text.
- The declaration total is under 8,000 characters, asserted by a test.
- No secret in the repository, in `wrangler.base.jsonc`, or in logs.
