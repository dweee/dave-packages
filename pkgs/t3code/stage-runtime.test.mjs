import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

// Nix copies the test and implementation to different store paths.
const script = process.env.T3CODE_STAGE_RUNTIME_SCRIPT
  ?? fileURLToPath(new URL('./stage-runtime.mjs', import.meta.url));

test('isolated runtime preserves versions, cycles and optional peers without build tools', () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 't3-stage-'));
  try {
    const source = path.join(temporary, 'source');
    const output = path.join(temporary, 'output');
    function write(filename, content) {
      fs.mkdirSync(path.dirname(filename), { recursive: true });
      fs.writeFileSync(filename, content);
    }
    function json(filename, value) { write(filename, JSON.stringify(value)); }
    function link(target, filename) {
      fs.mkdirSync(path.dirname(filename), { recursive: true });
      fs.symlinkSync(path.relative(path.dirname(filename), target), filename);
    }
    function pkg(name, version, extra = {}) {
      const directory = path.join(source, 'node_modules/.pnpm', `${name}@${version}`, 'node_modules', name);
      json(path.join(directory, 'package.json'), { name, version, main: 'index.cjs', ...extra });
      write(path.join(directory, 'index.cjs'), `module.exports = ${JSON.stringify(version)}`);
      return directory;
    }
    const shared = pkg('shared', '1');
    const foreign = pkg('foreign', '1', { os: [process.platform === 'darwin' ? 'linux' : 'darwin'] });
    const first = pkg('runtime', '1', {
      dependencies: { shared: '1' }, devDependencies: { 'build-only': '1' },
      optionalDependencies: { absent: '1', foreign: '1' },
      peerDependencies: { 'optional-peer': '1' },
      peerDependenciesMeta: { 'optional-peer': { optional: true } },
    });
    const second = pkg('runtime', '2', { dependencies: { shared: '1' } });
    const build = pkg('build-only', '1');
    for (const runtime of [first, second]) {
      link(shared, path.join(runtime, 'node_modules/shared'));
      link(build, path.join(runtime, 'node_modules/build-only'));
    }
    link(foreign, path.join(first, 'node_modules/foreign'));
    json(path.join(shared, 'package.json'), { name: 'shared', version: '1', main: 'index.cjs', dependencies: { runtime: '1' } });
    link(first, path.join(shared, 'node_modules/runtime'));
    fs.mkdirSync(path.join(source, 'node_modules/.pnpm/node_modules'), { recursive: true });
    for (const [app, runtime] of [['server', first], ['desktop', second]]) {
      json(path.join(source, 'apps', app, 'package.json'), { dependencies: { runtime: '*' } });
      link(runtime, path.join(source, 'apps', app, 'node_modules/runtime'));
    }
    for (const [filename, selector] of [
      ['cli-external-packages', 'isRuntimeExternalCliDependency'],
      ['desktop-external-packages', 'isDesktopRuntimeExternalDependency'],
    ]) write(path.join(source, 'scripts/lib', `${filename}.ts`), `export const ${selector} = name => name === 'runtime';`);
    execFileSync(process.execPath, [script, source, output]);
    const server = createRequire(path.join(output, 'apps/server/probe.cjs'));
    const desktop = createRequire(path.join(output, 'apps/desktop/probe.cjs'));
    assert.equal(server('runtime'), '1');
    assert.equal(desktop('runtime'), '2');
    assert.equal(createRequire(server.resolve('runtime'))('shared'), '1');
    assert.throws(() => createRequire(server.resolve('runtime'))('build-only'), { code: 'MODULE_NOT_FOUND' });
    assert.equal(fs.existsSync(path.join(output, 'node_modules/.pnpm/foreign@1')), false);
    // A genuinely missing required dependency must stop packaging.
    json(path.join(first, 'package.json'), { name: 'runtime', dependencies: { missing: '1' } });
    assert.throws(() => execFileSync(process.execPath, [script, source, `${output}-broken`], { stdio: 'pipe' }),
      /Missing production dependency missing/);
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true });
  }
});
