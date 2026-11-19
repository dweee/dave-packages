#!/usr/bin/env python3
"""Pin Horizon's three channels in sources.json.

  stable    the game: the newest dated Nightly (nightly-YYYY-MM-DD); the launcher: the newest launcher@X.Y.Z
  unstable  the game: the rolling `nightly` release; the launcher: as stable (it has one release line)
  head      both: main's newest commit

Source builds pin the Nightly's source commit, which upstream keeps for good as nightly-source/<date>-<short>.
The prebuilt (-bin) packages pin release assets by the SHA256SUMS upstream publishes; dated Nightlies are
deleted after seven days, so those pins only stay fetchable while this keeps running.

  update.py [--check] [--channel stable|unstable|head ...] [--system SYSTEM]

--check changes nothing and prints `update available <what>: <current> -> <latest>` lines
(ci/update-monitor.py collects those). Needs nix, and GH_TOKEN or GITHUB_TOKEN to avoid rate limits.
"""
import argparse
import base64
import datetime as dt
import json
import os
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SOURCES = HERE / 'sources.json'
REPO = 'horizon-rust/horizon'
MIXINS = 'horizon-rust/horizon-mixins'
REPLAY = None
CAPTURE = None
FAKE = 'sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
LAUNCHER_TAG = re.compile(r'^launcher@(\d+)\.(\d+)\.(\d+)$')
DATED = re.compile(r'^nightly-(\d{4}-\d{2}-\d{2})$')
LAUNCHER_ASSETS = {
    'x86_64-linux': 'horizon-launcher-linux-x86_64.tar.gz',
    'aarch64-darwin': 'horizon-launcher-macos-arm64.zip',
    'x86_64-darwin': 'horizon-launcher-macos-x64.zip',
}
GAME_ASSETS = {
    'x86_64-linux': 'horizon-linux-x86_64.tar.gz',
    'aarch64-darwin': 'horizon-macos-arm64.zip',
    'x86_64-darwin': 'horizon-macos-x64.zip',
}
SERVER_ASSETS = {
    'x86_64-linux': 'horizon-server-linux-x86_64.tar.gz',
    # The macOS game folders hold horizon-server beside the full game.
    'aarch64-darwin': 'horizon-macos-arm64.zip',
    'x86_64-darwin': 'horizon-macos-x64.zip',
}


def fetch(url, raw=False):
    if REPLAY is not None:
        if url not in REPLAY:
            raise ValueError('Frozen Horizon snapshot lacks ' + url)
        data = base64.b64decode(REPLAY[url], validate=True)
        return data if raw else json.loads(data)
    request = urllib.request.Request(url, headers={'User-Agent': 'dave-packages-horizon-update'})
    token = os.environ.get('GH_TOKEN') or os.environ.get('GITHUB_TOKEN')
    if token and url.startswith('https://api.github.com/'):
        request.add_header('Authorization', 'Bearer ' + token)
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()
    if CAPTURE is not None:
        CAPTURE[url] = base64.b64encode(data).decode()
    return data if raw else json.loads(data)


def api(path):
    return fetch('https://api.github.com/repos/' + path)


def releases():
    found = []
    for page in range(1, 6):
        batch = api(f'{REPO}/releases?per_page=100&page={page}')
        found += batch
        if len(batch) < 100:
            break
    return found


def commit(repo, ref):
    value = api(f'{repo}/commits/{ref}')
    date = value['commit']['committer']['date'][:10]
    return value['sha'], date


def sri(hex_digest):
    return 'sha256-' + base64.b64encode(bytes.fromhex(hex_digest)).decode()


def asset_pins(release, names):
    """{system: {url, hash}} from the release's SHA256SUMS, for the assets it has."""
    sums = {}
    for asset in release['assets']:
        if asset['name'] == 'SHA256SUMS':
            text = fetch(asset['browser_download_url'], raw=True).decode()
            for line in text.splitlines():
                digest, _, name = line.strip().partition('  ')
                sums[name.lstrip('*')] = digest
    tag = release['tag_name']
    pins = {}
    for system, name in names.items():
        if name in sums:
            pins[system] = {
                'url': f'https://github.com/{REPO}/releases/download/{tag.replace("@", "%40")}/{name}',
                'hash': sri(sums[name]),
            }
    return pins


def nix(*args):
    return subprocess.run(['nix', '--extra-experimental-features', 'nix-command flakes', *args],
                          text=True, capture_output=True, cwd=ROOT)


def source_hash(repo, rev):
    result = nix('flake', 'prefetch', '--json', f'github:{repo}/{rev}')
    if result.returncode:
        raise RuntimeError(result.stderr)
    return json.loads(result.stdout)['hash']


def cargo_hash(kind, pin, system):
    """The vendored crates' hash, from the mismatch Nix reports for a fake one."""
    expression = f'''
      let
        flake = builtins.getFlake "git+file://{ROOT}";
        pkgs = import flake.inputs.nixpkgs {{ system = "{system}"; }};
        pin = builtins.fromJSON {json.dumps(json.dumps({**pin, 'cargoHash': FAKE}))};
      in (pkgs.callPackage {HERE}/{kind}.nix ({{ inherit pin; }}
          // pkgs.lib.optionalAttrs ("{kind}" == "game") {{ horizon-mixins = null; wrapFolder = _: ""; }})).cargoDeps
    '''
    result = nix('build', '--no-link', '--impure', '--expr', expression)
    match = re.search(r'got:\s+(sha256-[A-Za-z0-9+/=]+)', result.stderr)
    if not match:
        raise RuntimeError(f'no cargo hash for {kind} {pin["rev"]}:\n{result.stderr[-3000:]}')
    return match.group(1)


def source_pin(kind, current, rev, version, system, repo=REPO, **extra):
    """A source pin: the hashes are kept when the revision is the one already pinned."""
    if current and current.get('rev') == rev and current.get('cargoHash'):
        return {**current, 'version': version, **extra}
    pin = {'version': version, 'rev': rev, 'hash': source_hash(repo, rev), **extra}
    pin['cargoHash'] = cargo_hash(kind, pin, system)
    return pin


def mixins_rev(rev):
    text = fetch(f'https://raw.githubusercontent.com/{REPO}/{rev}/launcher/src/native_mods.rs', raw=True).decode()
    return re.search(r'MIXINS_REV: &str = "([0-9a-f]{40})"', text).group(1)


def nightly_source(release):
    match = re.search(r'Source: commit ([0-9a-f]{40})', release.get('body') or '')
    if match:
        return match.group(1)
    return commit(REPO, release['tag_name'])[0]


def resolve(old, channels, system, check):
    everything = releases()
    launchers = [r for r in everything if LAUNCHER_TAG.match(r['tag_name']) and not r['draft']
                 and not r['prerelease']]
    launcher = max(launchers, key=lambda r: tuple(map(int, LAUNCHER_TAG.match(r['tag_name']).groups())))
    dated = max((r for r in everything if DATED.match(r['tag_name']) and not r['draft']),
                key=lambda r: r['tag_name'])
    rolling = next(r for r in everything if r['tag_name'] == 'nightly')
    head, head_date = commit(REPO, 'main')
    launcher_version = launcher['tag_name'].removeprefix('launcher@')

    def game(release):
        date = re.search(r'(\d{4}-\d{2}-\d{2})', release['name']).group(1)
        rev = nightly_source(release)
        return rev, date, {'release': f'nightly-{date}', 'nightly': f'{date} {rev[:7]}'}

    wanted = {
        'stable': {'launcher': (commit(REPO, launcher['tag_name'])[0], launcher_version, {'release': launcher_version}),
                   'game': game(dated), 'bin': dated},
        'unstable': {'game': game(rolling), 'bin': rolling},
        'head': {'launcher': (head, f'{launcher_version}-unstable-{head_date}', {}),
                 'game': (head, head_date, {})},
    }
    new = json.loads(json.dumps(old))
    changes = []
    for channel in channels:
        for kind in ('launcher', 'game'):
            if kind not in wanted[channel]:
                continue
            rev, label, extra = wanted[channel][kind]
            current = old.get(kind, {}).get(channel)
            version = label if kind == 'launcher' else f'0-unstable-{label}'
            if current and current.get('rev') == rev:
                continue
            changes.append(f'{kind} {channel}: {(current or {}).get("version")} -> {version} ({rev[:7]})')
            if not check:
                new.setdefault(kind, {})[channel] = source_pin('game' if kind == 'game' else 'launcher',
                                                               current, rev, version, system, **extra)
        if 'bin' in wanted[channel]:
            release = wanted[channel]['bin']
            rev, date, _ = game(release)
            pins = {'version': f'0-unstable-{date}', 'tag': release['tag_name'], 'rev': rev,
                    'game': asset_pins(release, GAME_ASSETS), 'server': asset_pins(release, SERVER_ASSETS)}
            if old.get('bin', {}).get(channel) != pins:
                changes.append(f'bin {channel}: {old.get("bin", {}).get(channel, {}).get("version")} -> '
                               f'{pins["version"]} ({rev[:7]})')
                new.setdefault('bin', {})[channel] = pins
    # The launcher's prebuilt release and the horizon-mixins its native-mod builds use.
    if 'stable' in channels:
        pins = {'version': launcher_version, 'assets': asset_pins(launcher, LAUNCHER_ASSETS)}
        if old.get('bin', {}).get('launcher') != pins:
            changes.append(f'bin launcher: {old.get("bin", {}).get("launcher", {}).get("version")} -> '
                           f'{launcher_version}')
            new.setdefault('bin', {})['launcher'] = pins
        rev = mixins_rev(wanted['stable']['launcher'][0])
        current = old.get('mixins')
        if not current or current.get('rev') != rev:
            date = commit(MIXINS, rev)[1]
            changes.append(f'mixins: {(current or {}).get("rev", "-")[:7]} -> {rev[:7]}')
            if not check:
                new['mixins'] = source_pin('mixins', current, rev, f'0.6.0-unstable-{date}', system, repo=MIXINS)
    return new, changes


def main():
    global REPLAY, CAPTURE
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--channel', action='append', choices=['stable', 'unstable', 'head'])
    parser.add_argument('--system', default=None, help='where the cargo hashes are computed (default: this one)')
    parser.add_argument('--write-snapshot', type=Path)
    parser.add_argument('--snapshot', type=Path)
    parser.add_argument('--apply', action='store_true', help='Apply a frozen snapshot (default without snapshot options)')
    args = parser.parse_args()
    if args.snapshot and args.write_snapshot:
        parser.error('Choose one snapshot mode')
    if args.snapshot:
        snapshot = json.loads(args.snapshot.read_text())
        if snapshot.get('version') != 1 or snapshot.get('repository') != REPO or not isinstance(snapshot.get('responses'), dict):
            raise ValueError('Invalid Horizon snapshot')
        REPLAY = snapshot['responses']
    if args.write_snapshot:
        CAPTURE = {}
    snapshot_mode = bool(args.snapshot or args.write_snapshot)
    check = args.check or (snapshot_mode and not args.apply)
    system = args.system or nix('eval', '--impure', '--raw', '--expr', 'builtins.currentSystem').stdout.strip()
    old = json.loads(SOURCES.read_text()) if SOURCES.exists() else {}
    new, changes = resolve(old, args.channel or ['stable', 'unstable', 'head'], system, check)
    if args.write_snapshot:
        args.write_snapshot.write_text(json.dumps({'version': 1, 'repository': REPO, 'responses': CAPTURE}, indent=2) + '\n')
    if not snapshot_mode:
        for change in changes:
            print(('update available ' if check else 'horizon: ') + change)
    if not check and changes:
        new['updated'] = dt.datetime.now(dt.timezone.utc).strftime('%Y-%m-%d')
        SOURCES.write_text(json.dumps(new, indent=2, sort_keys=True) + '\n')
    if snapshot_mode:
        print(json.dumps({'changes': changes, 'applied': not check and bool(changes)}))
    elif not changes:
        print('horizon: up to date')
    return 0


if __name__ == '__main__':
    sys.exit(main())
