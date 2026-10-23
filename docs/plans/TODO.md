# Plans

- [x] `done` **Flash worker report handling** — [plan](20260905-flash-report-01-output.md)

## External worker consolidation

[Design and shared contract](completed/20260905-external-worker-00-design.md)

- [x] `done` **01 Shared launcher and contract tests** — [plan](completed/20260905-external-worker-01-launcher.md); depends on: none.
- [x] `done` **02 Unified skill and discovery migration** — [plan](completed/20260905-external-worker-02-migration.md); depends on: 01.

## Global visual description and summarization (`docdescribe`)

[Design and shared contract](20260913-docdescribe-00-design.md)

- [x] `done` **01 Core CLI and engine** — [plan](20260913-docdescribe-01-cli.md) — blocked by: none
- [x] `done` **02 Skill integration and FCRF adapter** — [plan](20260913-docdescribe-02-integration.md) — blocked by: 01

## Harness history lookup and resume

[Design and shared contract](20260916-harness-history-00-design.md)

- [x] `done` **01 Safe lookup and exact title** — [plan](20260916-harness-history-01-lookup.md) — blocked by: none
- [x] `done` **02 last and resume recipe** — [plan](20260916-harness-history-02-last.md) — blocked by: 01

## Raindrop MCP Worker

Repository: [diegobit/raindrop-mcp](https://github.com/diegobit/raindrop-mcp)

[Design and shared contract](https://github.com/diegobit/raindrop-mcp/blob/main/plans/20261021-raindrop-mcp-proxy-00-design.md)

- [x] `done` **01 The Worker and its tests** — [plan](https://github.com/diegobit/raindrop-mcp/blob/main/plans/20261021-raindrop-mcp-proxy-01-proxy.md) — blocked by: none
- [ ] `wip` **02 Deployment and harness wiring** — [plan](https://github.com/diegobit/raindrop-mcp/blob/main/plans/20261021-raindrop-mcp-proxy-02-integration.md) — blocked by: 01; deployed; OpenCode, Claude Code, and Codex verified on both machines; Antigravity pending quota; CPU samples measured (25-item update 20 ms, 25-item delete 16 ms, 100,000-char content 12 ms) on a `standard`/Paid deployment, so the Free 10 ms target is not met and the plan/caps decision is open

