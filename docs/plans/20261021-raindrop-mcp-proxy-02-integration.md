# Work Unit 02: harness integration and migration

Status: `todo`
Depends on: 01
Design: [Raindrop MCP proxy](20261021-raindrop-mcp-proxy-00-design.md)

## Deliverable

All four harnesses launch `raindrop-mcp` instead of the remote URL, `install.sh` exposes the command, and `docs/mcp-setup.md` describes the new wiring. Codex drops `npx mcp-remote`.

## Detailed Specifications

1. **Command exposure:**
   - `bin/raindrop-mcp.py` is executable and keeps its shebang.
   - `install.sh` gains one line next to the existing `tg` symlink:
     `ln -sf "$HOME/dotfiles/bin/raindrop-mcp.py" "$HOME/.local/bin/raindrop-mcp"`.
   - On this machine create the same symlink by hand, since `install.sh` is macOS-only.

2. **OpenCode** (`~/.config/opencode/opencode.jsonc` in the repository, `opencode.json` on Linux):
   - Replace the remote entry with a local one:
     `{"type": "local", "command": ["raindrop-mcp"]}`.
   - Keep the `permissions` block as a backstop: `delete_collections` and `delete_tags` no longer exist behind the proxy, and stay blocked if a harness is rolled back to the URL.

3. **Claude Code:**
   - `claude mcp remove raindrop -s user` then `claude mcp add --scope user raindrop -- raindrop-mcp`.
   - Keep the `permissions.deny` entries in `~/.claude/settings.json` and in the repository copy, for the same backstop reason.
   - `~/.claude.json` loses the header and the token.

4. **Codex** (`~/.codex/config.toml`):
   - Replace the `mcp-remote` entry with:
     `[mcp_servers.raindrop]` / `command = "raindrop-mcp"`.
   - Confirm no `npx` remains for this server. The `mcp-remote` workaround and its explanation are deleted from the docs.

5. **Antigravity:**
   - `agy mcp remove raindrop`, then `agy mcp add raindrop raindrop-mcp` as a stdio server.
   - `~/.gemini/config/mcp_config.json` loses the header and the token, and the repository example loses the `raindrop` entry.
   - Verification is pending: the Antigravity CLI quota is exhausted for about 64 hours. Record that in the unit status, do not claim it works.

6. **Documentation** (`docs/mcp-setup.md`):
   - Rewrite the Raindrop section around the proxy: why it exists, the six tools, the removed `search` parameter, the token file, and `--check` as the health command.
   - Delete the `mcp-remote` paragraph and the TOML snippet it justified.
   - Keep the note that the free plan has no semantic search, now phrased as "the parameter is not exposed".

7. **Verification per harness** (a configuration line is not proof; a completed turn is):
   - `raindrop-mcp --check` exits 0 and reports six tools without `search`.
   - OpenCode: `opencode mcp list` shows `connected`, then one `find_collections` call through the agent.
   - Claude Code: `claude mcp get raindrop` shows connected, then one read.
   - Codex: `codex mcp get raindrop` shows a stdio command, then one non-interactive turn that lists collections.
   - Antigravity: `agy mcp list` shows the server; a turn is deferred until the quota resets.

8. **Rollback, one line per harness:**
   - OpenCode and Claude: point the entry back at the URL with the header.
   - Codex: restore the `npx -y mcp-remote ...` entry, which is the only harness where the URL does not work natively.
   - Keep the old entries in the commit history; do not leave commented duplicates behind.

## Acceptance

- All four configurations start the same command, with no token in any of them except the two 600-mode files that remain local and untracked.
- `raindrop-mcp --check` passes on this machine and after `install.sh` on the Mac.
- Three harnesses verified by a completed turn; Antigravity recorded as pending.
