#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { randomUUID } from "node:crypto";
import os from "node:os";
import path from "node:path";

const DEFAULT_ORIGIN = "http://127.0.0.1:3773";
const LABEL = "t3-threads";
const DEFAULT_TTL = "30d";

const argv = process.argv.slice(2);
const command = argv[0];

const origin = (process.env.T3_ORIGIN ?? DEFAULT_ORIGIN).replace(/\/+$/, "");
const tokenPath =
  process.env.T3_TOKEN_FILE ??
  path.join(process.env.XDG_CONFIG_HOME ?? path.join(os.homedir(), ".config"), LABEL, "token");

function fail(message, code = 1) {
  console.error(message);
  process.exit(code);
}

function usage() {
  console.log(`usage: t3-threads <command> [options]

  list   [--project <id|name>] [--match <text>] [--all] [--json]
  read   <threadId|name> [--turns N] [--json]
  send   <threadId|name> <message> [--wait] [--queue] [--timeout seconds] [--interval ms]
         [--command-id <id>] [--message-id <id>] [--mode <runtimeMode>] [--interaction default|plan] [--json]
  wait   <threadId|name> [--timeout seconds] [--interval ms] [--json]
  token  mint [--ttl 30d] [--label <name>] | show | revoke [--label <name>]
  doctor

A name is a case-insensitive substring of an active thread's title; ambiguous names
list the candidates. A busy thread is refused unless --queue is passed; with --queue
the provider decides whether to steer the message into the running turn or queue it.
Environment: T3_ORIGIN (default ${DEFAULT_ORIGIN}), T3_TOKEN, T3_TOKEN_FILE
Exit codes: 0 ok, 1 error, 2 usage, 3 wait timeout`);
}

class UsageError extends Error {}

function parseArgs(args, valueFlags, boolFlags = new Set(["json"])) {
  const opts = {};
  const pos = [];
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg.startsWith("--")) {
      const eq = arg.indexOf("=");
      const name = eq === -1 ? arg.slice(2) : arg.slice(2, eq);
      if (!valueFlags.has(name) && !boolFlags.has(name)) {
        throw new UsageError(`unknown option --${name}`);
      }
      if (valueFlags.has(name)) {
        const value = eq === -1 ? args[++i] : arg.slice(eq + 1);
        if (value === undefined || value.startsWith("--")) {
          throw new UsageError(`--${name} needs a value`);
        }
        opts[name] = value;
      } else {
        if (eq !== -1) throw new UsageError(`--${name} takes no value`);
        opts[name] = true;
      }
    } else {
      pos.push(arg);
    }
  }
  return [opts, pos];
}

function numberOption(opts, name, fallback, min, { integer = false } = {}) {
  if (opts[name] === undefined) return fallback;
  const value = Number(opts[name]);
  if (!Number.isFinite(value) || value < min || (integer && !Number.isInteger(value))) {
    throw new UsageError(`--${name} must be ${integer ? "an integer" : "a number"} >= ${min}`);
  }
  return value;
}

function readToken() {
  if (process.env.T3_TOKEN) return process.env.T3_TOKEN.trim();
  if (existsSync(tokenPath)) return readFileSync(tokenPath, "utf8").trim();
  fail(`No T3 token. Mint one with: t3-threads token mint`);
}

async function api(pathname, init = {}, { auth = true } = {}) {
  const headers = { ...(init.headers ?? {}) };
  if (auth) headers.authorization = `Bearer ${readToken()}`;
  if (init.body !== undefined) headers["content-type"] = "application/json";
  let res;
  try {
    res = await fetch(origin + pathname, { ...init, headers });
  } catch (error) {
    throw new Error(`Cannot reach the T3 server at ${origin} (${error.message}). Is T3 Code running?`);
  }
  const text = await res.text();
  if (auth && (res.status === 401 || res.status === 403)) {
    throw new Error(`T3 rejected the token (HTTP ${res.status}). Mint a fresh one: t3-threads token mint`);
  }
  if (!res.ok) throw new Error(`T3 API ${pathname} failed: HTTP ${res.status} ${text.slice(0, 400)}`);
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

const shell = () => api("/api/orchestration/shell");

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function resolveThread(reference) {
  const snapshot = await shell();
  const projects = new Map(snapshot.projects.map((project) => [project.id, project]));
  const decorate = (thread) => ({
    id: thread.id,
    title: thread.title ?? "(untitled)",
    project: projects.get(thread.projectId)?.title ?? thread.projectId,
  });
  if (UUID_RE.test(reference)) {
    const thread = snapshot.threads.find((candidate) => candidate.id === reference);
    return thread ? decorate(thread) : { id: reference, title: "(unknown)", project: "(unknown)" };
  }
  const byId = snapshot.threads.find((candidate) => candidate.id === reference);
  if (byId) return decorate(byId);
  const needle = reference.toLowerCase();
  const matches = snapshot.threads.filter(
    (thread) => !thread.archivedAt && (thread.title ?? "").toLowerCase().includes(needle),
  );
  const exact = matches.filter((thread) => (thread.title ?? "").toLowerCase() === needle);
  const pool = exact.length > 0 ? exact : matches;
  if (pool.length === 1) return decorate(pool[0]);
  if (pool.length === 0) {
    throw new Error(`no active thread matching "${reference}" — check: t3-threads list --all`);
  }
  const lines = pool
    .slice(0, 10)
    .map((thread) => `- ${thread.id}\t${thread.title}\t${projects.get(thread.projectId)?.title ?? thread.projectId}`)
    .join("\n");
  throw new Error(
    `ambiguous thread name "${reference}" (${pool.length} matches):\n${lines}\nretry with a full thread id`,
  );
}

const threadDetail = (threadId, turnLimit) =>
  api(
    `/api/orchestration/threads/${encodeURIComponent(threadId)}` +
      (turnLimit ? `?turnLimit=${turnLimit}` : ""),
  );

function exitErrorMessage(exit) {
  const failure = exit?.cause?.find((cause) => cause._tag === "Fail");
  return failure?.error?.message ?? JSON.stringify(exit ?? null);
}

async function dispatch(command) {
  const { ticket } = await api("/api/auth/websocket-ticket", { method: "POST" });
  const wsUrl = origin.replace(/^http/, "ws") + "/ws?wsTicket=" + encodeURIComponent(ticket);
  return await new Promise((resolve, reject) => {
    let ws;
    try {
      ws = new WebSocket(wsUrl);
    } catch (error) {
      reject(new Error(`WebSocket failed: ${error.message}`));
      return;
    }
    const id = randomUUID();
    const timer = setTimeout(() => {
      try {
        ws.close();
      } catch {}
      reject(new Error("Timed out waiting for the T3 server response"));
    }, 20000);
    ws.onopen = () =>
      ws.send(
        JSON.stringify({
          _tag: "Request",
          id,
          tag: "orchestration.dispatchCommand",
          payload: command,
          headers: [],
        }),
      );
    ws.onmessage = (event) => {
      let message;
      try {
        message = JSON.parse(String(event.data));
      } catch {
        return;
      }
      if (message._tag !== "Exit" || message.requestId !== id) return;
      clearTimeout(timer);
      try {
        ws.close();
      } catch {}
      if (message.exit?._tag === "Success") resolve(message.exit.value);
      else reject(new Error(exitErrorMessage(message.exit)));
    };
    ws.onerror = (event) => {
      clearTimeout(timer);
      reject(new Error(`WebSocket error: ${event?.message ?? "connection failed"}`));
    };
  });
}

function attentionOf(thread) {
  if (thread.hasPendingApprovals) return "needs-approval";
  if (thread.hasPendingUserInput) return "needs-input";
  if (thread.session?.status === "error" || thread.latestTurn?.state === "error") return "error";
  if (thread.hasActionableProposedPlan) return "plan-ready";
  if (thread.latestTurn?.state === "running" || thread.session?.status === "running") return "working";
  if (thread.latestTurn?.state === "completed" || thread.latestTurn?.state === "interrupted")
    return "done";
  return "idle";
}

function isStaleRequestFailureDetail(payload) {
  const detail = typeof payload?.detail === "string" ? payload.detail.toLowerCase() : null;
  if (detail === null) return false;
  return (
    detail.includes("stale pending approval request") ||
    detail.includes("unknown pending approval request") ||
    detail.includes("unknown pending permission request") ||
    detail.includes("stale pending user-input request") ||
    detail.includes("unknown pending user-input request") ||
    detail.includes("unknown pending user input request") ||
    detail.includes("unknown pending codex user input request")
  );
}

function pendingRequests(activities = []) {
  const open = new Map();
  for (const activity of activities) {
    const payload = activity.payload ?? {};
    const requestId = typeof payload.requestId === "string" ? payload.requestId : undefined;
    if (!requestId) continue;
    if (activity.kind === "approval.requested" || activity.kind === "user-input.requested") {
      open.set(requestId, {
        requestId,
        kind: activity.kind === "approval.requested" ? "approval" : "user-input",
        requestKind: typeof payload.requestKind === "string" ? payload.requestKind : undefined,
        summary: activity.summary ?? null,
      });
    } else if (activity.kind === "approval.resolved" || activity.kind === "user-input.resolved") {
      open.delete(requestId);
    } else if (
      (activity.kind === "provider.approval.respond.failed" ||
        activity.kind === "provider.user-input.respond.failed") &&
      isStaleRequestFailureDetail(payload)
    ) {
      open.delete(requestId);
    }
  }
  return [...open.values()];
}

function truncate(text, limit = 1500) {
  if (!text) return "";
  return text.length <= limit ? text : `${text.slice(0, limit)}… [${text.length - limit} chars truncated]`;
}

function decodeToken(token) {
  try {
    const parts = token.split(".");
    const payload = parts.length >= 3 ? parts[1] : parts[0];
    return JSON.parse(
      Buffer.from(payload.replaceAll("-", "+").replaceAll("_", "/"), "base64").toString("utf8"),
    );
  } catch {
    return {};
  }
}

function formatExpiry(epoch) {
  if (!epoch) return "unknown";
  return new Date(epoch > 1e12 ? epoch : epoch * 1000).toISOString();
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function cmdList(args) {
  const [opts] = parseArgs(args, new Set(["project", "match"]), new Set(["all", "json"]));
  const snapshot = await shell();
  const projects = new Map(snapshot.projects.map((project) => [project.id, project]));
  let threads = snapshot.threads;
  if (!opts.all) threads = threads.filter((thread) => !thread.archivedAt);
  if (opts.project) {
    const needle = String(opts.project).toLowerCase();
    threads = threads.filter(
      (thread) =>
        thread.projectId === opts.project ||
        (projects.get(thread.projectId)?.title ?? "").toLowerCase().includes(needle),
    );
  }
  if (opts.match) {
    const needle = String(opts.match).toLowerCase();
    threads = threads.filter((thread) => (thread.title ?? "").toLowerCase().includes(needle));
  }
  threads = [...threads].sort((a, b) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt));
  if (opts.json) {
    console.log(
      JSON.stringify(
        threads.map((thread) => ({
          id: thread.id,
          title: thread.title,
          project: projects.get(thread.projectId)?.title ?? thread.projectId,
          attention: attentionOf(thread),
          updatedAt: thread.updatedAt,
          model: thread.modelSelection
            ? `${thread.modelSelection.instanceId}/${thread.modelSelection.model}`
            : null,
        })),
        null,
        2,
      ),
    );
    return;
  }
  for (const thread of threads) {
    console.log(
      [
        thread.id,
        attentionOf(thread),
        projects.get(thread.projectId)?.title ?? thread.projectId,
        thread.title ?? "(untitled)",
      ].join("\t"),
    );
  }
}

async function cmdRead(args) {
  const [opts, pos] = parseArgs(args, new Set(["turns"]));
  if (!pos[0]) throw new UsageError("usage: t3-threads read <threadId|name> [--turns N] [--json]");
  const turns = numberOption(opts, "turns", 6, 1, { integer: true });
  const target = await resolveThread(pos[0]);
  const { thread } = await threadDetail(target.id, turns);
  const pending = pendingRequests(thread.activities);
  const reply = {
    id: thread.id,
    title: thread.title,
    projectId: thread.projectId,
    attention: attentionOf(thread),
    latestTurn: thread.latestTurn
      ? { state: thread.latestTurn.state, completedAt: thread.latestTurn.completedAt }
      : null,
    sessionStatus: thread.session?.status ?? null,
    pendingRequests: pending,
    messages: (thread.messages ?? []).map((message) => ({
      id: message.id,
      role: message.role,
      turnId: message.turnId ?? null,
      createdAt: message.createdAt,
      streaming: message.streaming ?? false,
      text: truncate(message.text),
    })),
  };
  if (opts.json) {
    console.log(JSON.stringify(reply, null, 2));
    return;
  }
  console.log(`thread ${thread.id} — ${thread.title ?? "(untitled)"}`);
  console.log(`state: ${reply.attention}${reply.latestTurn ? ` (turn ${reply.latestTurn.state})` : ""}, session ${reply.sessionStatus ?? "none"}`);
  for (const request of pending) console.log(`pending ${request.kind}: ${request.requestId} ${request.summary ?? ""}`);
  for (const message of reply.messages) console.log(`\n[${message.role} ${message.createdAt}]${message.streaming ? " (streaming)" : ""}\n${message.text}`);
}

async function waitForThread(threadId, opts, anchor = null) {
  const timeout = Number(opts.timeout ?? 300);
  const interval = Number(opts.interval ?? 1500);
  const deadline = Date.now() + timeout * 1000;
  const sent = anchor !== null;
  for (;;) {
    const { thread } = await threadDetail(threadId, 5);
    const pending = pendingRequests(thread.activities);
    const turn = thread.latestTurn ?? null;
    const messages = thread.messages ?? [];
    let assistant = null;
    let failed = false;
    let completed = false;
    if (!sent) {
      const lastUser = [...messages].reverse().find((message) => message.role === "user");
      const candidate = [...messages].reverse().find((message) => message.role === "assistant" && !message.streaming);
      assistant =
        candidate && (!lastUser || Date.parse(candidate.createdAt) >= Date.parse(lastUser.createdAt))
          ? candidate
          : null;
      failed = turn?.state === "error" || turn?.state === "interrupted";
      completed = !failed && turn?.state === "completed" && assistant !== null;
    } else {
      const anchorIndex = messages.findIndex((message) => message.id === anchor.messageId);
      if (anchorIndex >= 0) {
        const anchorTime = Date.parse(messages[anchorIndex].createdAt);
        const fresh = (message) => Date.parse(message.updatedAt ?? message.createdAt) > anchorTime;
        const turnStart = turn ? Date.parse(turn.requestedAt ?? turn.startedAt ?? "") : NaN;
        const turnAfterAnchor =
          turn !== null &&
          turn.turnId !== anchor.priorTurnId &&
          Number.isFinite(turnStart) &&
          turnStart >= anchorTime;
        const laterUser = messages.some(
          (message, index) => index > anchorIndex && message.role === "user",
        );
        if (turnAfterAnchor && (turn.state === "error" || turn.state === "interrupted") && !laterUser) {
          failed = true;
        } else if (turnAfterAnchor && turn.state === "completed") {
          if (turn.assistantMessageId) {
            const replyIndex = messages.findIndex((message) => message.id === turn.assistantMessageId);
            const referenced = replyIndex > anchorIndex ? messages[replyIndex] : null;
            const interveningUser = messages.some(
              (message, index) => index > anchorIndex && index < replyIndex && message.role === "user",
            );
            if (referenced && !referenced.streaming && fresh(referenced) && !interveningUser) {
              assistant = referenced;
            }
          } else {
            const replyIndex = messages.findIndex(
              (message, index) =>
                index > anchorIndex && message.role === "assistant" && !message.streaming && fresh(message),
            );
            if (replyIndex > anchorIndex) {
              const interveningUser = messages.some(
                (message, index) => index > anchorIndex && index < replyIndex && message.role === "user",
              );
              if (!interveningUser) assistant = messages[replyIndex];
            } else if (messages.some((message, index) => index > anchorIndex && message.role === "assistant")) {
              // an assistant message follows the anchor but is not eligible yet
            } else if (!laterUser) {
              completed = true;
            }
          }
          if (assistant !== null) completed = true;
        }
      }
    }
    const running = !sent
      ? turn?.state === "running" ||
        thread.session?.status === "running" ||
        thread.session?.status === "starting"
      : false;
    if (pending.length > 0) {
      return { outcome: "needs-you", threadId, sent, pendingRequests: pending };
    }
    const settled = sent ? failed || completed : !running && (failed || completed);
    if (settled) {
      return {
        outcome: failed ? turn.state : "completed",
        threadId,
        sent,
        sessionStatus: thread.session?.status ?? "none",
        lastError: thread.session?.lastError ?? null,
        reply: assistant ? truncate(assistant.text, 6000) : null,
        replyMessageId: assistant?.id ?? null,
      };
    }
    if (Date.now() > deadline) {
      return {
        outcome: "timeout",
        threadId,
        sent,
        turnState: turn?.state ?? null,
        sessionStatus: thread.session?.status ?? "none",
      };
    }
    await sleep(interval);
  }
}

function printWait(result, asJson) {
  if (result.outcome === "timeout") process.exitCode = 3;
  else if (result.outcome !== "completed" && result.outcome !== "needs-you") process.exitCode = 1;
  if (asJson) {
    console.log(JSON.stringify(result, null, 2));
  } else if (result.outcome === "completed") {
    console.log(result.reply ?? "(turn completed with no assistant message)");
  } else if (result.outcome === "needs-you") {
    console.log(`thread needs input (${result.pendingRequests.length} pending):`);
    for (const request of result.pendingRequests)
      console.log(`- ${request.kind} ${request.requestId}${request.summary ? `: ${request.summary}` : ""}`);
  } else if (result.outcome === "timeout") {
    console.log(
      `${result.sent ? "message delivered; " : ""}timeout: ` +
        `${result.turnState === "completed" ? "reply pending" : "still working"} ` +
        `(turn ${result.turnState ?? "unknown"}, session ${result.sessionStatus})`,
    );
  } else {
    console.log(`turn ended: ${result.outcome}${result.lastError ? ` — ${JSON.stringify(result.lastError).slice(0, 300)}` : ""}`);
  }
}

async function cmdWait(args) {
  const [opts, pos] = parseArgs(args, new Set(["timeout", "interval"]));
  if (!pos[0]) throw new UsageError("usage: t3-threads wait <threadId|name> [--timeout seconds] [--json]");
  opts.timeout = numberOption(opts, "timeout", 300, 1);
  opts.interval = numberOption(opts, "interval", 1500, 250);
  const target = await resolveThread(pos[0]);
  printWait(await waitForThread(target.id, opts), opts.json);
}

const RUNTIME_MODES = new Set(["approval-required", "auto-accept-edits", "auto", "full-access"]);

async function cmdSend(args) {
  const [opts, pos] = parseArgs(
    args,
    new Set(["timeout", "interval", "command-id", "message-id", "mode", "interaction"]),
    new Set(["wait", "queue", "json"]),
  );
  const reference = pos.shift();
  const text = pos.join(" ").trim();
  if (!reference || !text) {
    throw new UsageError("usage: t3-threads send <threadId|name> <message> [--wait] [--queue] [--json]");
  }
  if (opts.mode !== undefined && !RUNTIME_MODES.has(opts.mode)) {
    throw new UsageError(`--mode must be one of: ${[...RUNTIME_MODES].join(", ")}`);
  }
  if (opts.interaction !== undefined && !["default", "plan"].includes(opts.interaction)) {
    throw new UsageError("--interaction must be default or plan");
  }
  opts.timeout = numberOption(opts, "timeout", 300, 1);
  opts.interval = numberOption(opts, "interval", 1500, 250);
  const target = await resolveThread(reference);
  let thread;
  try {
    thread = (await threadDetail(target.id, 5)).thread;
  } catch (error) {
    throw new Error(
      `cannot inspect thread "${target.title}" (${target.id}) before sending: ${error.message}`,
    );
  }
  const pending = pendingRequests(thread.activities ?? []);
  const running =
    thread.latestTurn?.state === "running" ||
    thread.session?.status === "running" ||
    thread.session?.status === "starting";
  const busy = running || pending.length > 0;
  if (busy && !opts.queue) {
    const reason = running ? "is running a turn" : "is waiting on input";
    throw new Error(
      `thread "${target.title}" (${target.project}) ${reason}` +
        `${pending.length > 0 ? ` — ${pending.length} pending request(s)` : ""}; ` +
        `pass --queue to send anyway (the provider may steer it into the running turn or queue it), ` +
        `or wait for the thread to settle`,
    );
  }
  const priorTurnId = thread.latestTurn?.turnId ?? null;
  const command = {
    type: "thread.turn.start",
    commandId: opts["command-id"] ?? randomUUID(),
    threadId: target.id,
    message: { messageId: opts["message-id"] ?? randomUUID(), role: "user", text, attachments: [] },
    runtimeMode: opts.mode ?? thread.runtimeMode ?? "approval-required",
    interactionMode: opts.interaction ?? thread.interactionMode ?? "default",
    createdAt: new Date().toISOString(),
  };
  let result;
  try {
    result = await dispatch(command);
  } catch (error) {
    throw new Error(
      `${error.message}\nuncertain send: thread ${target.id}, commandId ${command.commandId}, ` +
        `messageId ${command.message.messageId} — inspect with \`t3-threads read ${target.id}\` before retrying`,
    );
  }
  const summary = {
    sent: true,
    threadId: target.id,
    title: target.title,
    project: target.project,
    busy,
    sequence: result.sequence,
    commandId: command.commandId,
    messageId: command.message.messageId,
  };
  if (opts.json) {
    console.log(JSON.stringify(summary, null, 2));
  } else {
    console.log(
      `sent to "${target.title}" (${target.project}, thread ${target.id})` +
        `${busy ? " — busy thread: the provider may steer it into the running turn or queue it" : ""}` +
        ` (sequence ${result.sequence}, commandId ${command.commandId}, messageId ${command.message.messageId})`,
    );
  }
  if (opts.wait) {
    printWait(
      await waitForThread(target.id, opts, {
        messageId: command.message.messageId,
        priorTurnId,
      }),
      opts.json,
    );
  }
}

function cmdToken(args) {
  const [opts, pos] = parseArgs(args, new Set(["ttl", "label"]), new Set());
  const sub = pos[0] ?? "show";
  const label = opts.label ?? LABEL;
  if (sub === "mint") {
    const ttl = opts.ttl ?? DEFAULT_TTL;
    const res = spawnSync(
      "npx",
      ["-y", "t3@latest", "auth", "session", "issue", "--token-only", "--label", label, "--ttl", String(ttl)],
      { encoding: "utf8" },
    );
    if (res.status !== 0) fail(`t3 auth session issue failed: ${(res.stderr || res.stdout || "").trim()}`);
    const token = res.stdout.trim();
    if (!token) fail("t3 auth session issue returned an empty token");
    mkdirSync(path.dirname(tokenPath), { recursive: true, mode: 0o700 });
    writeFileSync(tokenPath, token, { mode: 0o600 });
    chmodSync(tokenPath, 0o600);
    const info = decodeToken(token);
    const expires = info.exp ? formatExpiry(info.exp) : "unknown";
    console.log(`stored ${label} token at ${tokenPath} (expires ${expires})`);
    return;
  }
  if (sub === "show") {
    const token = readToken();
    const info = decodeToken(token);
    const source = process.env.T3_TOKEN ? "T3_TOKEN environment" : tokenPath;
    console.log(`source: ${source}`);
    console.log(`session: ${info.sid ?? "?"} subject: ${info.sub ?? "?"}`);
    console.log(`expires: ${info.exp ? formatExpiry(info.exp) : "unknown"}`);
    return;
  }
  if (sub === "revoke") {
    const res = spawnSync("npx", ["-y", "t3@latest", "auth", "session", "list", "--json"], {
      encoding: "utf8",
    });
    if (res.status !== 0) fail(`t3 auth session list failed: ${(res.stderr || res.stdout || "").trim()}`);
    let sessions;
    try {
      sessions = JSON.parse(res.stdout);
    } catch {
      fail(`Could not parse auth session list output: ${res.stdout.slice(0, 300)}`);
    }
    const matches = (Array.isArray(sessions) ? sessions : sessions.sessions ?? []).filter(
      (session) => session.client?.label === label,
    );
    if (matches.length === 0) {
      console.log(`no sessions labeled ${label}`);
    }
    const revokedIds = new Set();
    for (const session of matches) {
      const revoke = spawnSync("npx", ["-y", "t3@latest", "auth", "session", "revoke", session.sessionId], {
        encoding: "utf8",
      });
      if (revoke.status !== 0) fail(`revoke ${session.sessionId} failed: ${(revoke.stderr || revoke.stdout || "").trim()}`);
      revokedIds.add(session.sessionId);
      console.log(`revoked ${session.sessionId}`);
    }
    if (existsSync(tokenPath) && revokedIds.has(decodeToken(readFileSync(tokenPath, "utf8").trim()).sid)) {
      rmSync(tokenPath);
      console.log(`removed ${tokenPath}`);
    }
    return;
  }
  fail("usage: t3-threads token mint|show|revoke [--ttl 30d]", 2);
}

async function cmdDoctor(args) {
  parseArgs(args, new Set(), new Set());
  let environment;
  try {
    environment = await api("/.well-known/t3/environment", {}, { auth: false });
  } catch {
    fail(`No T3 server at ${origin}. Start the desktop app or \`npx t3@latest\`.`);
  }
  console.log(`server: ${environment.serverVersion} (${environment.label}) at ${origin}`);
  const snapshot = await shell();
  const token = decodeToken(readToken());
  console.log(`token: ${token.sid ?? "?"}, expires ${token.exp ? formatExpiry(token.exp) : "unknown"}`);
  console.log(`projects: ${snapshot.projects.length}, threads: ${snapshot.threads.length}`);
  try {
    await dispatch({
      type: "thread.turn.start",
      commandId: randomUUID(),
      threadId: "00000000-0000-0000-0000-000000000000",
      message: { messageId: randomUUID(), role: "user", text: "t3-threads doctor probe", attachments: [] },
      runtimeMode: "approval-required",
      interactionMode: "default",
      createdAt: new Date().toISOString(),
    });
    console.log("websocket: probe unexpectedly succeeded; report this");
    process.exitCode = 1;
  } catch (error) {
    if (String(error.message).includes("does not exist")) {
      console.log("websocket: ok (ticket + dispatch verified)");
    } else {
      console.log(`websocket: check failed — ${error.message}`);
      process.exitCode = 1;
    }
  }
}

if (!command || command === "help" || command === "--help" || command === "-h") {
  usage();
  process.exit(command ? 0 : 2);
}

const commands = {
  list: cmdList,
  read: cmdRead,
  send: cmdSend,
  wait: cmdWait,
  token: async (args) => cmdToken(args),
  doctor: cmdDoctor,
};

const handler = commands[command];
if (!handler) fail(`unknown command: ${command}\n\n` + usage(), 2);
try {
  await handler(argv.slice(1));
} catch (error) {
  fail(error?.message ?? String(error), error instanceof UsageError ? 2 : 1);
}
