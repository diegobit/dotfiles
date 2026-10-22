# Work Unit 02: deployment and harness wiring

Status: `todo`
Depends on: 01
Design: [Raindrop MCP Worker](20261021-raindrop-mcp-proxy-00-design.md)

## Deliverable

The Worker live at `https://raindrop-mcp.diegobit.com/mcp`, four harnesses pointing at it, and `docs/mcp-setup.md` describing the new wiring. No `mcp-remote`, no per-machine install.

## Detailed Specifications

1. **Deploy:**
   - `npm run check:bundle` must not create routes or secrets; confirm the dry run output.
   - `wrangler secret put RAINDROP_TOKEN` with the account token; `wrangler secret put MCP_TOKEN` with a freshly generated 32-byte hex value. Record only where they live, never the values.
   - `npm run deploy:production`, then `curl` the custom domain: `initialize`, `tools/list` (six names), and one `tools/call` to `find_collections`. Confirm `Cache-Control: no-store` on every response and `401` without a bearer.
   - First the custom domain, then Cloudflare Access if the user wants it. Access would require service tokens for every client; recommend keeping the bearer model instead, as `icloud-mail-proxy` does.

2. **Client token on the machines:**
   - Write the `MCP_TOKEN` value to `~/.raindrop-mcp-token`, mode 600, on the Linux machine and on the Mac. It is not the Raindrop token and never goes into a repository.
   - `docs/mcp-setup.md` gains this file and drops `~/.raindrop-token` from the harness section; the Raindrop token now exists only in the Worker secret.

3. **OpenCode:**
   - Remote entry, `oauth: false`, header `Authorization: Bearer {file:~/.raindrop-mcp-token}`, URL `https://raindrop-mcp.diegobit.com/mcp`.
   - Same entry in `~/.config/opencode/opencode.json` on Linux and in the repository `opencode.jsonc` for the Mac.
   - Keep the deny rules for `delete_collections` and `delete_tags` as a backstop; the Worker never exposes them.

4. **Claude Code:**
   - `claude mcp remove raindrop -s user`, then
     `claude mcp add --scope user --transport http raindrop https://raindrop-mcp.diegobit.com/mcp --header "Authorization: Bearer $(cat ~/.raindrop-mcp-token)"`.
   - Keep the existing `mcp__raindrop__delete_*` deny entries.

5. **Codex:**
   - Try the native form first, since the Worker answers the notification correctly:
     `[mcp_servers.raindrop]` with `url = "https://raindrop-mcp.diegobit.com/mcp"` and `http_headers = { Authorization = "Bearer <token>" }`.
   - If Codex still rejects the transport, fall back to `npx -y mcp-remote <url> --header "Authorization: Bearer <token>" --transport http-only`. Record which one was needed in `docs/mcp-setup.md`; do not assume.
   - Remove the current `mcp-remote` entry pointing at `api.raindrop.io`.

6. **Antigravity:**
   - `agy mcp remove raindrop`, then `agy mcp add --header "Authorization: Bearer $(cat ~/.raindrop-mcp-token)" raindrop https://raindrop-mcp.diegobit.com/mcp`.
   - Verification is deferred: the Antigravity CLI quota is exhausted until roughly 25 October. Mark it pending; do not claim it works.

7. **Documentation (`docs/mcp-setup.md`):**
   - Rewrite the Raindrop section: one URL, two secrets with distinct roles, the six tools and their limits, keyword `query` with Raindrop operators, saved text through the official server, Trash-only deletion, no semantic or page-body search.
   - Drop the `raindrop-mcp` local command, the Python path, and the `mcp-remote` paragraph if the native form worked.
   - Point to `~/code/raindrop-mcp/DEPLOY.md` for deployment and secrets.

8. **Verification per harness** (a configuration line is not proof; a completed turn is):
   - `curl` assertions from step 1 pass.
   - OpenCode: `opencode mcp list` shows `connected`; one turn calling `find_bookmarks` with `query`, then `fetch_bookmark_content` on a returned id.
   - Claude Code: `claude mcp get raindrop` shows the URL; one turn doing the same two calls.
   - Codex: `codex mcp get raindrop` shows the chosen transport; one non-interactive turn doing the same two calls.
   - Antigravity: `agy mcp list` shows the entry; a turn deferred until the quota resets.
   - In each harness, confirm the six names are present and `delete_collections`/`delete_tags` are absent.

9. **Rollback:**
   - Point the four harnesses back at `https://api.raindrop.io/rest/v2/ai/mcp` with the account token, restoring `mcp-remote` for Codex only.
   - The Worker can stay deployed and unused; no data lives in it. No commented-out duplicates in the configs.

## Acceptance

- The Worker answers six tools at the custom domain over HTTPS with the bearer, and `401` without it.
- Three harnesses verified by a completed turn, including one `query` search and one content fetch; Antigravity recorded as pending.
- No token in any tracked file; `~/.raindrop-mcp-token` is the only client secret on each machine.
