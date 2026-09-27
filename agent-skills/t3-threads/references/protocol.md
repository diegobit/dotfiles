# T3 local server protocol (verified against v0.0.42 alpha, macOS desktop app)

The CLI in `scripts/t3-threads.mjs` uses the endpoints below. Server origin:
`http://127.0.0.1:3773` for the desktop app; `npx t3@latest` serves the same API
on its own port.

Liveness probe (no auth): `GET /.well-known/t3/environment` →
`{environmentId, label, serverVersion, capabilities}`.

## Auth

```bash
npx -y t3@latest auth session issue --token-only --label t3-threads --ttl 30d
npx -y t3@latest auth session list --json
npx -y t3@latest auth session revoke <sessionId>
```

- HTTP requests: `Authorization: Bearer <token>`.
- WebSocket: the documented `?token=` query parameter is stale in this build. Mint a
  short-lived ticket first, then connect:
  - `POST /api/auth/websocket-ticket` (Bearer) → `{ticket, expiresAt}`
  - `ws://<origin>/ws?wsTicket=<ticket>`

## HTTP API used by the CLI

- `GET /api/orchestration/shell` → `{snapshotSequence, projects, threads, updatedAt}`.
  Thread shells carry `hasPendingApprovals`, `hasPendingUserInput`,
  `hasActionableProposedPlan`, `latestTurn.state`, `session.status` — enough to derive
  a single attention state.
- `GET /api/orchestration/threads/:threadId?turnLimit=N` →
  `{snapshotSequence, thread: {messages, activities, latestTurn, session, ...}}`.
- `POST /api/orchestration/dispatch` also accepts commands, but the skill prefers the
  documented WebSocket RPC for writes.

## WebSocket RPC (Effect RPC, plain JSON serialization)

Client → server:

```json
{"_tag":"Request","id":"<uuid>","tag":"orchestration.dispatchCommand","payload":<command>,"headers":[]}
```

Server → client:

```json
{"_tag":"Exit","requestId":"<id>","exit":{"_tag":"Success","value":{"sequence":42}}}
{"_tag":"Exit","requestId":"<id>","exit":{"_tag":"Failure","cause":[{"_tag":"Fail","error":{"_tag":"OrchestrationDispatchCommandError","message":"..."}}]}}
```

Streaming tags (`subscribeShell`, `subscribeThread`) send `{"_tag":"Chunk", ...}` items
before the final `Exit`.

Method tags present in v0.0.42: `orchestration.dispatchCommand`, `getWorkflowScript`,
`getTurnDiff`, `getFullThreadDiff`, `searchThreads`, `getArchivedShellSnapshot`,
`subscribeShell`, `subscribeThread`. The public docs still describe
`orchestration.getSnapshot`, which this build no longer serves.

## thread.turn.start command

```json
{
  "type": "thread.turn.start",
  "commandId": "<uuid>",
  "threadId": "<uuid>",
  "message": {"messageId": "<uuid>", "role": "user", "text": "...", "attachments": []},
  "runtimeMode": "approval-required | auto-accept-edits | auto | full-access",
  "interactionMode": "default | plan",
  "createdAt": "<iso>"
}
```

`thread.create` additionally requires `title`, `projectId`, `modelSelection`
(`{instanceId, model}`) and accepts nullable `branch`/`worktreePath`.

## Verification and debugging

- Transport/auth probe without touching real threads: dispatch `thread.turn.start` with
  a nonexistent `threadId`; expect
  `Thread '<id>' does not exist for command 'thread.turn.start'.`
- Inspect the shipped server bundle:

  ```bash
  npx -y @electron/asar extract-file \
    "/Applications/T3 Code (Alpha).app/Contents/Resources/app.asar" \
    apps/server/dist/bin.mjs
  ```

  Then search for `ORCHESTRATION_WS_METHODS`, `websocket-ticket`, and
  `/api/orchestration` to re-confirm routes after an upgrade. The app name may drop
  "(Alpha)" in later versions.
