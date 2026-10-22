# Work Unit 01: the Raindrop MCP Worker

Status: `todo`
Depends on: none
Design: [Raindrop MCP Worker](20261021-raindrop-mcp-proxy-00-design.md)

## Deliverable

New private repository `diegobit/raindrop-mcp` with a Worker exposing six MCP tools on `/mcp`, plus its vitest suite. Modeled on `~/code/icloud-mail-proxy`, which is the working precedent: `agents/mcp` handler, `@modelcontextprotocol/sdk`, zod, wrangler profiles.

## Detailed Specifications

1. **Scaffolding:**
   - `gh repo create diegobit/raindrop-mcp --private --clone` under `~/code/raindrop-mcp`.
   - `package.json` dependencies: `agents`, `@modelcontextprotocol/sdk`, `zod`. Dev: `wrangler`, `typescript`, `vitest`, `@cloudflare/workers-types`. Node 24, `npm ci`.
   - Scripts mirroring the precedent: `test` (`vitest run`), `typecheck` (`tsc --noEmit`), `dev` (`wrangler dev -c wrangler.base.jsonc`), `check:bundle` (`wrangler deploy --dry-run -c wrangler.base.jsonc`), `deploy:production`.
   - `wrangler.base.jsonc`: no `account_id`, no `routes`; `main: src/index.ts`, `compatibility_date` matching the precedent, `nodejs_compat`, `workers_dev: true`, vars `RAINDROP_REST_URL` and `RAINDROP_MCP_URL`, and one rate-limit binding for `/mcp`.
   - `deploy-profiles.jsonc`: `production` → `raindrop-mcp.diegobit.com`, `workers_dev: false`, `custom_domain: true`.

2. **`src/auth.ts`:**
   - `extractBearer(request)` with the same `^Bearer (.+)$` rule as the precedent.
   - `tokenMatches(presented, secret)`: SHA-256 both values, compare with `crypto.subtle.timingSafeEqual`; an empty secret never matches.
   - `json(body, status, headers)` and `withNoStore(response)` helpers.

3. **`src/index.ts`:**
   - Route `POST|GET|DELETE /mcp` only; everything else `404`.
   - Extract and verify the bearer before building a server; on failure `401` with `WWW-Authenticate: Bearer` and no detail.
   - Rate limit keyed by the token digest: `env.MCP_LIMITER.limit({ key })`; on failure `429` with `Retry-After: 60`.
   - `createMcpHandler(() => buildServer(env))` with a fresh server per request.
   - Every response through `withNoStore`.

4. **`src/rest.ts`:**
   - `call(env, path, init)` with base `env.RAINDROP_REST_URL`, `Authorization: Bearer env.RAINDROP_TOKEN`, `Accept: application/json`, `AbortSignal.timeout(60_000)`.
   - Typed helpers: `listRaindrops(collection, params)`, `listCollections()`, `listChildren()`, `createRaindrops(items)`, `updateRaindrop(id, body)`, `moveToTrash(id)`.
   - One error type carrying a short, user-safe message per the design's status mapping; no response body echoed into errors except Raindrop's own `errorMessage` truncated to 200 characters.
   - No retries anywhere.

5. **`src/content.ts`:**
   - Per-isolate `let session: Promise<void> | null`, resolving after `initialize` and `notifications/initialized`; the empty 200 on the notification is expected and ignored.
   - `fetchContent(env, bookmarkId)`: `POST` a `tools/call` for `fetch_bookmark_content`, decode `structuredContent` first then the first `content` item of type `text`, and return `{id, title, url, text}` from `bookmark`.
   - `AbortSignal.timeout(30_000)`; on any failure throw the same error type so the tool answers `isError`.
   - A missing or empty `body` throws "no saved content for this bookmark".

6. **`src/mcp.ts`:** register six tools on `McpServer` with zod schemas and `.strict()`.
   - `find_bookmarks({query?, collection?, sort?, limit?, page?})`: defaults 0/`newest`/20/0 with `limit` 1–50 and `page` ≥ 0. Builds `/raindrops/{collection}?search&sort&perpage&page`, maps `count→total` and `_id→id`, `collection.$id→collection_id`, `link→url`, drops empty `excerpt`/`note`. `relevance` without `query` → `errorResult`, not a protocol error.
   - `find_collections()`: merge `/collections` and `/collections/childrens` by id, add `system: {unsorted: -1, trash: -99}`.
   - `fetch_bookmark_content({bookmark_id})`: delegates to `content.ts`.
   - `create_bookmarks({items})` with `items` 1–100: one `POST /raindrops`, wire `url→link`, `collection→{"$id": n}`; answer per index `created/failed/uncertain`. A transport failure on the single call marks every item `uncertain`, because the commit is unknown.
   - `update_bookmarks({bookmark_ids, title?, note?, tags?, favorite?, collection?})` with 1–25 ids: sequential `PUT /raindrop/{id}` (singular), `favorite→important` preserving `false`, `tags` replacing. Stop at the first 429, remainder `unattempted`. Transport failure → `uncertain` for that id and stop.
   - `delete_bookmarks({bookmark_ids})` with 1–25 ids: sequential `PUT /raindrop/{id}` with `{"collection": {"$id": -99}}`. Never `DELETE`. Same stop rule and buckets.
   - Every handler wraps work in a guard that turns the shared error type into `errorResult`; partial writes return the bucket object alongside `isError`.

7. **Tests (`test/`):**
   - `auth.test.ts`: missing, malformed, wrong and correct bearer; empty secret.
   - `rest.test.ts` with `vi.stubGlobal("fetch")`: URL and query construction for every helper, wire mappings, status mapping, assignment of the timeout signal.
   - `content.test.ts`: `structuredContent`, text-JSON, `isError`, empty body, timeout, and that a second call reuses the initialized session.
   - `mcp.test.ts` over `InMemoryTransport`: the six names, total declaration size under 8,000 characters, `relevance` without `query` is `isError`, `.strict()` rejects an unknown argument, a partial write returns buckets with `isError`.
   - No test touches the network; no test reads a real token.

8. **Docs in the repo:** `README.md` (what it is, the six tools, the two secrets), `DEPLOY.md` (bundle check, secrets, deploy, curl verification), and `plans/` only if a decision needs recording.

## Acceptance

- `npm test`, `npm run typecheck`, `npm run check:bundle` all pass.
- `wrangler dev` plus curl: `initialize` and `tools/list` return six tools, and `notifications/initialized` gets an empty response with a content type.
- No secret appears in the repository, in `wrangler.base.jsonc`, or in logs.
- The declaration total is under 8,000 characters, asserted by a test.
