# MCP Setup

The private [diegobit/fleet](https://github.com/diegobit/fleet) repo manages the MCP servers of
every agent harness on every host. `install.sh` runs its `bin/apply.sh`, which writes the servers
listed in `agents/mcp.json` into Claude Code, Codex, OpenCode, Cursor and Antigravity. Add, rename
or remove a server there, not in a harness's own configuration.

On the Mac, that includes the `mcp` section of [opencode.jsonc](../.config/opencode/opencode.jsonc):
fleet rewrites it, so edit only the other settings in this file.

## Tokens

Each remote server needs its client token in a file outside any repository, without the `Bearer`
prefix, with permissions `600`. A host without the file does not get the server.

- Rivolo: `~/.rivolo-token`
- iCloud Mail: `~/.icloud-mail-token`
- Raindrop Worker client: `~/.raindrop-mcp-token`
- Raindrop account: `~/.raindrop-token`; rollback only, see below.

After adding or rotating a token, rerun `~/code/dg/fleet/bin/apply.sh` and restart the harnesses.
OpenCode reads the files through `{file:...}`; the other harnesses get the value written into
their configuration. Keep token values out of logs and agent replies.

## Raindrop.io

The `raindrop` server is the Worker at `https://raindrop-mcp.diegobit.com/mcp`. It exposes six tools:

| Tool | Limit |
| --- | --- |
| `find_bookmarks` | 1–50 results per page, page 0 or later. |
| `find_collections` | No arguments. Includes Unsorted (`-1`) and Trash (`-99`). |
| `fetch_bookmark_content` | Saved page text only, capped at 50,000 characters. |
| `create_bookmarks` | 1–100 items in one request. |
| `update_bookmarks` | 1–10 bookmarks, sequential; stops at the first rate limit. |
| `delete_bookmarks` | 1–10 bookmarks, sequential; moves them to Trash and never deletes permanently. |

`find_bookmarks` takes a keyword `query` with Raindrop's search operators. There is no semantic search, no page-body search, and no permanent deletion. `fetch_bookmark_content` asks Raindrop's official MCP server for the text saved with a bookmark; it never fetches the live page. A bookmark without saved text is an error, not an empty success.

The Worker uses two secrets with different roles:

| Secret | Held by | Purpose |
| --- | --- | --- |
| `RAINDROP_TOKEN` | Worker secret only | Calls to Raindrop REST and the official content server. |
| `MCP_TOKEN` | Worker secret and `~/.raindrop-mcp-token` on each machine | The bearer value clients present to the Worker. |

Keep the client token outside the repository, without the `Bearer` prefix, in `~/.raindrop-mcp-token` with permissions `600`. A leaked harness configuration exposes only the Worker, not the Raindrop account.

Deployment, secret upload, and the production verification sequence are in `~/code/raindrop-mcp/DEPLOY.md`.

## Verification

Open a new session, check that it exposes the server's tools, and invoke a read-only tool. A configuration entry or a direct HTTP test does not prove that the tools are available in the harness.

After rotating `~/.raindrop-mcp-token`, reload or restart each harness so it reconnects with the new value. OpenCode's background service keeps the old header until `opencode reload`; a read-only turn then confirms the change.

- Claude Code: `claude mcp list` shows each server `Connected`.
- Cursor: `cursor-agent mcp list` shows each server `ready`.
- OpenCode: `opencode run --standalone --print-logs "ok"` logs `mcp connected` for each server.
- Codex: `codex mcp list`; Antigravity: `agy mcp list`. These only show the entries, so run one turn.

In each harness, confirm the six tool names are present and `delete_collections` and `delete_tags` are absent.

To roll back Raindrop, point the `raindrop` entry in fleet's `agents/mcp.json` at `https://api.raindrop.io/rest/v2/ai/mcp` with `~/.raindrop-token`. The Worker can stay deployed; it stores no bookmark data.
