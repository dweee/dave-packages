#!/usr/bin/env python3
"""Check Mopidy 4 group pins, or prepare an isolated review candidate.

Never rewrites the working checkout. --candidate copies current tracked and
unignored files (including WIP) to a new directory, refreshes the owned pins in
nix/mopidy-4.nix and, with --build, builds every owned package there. Candidates
require review; the group is never bumped piecemeal.
"""
import argparse
import base64
import difflib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

OVERLAY = 'nix/mopidy-4.nix'
OWNED_COUNT = 11
# Inherited from the catalog's nixpkgs pin, not bumped outside the reviewed group.
INHERITED = ['mopidy-iris', 'mopidy-notify', 'mopidy-jellyfin', 'mopidy-tunein', 'mopidy-bandcamp']


def run(*args, cwd=None):
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(f'{args[0]} failed ({result.returncode}): {result.stderr[-3000:]}')
    return result.stdout.strip()


def get(url):
    headers = {'User-Agent': 'dave-packages-mopidy-updater'}
    token = os.environ.get('GITHUB_TOKEN') or os.environ.get('GH_TOKEN')
    if token and url.startswith('https://api.github.com/'):
        headers['Authorization'] = 'Bearer ' + token
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=60) as response:
        return json.loads(response.read())


def copy_checkout(root, target):
    if target.exists():
        raise RuntimeError(f'candidate directory already exists: {target}')
    if target == root or root in target.parents:
        raise RuntimeError('candidate directory must be outside source checkout')
    files = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=root).split(b'\0')
    target.mkdir(parents=True)
    for raw in set(files):
        if not raw:
            continue
        rel = Path(os.fsdecode(raw))
        source = root / rel
        if source.is_file() or source.is_symlink():
            dest = target / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, dest, follow_symlinks=False)


def owned_row(name, current, block):
    info = get(f'https://pypi.org/pypi/{name}/json')
    latest = info['info']['version']
    if re.search(r'[A-Za-z]', latest):
        raise RuntimeError(f'{name}: refusing prerelease {latest}')
    row = dict(file=OVERLAY, name=name, current=current, latest=latest, upstream=f'https://pypi.org/project/{name}/{latest}/')
    github = re.search(r'owner = "([^"]+)";\s*repo = "([^"]+)";', block)
    if github:
        owner, repo = github.groups()
        # Verify the tag exists at the maintainer's repository; a PyPI version
        # does not imply the GitHub source tag exists.
        tag = f'v{latest}'
        get(f'https://api.github.com/repos/{owner}/{repo}/git/ref/tags/{tag}')
        row['url'] = f'https://github.com/{owner}/{repo}/archive/refs/tags/{tag}.tar.gz'
        row['tag'] = tag
    else:
        sdist = next((f for f in info['urls'] if f['packagetype'] == 'sdist' and not f.get('yanked')), None)
        if not sdist:
            raise RuntimeError(f'{name}: no non-yanked source distribution')
        row['hash'] = 'sha256-' + base64.b64encode(bytes.fromhex(sdist['digests']['sha256'])).decode()
    return row


def inherited_row(name):
    info = get(f'https://pypi.org/pypi/{name}/json')
    return dict(name=name, current='nixpkgs pin', latest=info['info']['version'], skipped=True,
                reason='inherited nixpkgs source; flake input update and group validation required',
                upstream=f'https://pypi.org/project/{name}/')


def plan(root):
    contents = (root / OVERLAY).read_text()
    pattern = r'(?m)^    (mopidy(?:-[\w-]+)?) = .*?overridePythonAttrs\s*\('
    starts = list(re.finditer(pattern, contents))
    owned = []
    for index, match in enumerate(starts):
        block = contents[match.start():starts[index+1].start() if index+1 < len(starts) else contents.index('\n  });', match.start())]
        version = re.search(r'version = "([^"]+)";', block)
        if version:
            owned.append((match.group(1), version.group(1), block))
    with ThreadPoolExecutor(max_workers=8) as pool:
        rows = list(pool.map(lambda item: owned_row(*item), owned))
    if len(rows) != OWNED_COUNT:
        raise RuntimeError(f'expected {OWNED_COUNT} owned Mopidy pins, found {len(rows)}; review group coverage')
    with ThreadPoolExecutor(max_workers=8) as pool:
        rows.extend(pool.map(inherited_row, INHERITED))
    rows.append(dict(name='mopidy-tidal', skipped=True, reason='disabled: upstream Mopidy 4 compatibility requires manual review'))
    return rows


def update(root, rows):
    path = root / OVERLAY
    contents = path.read_text()
    for row in rows:
        if row.get('skipped') or row['current'] == row['latest']:
            continue
        if 'url' in row:
            row['hash'] = json.loads(run('nix', 'store', 'prefetch-file', '--json', '--unpack', row['url']))['hash']
        pattern = rf'(?m)(^    {re.escape(row["name"])} = .*?overridePythonAttrs\s*\(.*?)(?=^    mopidy[^ ]* = |^  \}}\);)'
        matches = list(re.finditer(pattern, contents, re.S))
        if len(matches) != 1:
            raise RuntimeError(f'expected one override for {row["name"]}')
        match = matches[0]
        block = match.group(0)
        block = block.replace(f'version = "{row["current"]}";', f'version = "{row["latest"]}";')
        if 'tag' in row:
            block = re.sub(r'tag = "[^"]+";', f'tag = "{row["tag"]}";', block, count=1)
        block, count = re.subn(r'hash = "[^"]+";', f'hash = "{row["hash"]}";', block, count=1)
        if count != 1:
            raise RuntimeError(f'no source hash for {row["name"]}')
        contents = contents[:match.start()] + block + contents[match.end():]
    path.write_text(contents)


def build(root, rows, system):
    names = sorted({'mopidy'} | {row['name'] for row in rows if not row.get('skipped')})
    installables = [f'path:{root}#packages.{system}.{name}' for name in names]
    return run('nix', 'build', '--no-link', '--print-out-paths', *installables, cwd=root)


def main():
    sys.stdout.reconfigure(line_buffering=True)
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument('--check', action='store_true')
    modes.add_argument('--candidate', type=Path)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument('--system', help='validation platform (default: native CPU, Linux)')
    parser.add_argument('--build', action='store_true', help='build every owned package in the candidate')
    args = parser.parse_args()
    rows = plan(args.root)
    for row in rows:
        if row.get('skipped'):
            print(f'SKIPPED {row["name"]}: {row["reason"]}')
        else:
            print(f'{row["name"]}: {row["current"]} -> {row["latest"]} ({row["upstream"]})')
    if args.candidate:
        if not args.system:
            args.system = run('nix', 'eval', '--impure', '--raw', '--expr', 'builtins.currentSystem').replace('-darwin', '-linux')
        target = args.candidate.resolve()
        copy_checkout(args.root.resolve(), target)
        validation = 'not run; candidate requires group build and runtime review'
        error = None
        try:
            update(target, rows)
            if args.build:
                validation = 'group build passed: ' + build(target, rows, args.system).replace('\n', ' ')
        except Exception as exc:
            error = exc
            validation = f'FAILED: {exc}'
        finally:
            patch = ''.join(difflib.unified_diff((args.root / OVERLAY).read_text().splitlines(True),
                                                 (target / OVERLAY).read_text().splitlines(True),
                                                 fromfile='a/' + OVERLAY, tofile='b/' + OVERLAY))
            (target / 'changes.patch').write_text(patch)
            (target / 'mopidy-update-report.json').write_text(json.dumps(dict(group='mopidy', rows=rows, validation=validation), indent=2) + '\n')
        if error:
            raise RuntimeError(f'{error}; retained candidate/report/changes.patch: {target}')
        print(f'Candidate: {target}; {validation}')
    changed = sum(not r.get('skipped') and r['current'] != r['latest'] for r in rows)
    print(f'SUCCESS mopidy: checked {len(rows)} items, {changed} candidate changes, {sum(bool(r.get("skipped")) for r in rows)} manual exceptions')


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print(f'FAILURE: {exc}', file=sys.stderr)
        sys.exit(1)
