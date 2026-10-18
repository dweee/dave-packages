import assert from "node:assert/strict";
import { spawn, execFileSync } from "node:child_process";
import { createRequire } from "node:module";
import { createInterface } from "node:readline";
import { join } from "node:path";

const out = process.argv[2];
const root = join(out, "lib/rea-agents");
const env = { ...process.env, PATH: "/no-ambient-tools" };
for (const command of ["bin/rea", "bin/rea-agents", "lib/rea-agents/scripts/rea.mjs"]) {
  assert.equal(execFileSync(join(out, command), ["--version"], { env, encoding: "utf8" }).trim(), "6.7.0");
}

// Exercise the installed stdio boundary, including the dispatcher's own PATH.
const child = spawn(join(out, "bin/rea"), ["mcp"], { env, stdio: ["pipe", "pipe", "pipe"] });
let stderr = "";
child.stderr.on("data", (chunk) => { stderr += chunk; });
const pending = new Map();
const lines = createInterface({ input: child.stdout });
lines.on("line", (line) => {
  const response = JSON.parse(line);
  const request = pending.get(response.id);
  if (request) {
    pending.delete(response.id);
    clearTimeout(request.timer);
    request.resolve(response);
  }
});
function request(id, method, params) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`${method} timed out: ${stderr}`)), 20_000);
    pending.set(id, { resolve, timer });
    child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id, method, params })}\n`);
  });
}
try {
  const initialize = await request(1, "initialize", {
    protocolVersion: "2025-03-26", capabilities: {},
    clientInfo: { name: "rea-nix-smoke", version: "1" },
  });
  assert.equal(initialize.error, undefined, JSON.stringify(initialize));
  assert.ok(initialize.result.serverInfo.name);
  child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" })}\n`);
  const catalog = await request(2, "tools/list", {});
  assert.equal(catalog.error, undefined, JSON.stringify(catalog));
  assert.ok(catalog.result.tools.length > 0);
  console.log(`MCP initialize and tools/list passed (${catalog.result.tools.length} tools)`);
} finally {
  child.stdin.end();
  child.kill("SIGTERM");
  lines.close();
}

const require = createRequire(join(root, "package.json"));
assert.throws(() => require.resolve("frida"), { code: "MODULE_NOT_FOUND" });
const terminal = require("@lydell/node-pty").spawn(process.execPath, ["--version"], {
  env, cwd: process.cwd(), name: "xterm", cols: 80, rows: 24,
});
await new Promise((resolve, reject) => {
  let output = "";
  const timer = setTimeout(() => { terminal.kill(); reject(new Error("Native PTY timed out")); }, 10_000);
  terminal.onData((chunk) => { output += chunk; });
  terminal.onExit(({ exitCode }) => {
    clearTimeout(timer);
    try {
      assert.equal(exitCode, 0);
      assert.equal(output.trim(), process.version);
      resolve();
    } catch (error) { reject(error); }
  });
});
console.log("CLI aliases, direct dispatcher, and native PTY passed");
