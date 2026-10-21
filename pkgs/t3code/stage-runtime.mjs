// Stage the bundles' disk-backed production dependencies from the existing,
// offline pnpm install. Keep pnpm's versioned package directories, but rebuild
// their links from manifests so development dependencies cannot leak through.
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const [repository, destination] = process.argv.slice(2).map(p => path.resolve(p));
if (!repository || !destination) throw new Error('Usage: stage-runtime.mjs REPOSITORY DESTINATION');
const { isRuntimeExternalCliDependency } = await import(pathToFileURL(path.join(repository, 'scripts/lib/cli-external-packages.ts')));
const { isDesktopRuntimeExternalDependency } = await import(pathToFileURL(path.join(repository, 'scripts/lib/desktop-external-packages.ts')));
const store = fs.realpathSync(path.join(repository, 'node_modules/.pnpm'));
const staged = new Map();
const libc = process.platform === 'linux'
  ? (process.report.getReport().header.glibcVersionRuntime ? 'glibc' : 'musl')
  : undefined;
function supportsHost(manifest) {
  return [['os', process.platform], ['cpu', process.arch], ['libc', libc]].every(([key, host]) => {
    const values = manifest[key];
    return !values || (!values.includes(`!${host}`)
      && (values.every(value => value.startsWith('!')) || values.includes(host)));
  });
}

function resolvePackage(name, from) {
  for (let directory = from; ; directory = path.dirname(directory)) {
    const candidate = path.join(directory, 'node_modules', name);
    if (fs.existsSync(path.join(candidate, 'package.json'))) return fs.realpathSync(candidate);
    if (path.dirname(directory) === directory) return undefined;
  }
}

function link(target, filename) {
  fs.mkdirSync(path.dirname(filename), { recursive: true });
  fs.symlinkSync(path.relative(path.dirname(filename), target), filename, 'dir');
}

function stage(source) {
  if (staged.has(source)) return staged.get(source);
  const relative = path.relative(store, source);
  if (relative.startsWith('..') || path.isAbsolute(relative)) {
    throw new Error(`Unbundled workspace or dependency outside pnpm store: ${source}`);
  }
  const target = path.join(destination, 'node_modules/.pnpm', relative);
  staged.set(source, target); // Break dependency cycles before visiting children.
  fs.cpSync(source, target, {
    recursive: true,
    // Dependency links are rebuilt below; never copy development-only links or
    // executable shims referring to the build directory.
    filter: filename => path.basename(filename) !== 'node_modules',
    verbatimSymlinks: true,
  });
  fs.chmodSync(target, fs.statSync(target).mode | 0o200);
  const manifest = JSON.parse(fs.readFileSync(path.join(source, 'package.json')));
  const optional = manifest.optionalDependencies ?? {};
  const peers = manifest.peerDependencies ?? {};
  const dependencies = { ...peers, ...manifest.dependencies, ...optional };
  for (const name of Object.keys(dependencies).sort()) {
    const dependency = resolvePackage(name, source);
    if (!dependency) {
      if (name in optional || manifest.peerDependenciesMeta?.[name]?.optional) continue;
      // Electron is supplied by Nix, never by npm's download wrapper.
      if (name === 'electron') continue;
      throw new Error(`Missing production dependency ${name} of ${manifest.name}`);
    }
    if (!supportsHost(JSON.parse(fs.readFileSync(path.join(dependency, 'package.json'))))) {
      if (name in optional) continue;
      throw new Error(`Incompatible production dependency ${name} of ${manifest.name}`);
    }
    link(stage(dependency), path.join(target, 'node_modules', name));
  }
  return target;
}

// The bundler also externalizes transitive native loaders and Cursor packages.
// pnpm's hoisted directory supplies these even when the app's manifest does
// not name them directly. App-local versions take precedence over the hoist.
function packageNames(directory) {
  return fs.readdirSync(directory).filter(n => !n.startsWith('.')).flatMap(name =>
    name.startsWith('@')
      ? fs.readdirSync(path.join(directory, name)).map(child => `${name}/${child}`)
      : [name]);
}
const hoisted = path.join(repository, 'node_modules/.pnpm/node_modules');
for (const [app, external] of [
  ['server', isRuntimeExternalCliDependency],
  ['desktop', name => isRuntimeExternalCliDependency(name) || isDesktopRuntimeExternalDependency(name)],
]) {
  const appDirectory = path.join(repository, 'apps', app);
  const manifest = JSON.parse(fs.readFileSync(path.join(appDirectory, 'package.json')));
  const roots = new Set([
    ...Object.keys(manifest.dependencies ?? {}),
    ...packageNames(hoisted),
  ].filter(external));
  for (const name of [...roots].sort()) {
    const source = resolvePackage(name, appDirectory) ?? resolvePackage(name, path.dirname(hoisted));
    if (!source) throw new Error(`Missing runtime external ${name}`);
    if (!supportsHost(JSON.parse(fs.readFileSync(path.join(source, 'package.json'))))) continue;
    link(stage(source), path.join(destination, 'apps', app, 'node_modules', name));
  }
}

// Fail the build if a package-internal symlink escaped the staged tree.
const realDestination = fs.realpathSync(destination);
function checkLinks(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const filename = path.join(directory, entry.name);
    if (entry.isSymbolicLink()) {
      const target = fs.realpathSync(filename);
      if (!target.startsWith(`${realDestination}/`)) throw new Error(`Runtime link escapes output: ${filename}`);
    } else if (entry.isDirectory()) checkLinks(filename);
  }
}
checkLinks(destination);
console.log(`Staged ${staged.size} runtime packages; no development dependency tree copied.`);
