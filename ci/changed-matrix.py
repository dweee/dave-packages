#!/usr/bin/env python3
"""Filter native jobs by derivation identity across immutable Git revisions."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def load_matrix(family, package):
    filename = 'cache-only-matrix.py' if family == 'cache-only' else 'matrix.py'
    spec = importlib.util.spec_from_file_location('inventory', ROOT / 'ci' / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.matrix(package) if family == 'cache-only' else module.matrix(family, package)


def evaluate(tree, jobs, attribute):
    # tryEval is per package: an unrelated broken package must not hide changes.
    entries = ' '.join(
        '{ system = %s; package = %s; }' % (json.dumps(j['system']), json.dumps(j['package']))
        for j in jobs
    )
    expression = '''ps: map (j: let
      exists = builtins.hasAttr j.system ps && builtins.hasAttr j.package ps.${j.system};
      result = builtins.tryEval ps.${j.system}.${j.package}.drvPath;
    in j // { value = if !exists then "absent" else if result.success then result.value else null; }) [ %s ]''' % entries
    result = subprocess.check_output([
        'nix', 'eval', '--json', '--no-update-lock-file', '--no-write-lock-file',
        f'{tree}#{attribute}', '--apply', expression,
    ], text=True)
    return {(j['system'], j['package']): j['value'] for j in json.loads(result)}


def select(jobs, before, after):
    return [j for j in jobs if before[(j['system'], j['package'])] is None
            or after[(j['system'], j['package'])] is None
            or before[(j['system'], j['package'])] != after[(j['system'], j['package'])]]


def inventory_at(revision, family):
    filename = 'cache-only-platforms.json' if family == 'cache-only' else 'platforms.json'
    def read(name):
        return json.loads(subprocess.check_output(['git', 'show', f'{revision}:nix/{name}'], cwd=ROOT, text=True))
    inventory = read(filename)
    owners = set() if family == 'cache-only' else {
        name for info in read('forks.json').values() for name in info['packages']}
    return {(system, name) for system, names in inventory.items() for name in names
            if name not in owners}


def metadata_only(paths):
    return all(path in {'nix/platforms.json', 'nix/cache-only-platforms.json', 'nix/forks.json'}
               or path.startswith(('ci/', '.github/', 'docs/'))
               or ('/' not in path and path.endswith('.md'))
               for path in paths)


def changed(family, package, base, head):
    jobs = load_matrix(family, package)['include']
    if not base or set(base) == {'0'}:
        return {'include': jobs}  # Initial push has no previous tree.
    paths = subprocess.check_output(['git', 'diff', '--name-only', base, head, '--'],
                                    cwd=ROOT, text=True).splitlines()
    if metadata_only(paths):
        before = inventory_at(base, family)
        return {'include': [j for j in jobs if (j['system'], j['package']) not in before]}
    attribute = 'cacheOnlyPackages' if family == 'cache-only' else 'packages'
    with tempfile.TemporaryDirectory() as temp:
        trees = []
        try:
            for name, revision in [('base', base), ('head', head)]:
                tree = Path(temp) / name
                subprocess.run(['git', 'worktree', 'add', '--detach', str(tree), revision],
                               cwd=ROOT, check=True, stdout=sys.stderr)
                trees.append(tree)
            before = evaluate(trees[0], jobs, attribute)
            after = evaluate(trees[1], jobs, attribute)
            return {'include': select(jobs, before, after)}
        finally:
            for tree in trees:
                subprocess.run(['git', 'worktree', 'remove', '--force', str(tree)], cwd=ROOT, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('family', choices=['darwin', 'others', 'cache-only'])
    parser.add_argument('--package', default='all')
    args = parser.parse_args()
    event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())
    kind = os.environ['GITHUB_EVENT_NAME']
    if kind == 'workflow_dispatch':
        result = load_matrix(args.family, args.package)
    elif kind == 'pull_request':
        # Compare the tested merge result with its base branch: only the PR's effect.
        result = changed(args.family, args.package, event['pull_request']['base']['sha'],
                         os.environ['GITHUB_SHA'])
    elif kind == 'push':
        result = changed(args.family, args.package, event['before'], event['after'])
    else:
        raise ValueError('Unsupported event: ' + kind)
    print(json.dumps(result, separators=(',', ':')))
    output = os.environ.get('GITHUB_OUTPUT')
    if output:
        with open(output, 'a') as stream:
            stream.write('has_jobs=' + str(bool(result['include'])).lower() + '\n')


if __name__ == '__main__':
    main()
