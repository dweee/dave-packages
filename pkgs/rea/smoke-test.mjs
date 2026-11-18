import assert from "node:assert/strict";
import { spawn, execFileSync } from "node:child_process";
import { createRequire } from "node:module";
import { createInterface } from "node:readline";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const out = process.argv[2];
const root = join(out, "lib/rea-agents");
const env = { ...process.env, PATH: "/no-ambient-tools" };
for (const command of ["bin/rea", "bin/rea-agents", "lib/rea-agents/scripts/rea.mjs"]) {
  assert.equal(execFileSync(join(out, command), ["--version"], { env, encoding: "utf8" }).trim(), "6.7.0");
}

// REA enumerates processes before launching a provider. Exercise this separately
// so an absent ps is not misreported by the provider as a missing Java runtime.
if (process.platform === "darwin") {
  const listing = execFileSync(join(out, "libexec/rea-node"), ["-e",
    "process.stdout.write(require('node:child_process').execFileSync('ps', ['-axo', 'pid=,ppid=,pgid=,uid=,stat=,command='], {encoding:'utf8'}))"],
    { env, encoding: "utf8", maxBuffer: 4 * 1024 * 1024 });
  assert.match(listing, /\s*\d+\s+\d+\s+\d+\s+\d+\s+\S+\s+\S+/);
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
    const timer = setTimeout(() => reject(new Error(`${method} timed out: ${stderr}`)), method === "tools/call" ? 180_000 : 20_000);
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
  const android = await request(3, "tools/call", {
    name: "search_android_classes",
    arguments: { path: process.argv[3], query: "io.appium.android.apis.ApiDemos" },
  });
  assert.equal(android.error, undefined, JSON.stringify(android));
  assert.notEqual(android.result.isError, true, JSON.stringify(android));
  assert.match(JSON.stringify(android.result), /io\.appium\.android\.apis\.ApiDemos/);
  console.log(`MCP initialize, tools/list and Android class search passed (${catalog.result.tools.length} tools)`);
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

// Obtain the actual installed child environment, with no ambient tools/settings.
// This also exercises the native Darwin interpreter wrapper.
const cleanEnv = Object.fromEntries(Object.entries(env).filter(([key]) =>
  !key.startsWith("REA_") && key !== "JAVA_HOME"));
const wrappedNode = join(out, "libexec/rea-node");
const runtime = JSON.parse(execFileSync(wrappedNode,
  ["-e", "console.log(JSON.stringify(process.env))"], { env: cleanEnv, encoding: "utf8" }));
for (const [name, value] of Object.entries(runtime)) {
  if (name.startsWith("REA_") && (name.endsWith("COMMAND") || name.endsWith("PATH") || name === "REA_JADX_MCP_JAR")) {
    assert.ok(value.startsWith("/nix/store/"), `${name}: ${value}`);
  }
}
const override = "/caller-supplied/jadx.jar";
assert.equal(execFileSync(wrappedNode,
  ["-p", "process.env.REA_JADX_MCP_JAR"],
  { env: { ...cleanEnv, REA_JADX_MCP_JAR: override }, encoding: "utf8" }).trim(), override);
assert.match(execFileSync(join(runtime.JAVA_HOME, "bin/java"), ["--list-modules"],
  { env: runtime, encoding: "utf8" }), /jdk\.compiler@/);

function analyze(command, args = []) {
  const output = execFileSync(join(out, "bin/rea"), [command, ...args, "--json"],
    { env: { ...cleanEnv, REA_LOG_LEVEL: "silent", REA_JADX_HEAP_MIB: "1024", REA_JADX_ACTIVE_PROCESSOR_COUNT: "2" }, encoding: "utf8", timeout: 180_000, maxBuffer: 16 * 1024 * 1024 });
  const result = JSON.parse(output);
  assert.equal(result.error, undefined, output);
  assert.equal(result.code, undefined, output);
  return result;
}
const apk = process.argv[3];
assert.ok(apk, "Android APK fixture is required");
const classes = analyze("search-android-classes", [apk, "io.appium.android.apis.ApiDemos"]);
assert.match(JSON.stringify(classes), /io\.appium\.android\.apis\.ApiDemos/);
assert.match(JSON.stringify(analyze("inspect-android-method", [apk, "io.appium.android.apis.ApiDemos", "onCreate"])), /super\.onCreate/);
if (runtime.REA_APKTOOL_COMMAND) analyze("inspect-apktool-client");
if (process.platform === "linux") {
  analyze("inspect-pcap-client");
  assert.match(execFileSync(runtime.REA_SIGROK_COMMAND, ["--version"],
    { env: runtime, encoding: "utf8" }), /^sigrok-cli 0\.7\.2/);
}
console.log("Packaged tools, caller override, Android class/method, Apktool and packet clients passed");

const workspace = mkdtempSync(join(tmpdir(), "rea-tools-"));
try {
  const wasm = join(workspace, "empty.wasm");
  writeFileSync(wasm, Buffer.from([0, 97, 115, 109, 1, 0, 0, 0]));
  analyze("inspect-wasm-artifact", [wasm]);
  if (runtime.REA_PWNTOOLS_PYTHON) {
    const versions = JSON.parse(execFileSync(runtime.REA_PWNTOOLS_PYTHON,
      ["-c", "import json, importlib.metadata as m; print(json.dumps({n:m.version(n) for n in ['pwntools','pyelftools','unicorn']}))"],
      { env: runtime, encoding: "utf8" }));
    assert.deepEqual(versions, { pwntools: "4.15.0", pyelftools: "0.33", unicorn: "2.1.2" });
  }
} finally { rmSync(workspace, { recursive: true, force: true }); }
console.log("Strict WABT and Python dependency profiles passed");
