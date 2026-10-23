# MCP Setup

After running `install.sh`, configure the servers in the harnesses you use. The script points to this guide; MCP setup remains manual.

## Configuration

Use the repository files below as the reference for endpoints and commands.

| Harness | Setup |
| --- | --- |
| OpenCode | The `mcp.servers` section is in [opencode.jsonc](../.config/opencode/opencode.jsonc). Linux uses the same entry in `~/.config/opencode/opencode.json`. |
| Claude Code | Add the servers with `claude mcp add --scope user`. Check `claude mcp add --help` for the current syntax. |
| Codex | Configure native Streamable HTTP servers in `~/.codex/config.toml`. Check `codex mcp add --help`. |
| Antigravity ACP | Use the [template](../.gemini/config/mcp_config.json.example) for `~/.gemini/config/mcp_config.json`, replacing placeholders locally. In T3, check the logs to find the configuration file the provider actually reads. |

Merge entries into existing files, preserving other settings. Each harness has its own format. Set permissions `600` on any local configuration that contains a token value.

## Raindrop.io

All four harnesses use the Worker at `https://raindrop-mcp.diegobit.com/mcp`. It exposes six tools:

| Tool | Limit |
| --- | --- |
| `find_bookmarks` | 1–50 results per page, page 0 or later. |
| `find_collections` | No arguments. Includes Unsorted (`-1`) and Trash (`-99`). |
| `fetch_bookmark_content` | Saved page text only, capped at 100,000 characters. |
| `create_bookmarks` | 1–100 items in one request. |
| `update_bookmarks` | 1–25 bookmarks, sequential; stops at the first rate limit. |
| `delete_bookmarks` | 1–25 bookmarks, sequential; moves them to Trash and never deletes permanently. |

`find_bookmarks` takes a keyword `query` with Raindrop's search operators. There is no semantic search, no page-body search, and no permanent deletion. `fetch_bookmark_content` asks Raindrop's official MCP server for the text saved with a bookmark; it never fetches the live page. A bookmark without saved text is an error, not an empty success.

The Worker uses two secrets with different roles:

| Secret | Held by | Purpose |
| --- | --- | --- |
| `RAINDROP_TOKEN` | Worker secret only | Calls to Raindrop REST and the official content server. |
| `MCP_TOKEN` | Worker secret and `~/.raindrop-mcp-token` on each machine | The bearer value clients present to the Worker. |

Keep the client token outside the repository, without the `Bearer` prefix, in `~/.raindrop-mcp-token` with permissions `600`. A leaked harness configuration exposes only the Worker, not the Raindrop account.

OpenCode reads the token through `{file:~/.raindrop-mcp-token}`; the entry is already in the repository configuration. Claude Code and Antigravity store the header in their own configuration; Codex stores it in `~/.codex/config.toml`.

```sh
# Claude Code
claude mcp add --scope user --transport http raindrop https://raindrop-mcp.diegobit.com/mcp \
  --header "Authorization: Bearer $(cat ~/.raindrop-mcp-token)"

# Antigravity
agy mcp add --header "Authorization: Bearer $(cat ~/.raindrop-mcp-token)" raindrop \
  https://raindrop-mcp.diegobit.com/mcp
```

Codex supports this server natively, so no `mcp-remote` bridge is needed. Add this to `~/.codex/config.toml`:

```toml
[mcp_servers.raindrop]
url = "https://raindrop-mcp.diegobit.com/mcp"
http_headers = { Authorization = "Bearer <token>" }
```

Deployment, secret upload, and the production verification sequence are in `~/code/raindrop-mcp/DEPLOY.md`.

## Tokens

Store token values outside the repository, without the `Bearer` prefix, in files with permissions `600`:

- Rivolo: `~/.rivolo-token`; Codex environment variable: `RIVOLO_TOKEN`.
- iCloud Mail: `~/.icloud-mail-token`; environment variable: `ICLOUD_MAIL_TOKEN`.
- Raindrop Worker client: `~/.raindrop-mcp-token`; this is the only Raindrop client secret on each machine.
- Raindrop account: `~/.raindrop-token`; rollback only, kept until every harness has completed a real search and content call.

Your shell can export these variables by reading the files. The process that starts the harness must inherit them. Tracked files, including `config.fish`, should contain only references to secrets. Set permissions `600` on local configurations containing tokens too; keep token values out of logs and agent replies.

## Verification

Open a new session, check that it exposes the server's tools, and invoke a read-only tool. A configuration entry or a direct HTTP test does not prove that the tools are available in the harness.

After rotating `~/.raindrop-mcp-token`, reload or restart each harness so it reconnects with the new value. OpenCode's background service keeps the old header until `opencode reload`; a read-only turn then confirms the change.

- OpenCode: `opencode mcp list` shows `connected`; one turn calls `find_bookmarks` with a `query`, then `fetch_bookmark_content` on a returned id.
- Claude Code: `claude mcp get raindrop` shows the Worker URL; one turn makes the same two calls.
- Codex: `codex mcp get raindrop` shows `streamable_http`; one non-interactive turn makes the same two calls.
- Antigravity: `agy mcp list` shows the entry. Its first verification turn is pending until the CLI quota resets.

In each harness, confirm the six tool names are present and `delete_collections` and `delete_tags` are absent.

To roll back, point each harness at `https://api.raindrop.io/rest/v2/ai/mcp` with `~/.raindrop-token`, and restore `npx mcp-remote` for Codex only. The Worker can stay deployed; it stores no bookmark data.
