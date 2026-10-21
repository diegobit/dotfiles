# MCP Setup

After running `install.sh`, configure the servers in the harnesses you use. The script points to this guide; MCP setup remains manual.

## Configuration

Use the repository files below as the reference for endpoints and commands.

| Harness | Setup |
| --- | --- |
| OpenCode | The `mcp` section is already in [opencode.jsonc](../.config/opencode/opencode.jsonc), symlinked to `~/.config/opencode/opencode.jsonc`. |
| Claude Code | Add the same servers with `claude mcp add --scope user`. Check `claude mcp add --help` for the current syntax. |
| Codex | Configure the same servers in `~/.codex/config.toml`, using environment variables for tokens. Check `codex mcp add --help`. |
| Antigravity ACP | Use the [template](../.gemini/config/mcp_config.json.example) for `~/.gemini/config/mcp_config.json`, replacing placeholders locally. In T3, check the logs to find the configuration file the provider actually reads. |

Merge entries into existing files, preserving other settings. Each harness has its own format; adapt the OpenCode configuration for each one.

## Raindrop.io

All four harnesses use the official remote server, `https://api.raindrop.io/rest/v2/ai/mcp`, authenticated with the personal API token in the `Authorization` header. OpenCode reads the token through `{file:~/.raindrop-token}`; Codex and Antigravity carry the header value in their own configuration; Claude Code stores it in `~/.claude.json`.

The server exposes 21 tools. `delete_bookmarks` stays available, while `raindrop_delete_collections` and `raindrop_delete_tags` are denied in OpenCode and `mcp__raindrop__delete_collections` and `mcp__raindrop__delete_tags` in Claude Code. Codex and Antigravity have no equivalent switch, so the global `AGENTS.md` tells agents not to call them.

On the free plan the server answers filtered reads but rejects semantic search with "Semantic search is only available to Pro users". The REST API's `search` parameter still works for keyword search.

The official skills ship separately: `claude plugin install raindrop@claude-plugins-official`, `codex plugin add raindrop@openai-curated`, `gemini extensions install https://github.com/raindropio/skills`.

Copy the token once into `~/.raindrop-token` on each machine, then:

```sh
# OpenCode needs nothing: the symlinked configuration already lists the server.

# Claude Code
claude mcp add --scope user --transport http raindrop https://api.raindrop.io/rest/v2/ai/mcp \
  --header "Authorization: Bearer $(cat ~/.raindrop-token)"

# Antigravity
agy mcp add --header "Authorization: Bearer $(cat ~/.raindrop-token)" raindrop \
  https://api.raindrop.io/rest/v2/ai/mcp
```

Codex has no header flag, and its native HTTP client rejects this server's reply to the `initialized` notification ("Unexpected content type ... when send initialized notification"). It runs `mcp-remote` as a stdio bridge instead, so append this to `~/.codex/config.toml`. The header comes from the file rather than an environment variable because T3 Code starts Codex outside the shell, where exported variables are missing.

```toml
[mcp_servers.raindrop]
command = "npx"
args = ["-y", "mcp-remote", "https://api.raindrop.io/rest/v2/ai/mcp", "--header", "Authorization: Bearer <token>", "--transport", "http-only"]
```

## Tokens

Store token values outside the repository, without the `Bearer` prefix, in files with permissions `600`:

- Rivolo: `~/.rivolo-token`; Codex environment variable: `RIVOLO_TOKEN`.
- iCloud Mail: `~/.icloud-mail-token`; environment variable: `ICLOUD_MAIL_TOKEN`.
- Raindrop: `~/.raindrop-token`; environment variable: `RAINDROP_TOKEN`.

Your shell can export these variables by reading the files. The process that starts the harness must inherit them. Tracked files, including `config.fish`, should contain only references to secrets. Set permissions `600` on local configurations containing tokens too; keep token values out of logs and agent replies.

## Verification

Open a new session, check that it exposes the server's tools, and invoke a read-only tool. A configuration entry or a direct HTTP test does not prove that the tools are available in the harness.
