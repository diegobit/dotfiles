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

## Tokens

Store token values outside the repository, without the `Bearer` prefix, in files with permissions `600`:

- Rivolo: `~/.rivolo-token`; Codex environment variable: `RIVOLO_TOKEN`.
- iCloud Mail: `~/.icloud-mail-token`; environment variable: `ICLOUD_MAIL_TOKEN`.

Your shell can export these variables by reading the files. The process that starts the harness must inherit them. Tracked files, including `config.fish`, should contain only references to secrets. Set permissions `600` on local configurations containing tokens too; keep token values out of logs and agent replies.

## Verification

Open a new session, check that it exposes the server's tools, and invoke a read-only tool. A configuration entry or a direct HTTP test does not prove that the tools are available in the harness.
