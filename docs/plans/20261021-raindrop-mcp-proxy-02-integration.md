# Work Unit 02: harness integration

Status: `todo`
Depends on: 01
Design: [Raindrop MCP adapter](20261021-raindrop-mcp-proxy-00-design.md)

## Deliverable

All four harnesses launch the adapter, `install.sh` exposes it, `docs/mcp-setup.md` describes the six-tool contract, and Codex no longer uses `npx mcp-remote`.

## Detailed Specifications

1. **Command exposure:**
   - `bin/raindrop-mcp.py` is executable and keeps its shebang.
   - `install.sh` gains, next to the existing `tg` symlink:
     `ln -sf "$HOME/dotfiles/bin/raindrop-mcp.py" "$HOME/.local/bin/raindrop-mcp"`. That path is the macOS checkout.
   - On this Linux machine the checkout is `$HOME/code/dotfiles`, so the symlink is
     `ln -sf "$HOME/code/dotfiles/bin/raindrop-mcp.py" "$HOME/.local/bin/raindrop-mcp"`.
   - Every harness entry uses the absolute resolved path, not the bare command: Linux `/home/diego/.local/bin/raindrop-mcp`, macOS `/Users/diego/.local/bin/raindrop-mcp`. Resolve `$HOME` at configuration time so the files hold the literal path.
   - The script's interpreter is still resolved by `#!/usr/bin/env python3`, so `PATH` must contain a Python 3.9+ in the environment that launches the harness. Verify that explicitly on the Mac's GUI session.

2. **OpenCode:**
   - Replace the remote entry with `{"type": "local", "command": ["/home/diego/.local/bin/raindrop-mcp"]}` in `~/.config/opencode/opencode.json` (Linux) and in the repository `opencode.jsonc` (Mac, path adjusted for `/Users/diego`).
   - Keep the `permissions` deny rules for `raindrop_delete_collections` and `raindrop_delete_tags`. They are dead weight for the adapter, which exposes neither, and exist so a temporary rollback to the remote URL does not open them.
   - `oauth`, `headers`, and the `{file:~/.raindrop-token}` reference disappear from this entry.

3. **Claude Code:**
   - `claude mcp remove raindrop -s user`, then `claude mcp add --scope user raindrop -- /home/diego/.local/bin/raindrop-mcp`.
   - Keep `mcp__raindrop__delete_collections` and `mcp__raindrop__delete_tags` in `permissions.deny` for the same rollback reason.
   - `~/.claude.json` must contain no token and no header for this server.

4. **Codex:**
   - Replace the `mcp-remote` entry with `command = "/home/diego/.local/bin/raindrop-mcp"` under `[mcp_servers.raindrop]`.
   - Delete the `npx` arguments, the header argument, and the paragraph in the docs that justified the bridge.

5. **Antigravity:**
   - `agy mcp remove raindrop`, then `agy mcp add raindrop /home/diego/.local/bin/raindrop-mcp` (stdio).
   - `~/.gemini/config/mcp_config.json` must contain no token and no header; the repository example loses its `raindrop` entry.
   - Verification is deferred: the Antigravity CLI quota is exhausted until roughly 25 October. Record it as pending in the unit status; do not claim it works.

6. **Documentation (`docs/mcp-setup.md`):**
   - Rewrite the Raindrop section around the adapter: one local command, six tools, keyword `query` with Raindrop operators, saved text through the official server, Trash-only deletion.
   - State the free-plan boundary: no semantic search, no page-body search.
   - Remove the `mcp-remote` paragraph, the TOML `http_headers` snippet, and the per-harness token-header commands; replace them with the four `mcp add` lines that use the absolute path.
   - Keep `~/.raindrop-token` as the credential the adapter reads, with `RAINDROP_TOKEN` as an override; the harness never reads either one.

7. **Verification per harness** (a configuration line is not proof; a completed turn is):
   - `raindrop-mcp --check` exits 0: token present, MCP reachable, REST query answered, declarations under 8,000 characters.
   - OpenCode: `opencode mcp list` shows `connected`; one turn that calls `find_bookmarks` with `query` and returns a known bookmark, then `fetch_bookmark_content` on its id.
   - Claude Code: `claude mcp get raindrop` shows a stdio command; one turn doing the same two calls.
   - Codex: `codex mcp get raindrop` shows a local command, no `npx`; one non-interactive turn doing the same two calls.
   - Antigravity: `agy mcp list` shows the entry; a turn is deferred until the quota resets.
   - Confirm the six names and the absence of `delete_collections`/`delete_tags` in each harness's tool list.

8. **Rollback, one entry per harness:**
   - OpenCode and Claude: point back at `https://api.raindrop.io/rest/v2/ai/mcp` with the bearer header; the deny rules are already in place.
   - Codex: restore `npx -y mcp-remote … --transport http-only`, the only harness where the remote URL does not work natively.
   - Leave no commented-out duplicates in the configs; the git history is the record.

## Acceptance

- All four configurations start the same absolute path, and no token appears in any tracked file or any harness config.
- `--check` passes on this machine and after `install.sh` on the Mac.
- Three harnesses verified by a completed turn, including one `query` search and one content fetch; Antigravity recorded as pending.
