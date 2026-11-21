#!/usr/bin/env python3
"""Exercise selection and real Nix evaluation without downloading inputs."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

CI = Path(__file__).resolve().parent
ROOT = CI.parent



def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


changed = load(CI / 'changed-matrix.py', 'changed')

PLATFORMS = {
    'aarch64-darwin': ['shared', 'mac-only', 'forked'],
    'x86_64-linux': ['shared', 'linux-only', 'forked'],
    'aarch64-linux': ['shared'],
}
FORKS = {'fork': {'repository': 'https://example.invalid/fork', 'packages': ['forked']}}


def fixture_tree(root, platforms=PLATFORMS):
    """A repository root holding the real matrix helpers and a small inventory."""
    (root / 'ci').mkdir(parents=True)
    (root / 'nix').mkdir()
    for name in ('matrix.py', 'changed-matrix.py', 'cache-only-matrix.py'):
        shutil.copy(CI / name, root / 'ci' / name)
    (root / 'nix' / 'platforms.json').write_text(json.dumps(platforms))
    (root / 'nix' / 'forks.json').write_text(json.dumps(FORKS))
    return root


def git(root, *args):
    return subprocess.run(['git', '-c', 'user.name=t', '-c', 'user.email=t@example.invalid', *args],
                          cwd=root, check=True, capture_output=True, text=True).stdout.strip()


def jobs(result):
    return sorted((j['system'], j['package']) for j in result['include'])


class InventoryTests(unittest.TestCase):
    """ci/matrix.py builds every native darwin and others job."""

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.matrix = load(fixture_tree(Path(self.directory.name)) / 'ci' / 'matrix.py', 'fixture_matrix')

    def test_families_split_by_platform_with_their_runners(self):
        darwin = self.matrix.matrix('darwin')['include']
        others = self.matrix.matrix('others')['include']
        self.assertEqual([(j['system'], j['package'], j['runner']) for j in darwin],
                         [('aarch64-darwin', 'shared', 'macos-15'), ('aarch64-darwin', 'mac-only', 'macos-15')])
        self.assertEqual([(j['system'], j['package'], j['runner']) for j in others],
                         [('x86_64-linux', 'shared', 'ubuntu-24.04'), ('x86_64-linux', 'linux-only', 'ubuntu-24.04'),
                          ('aarch64-linux', 'shared', 'ubuntu-24.04-arm')])

    def test_selected_package_builds_on_each_platform_of_its_family(self):
        self.assertEqual(jobs(self.matrix.matrix('others', 'shared')),
                         [('aarch64-linux', 'shared'), ('x86_64-linux', 'shared')])
        self.assertEqual(jobs(self.matrix.matrix('darwin', 'mac-only')), [('aarch64-darwin', 'mac-only')])

    def test_fork_owned_packages_are_left_to_their_fork(self):
        for family in ('darwin', 'others'):
            self.assertNotIn('forked', [j['package'] for j in self.matrix.matrix(family)['include']])
            with self.assertRaisesRegex(ValueError, 'application fork: https://example.invalid/fork'):
                self.matrix.matrix(family, 'forked')

    def test_package_outside_the_family_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'unavailable'):
            self.matrix.matrix('darwin', 'linux-only')
        with self.assertRaisesRegex(ValueError, 'unavailable'):
            self.matrix.matrix('others', 'missing')

    def test_real_inventory_covers_every_unforked_package_once(self):
        real = load(CI / 'matrix.py', 'real_matrix')
        platforms = json.loads((ROOT / 'nix/platforms.json').read_text())
        forks = {n for info in json.loads((ROOT / 'nix/forks.json').read_text()).values() for n in info['packages']}
        expected = sorted((system, name) for system, names in platforms.items() for name in names
                          if name not in forks)
        found = jobs(real.matrix('darwin')) + jobs(real.matrix('others'))
        self.assertEqual(sorted(found), expected)
        self.assertEqual(len(found), len(set(found)))
        runners = {'aarch64-darwin': 'macos-15', 'x86_64-linux': 'ubuntu-24.04', 'aarch64-linux': 'ubuntu-24.04-arm'}
        for family in ('darwin', 'others'):
            for job in real.matrix(family)['include']:
                self.assertEqual(job['runner'], runners[job['system']])
                self.assertEqual(job['system'].endswith('-darwin'), family == 'darwin')


class DispatchScopeTests(unittest.TestCase):
    """A dispatched `changed` run selects the branch's own changes, like a PR run."""

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = fixture_tree(Path(self.directory.name) / 'repo')
        git(self.root, 'init', '-q', '-b', 'main')
        git(self.root, 'add', '.')
        git(self.root, 'commit', '-qm', 'base')
        self.base = git(self.root, 'rev-parse', 'HEAD')
        git(self.root, 'update-ref', 'refs/remotes/origin/main', self.base)
        git(self.root, 'checkout', '-qb', 'automation/input-updates')
        self.module = load(self.root / 'ci' / 'changed-matrix.py', 'fixture_changed')

    def add_package(self, system, name, message):
        path = self.root / 'nix' / 'platforms.json'
        inventory = json.loads(path.read_text())
        inventory[system].append(name)
        path.write_text(json.dumps(inventory))
        git(self.root, 'commit', '-qam', message)

    def test_branch_dispatch_builds_only_what_the_branch_added(self):
        self.add_package('x86_64-linux', 'branch-new', 'branch')
        result = self.module.dispatched('others', 'changed', 'refs/heads/automation/input-updates', 'main')
        self.assertEqual(jobs(result), [('x86_64-linux', 'branch-new')])
        self.assertEqual(self.module.dispatched('darwin', 'changed', 'refs/heads/automation/input-updates', 'main'),
                         {'include': []})

    def test_main_merged_into_the_branch_is_not_rebuilt(self):
        git(self.root, 'checkout', '-q', 'main')
        self.add_package('x86_64-linux', 'from-main', 'main moved')
        git(self.root, 'update-ref', 'refs/remotes/origin/main', git(self.root, 'rev-parse', 'HEAD'))
        git(self.root, 'checkout', '-q', 'automation/input-updates')
        git(self.root, 'merge', '-q', '--no-edit', 'main')
        self.add_package('aarch64-linux', 'branch-new', 'branch')
        result = self.module.dispatched('others', 'changed', 'refs/heads/automation/input-updates', 'main')
        self.assertEqual(jobs(result), [('aarch64-linux', 'branch-new')])

    def test_default_branch_and_named_packages_keep_their_scope(self):
        self.add_package('x86_64-linux', 'branch-new', 'branch')
        everything = self.module.load_matrix('others', 'all')
        self.assertEqual(self.module.dispatched('others', 'changed', 'refs/heads/main', 'main'), everything)
        self.assertEqual(self.module.dispatched('others', 'all', 'refs/heads/automation/input-updates', 'main'),
                         everything)
        self.assertEqual(jobs(self.module.dispatched('others', 'shared', 'refs/heads/automation/input-updates',
                                                     'main')),
                         [('aarch64-linux', 'shared'), ('x86_64-linux', 'shared')])

    def test_missing_default_branch_fails_instead_of_building_nothing(self):
        git(self.root, 'update-ref', '-d', 'refs/remotes/origin/main')
        with self.assertRaises(subprocess.CalledProcessError):
            self.module.dispatched('others', 'changed', 'refs/heads/automation/input-updates', 'main')



class PushComparisonTests(unittest.TestCase):
    """changed() on real Git history: initial pushes, inventory edits and recipe edits."""

    FLAKE = '''{
      outputs = {self}: { packages.x86_64-linux = {
        shared = builtins.derivation { name = "SHARED"; system = "x86_64-linux"; builder = "/bin/sh"; };
        linux-only = builtins.derivation { name = "linux-only"; system = "x86_64-linux"; builder = "/bin/sh"; };
      }; };
    }'''

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = fixture_tree(Path(self.directory.name) / 'repo',
                                 {'x86_64-linux': ['shared', 'linux-only']})
        (self.root / 'nix' / 'cache-only-platforms.json').write_text(json.dumps({'x86_64-linux': ['cached']}))
        (self.root / 'flake.nix').write_text(self.FLAKE.replace('SHARED', 'shared'))
        git(self.root, 'init', '-q', '-b', 'main')
        git(self.root, 'add', '.')
        git(self.root, 'commit', '-qm', 'base')
        self.base = git(self.root, 'rev-parse', 'HEAD')
        self.module = load(self.root / 'ci' / 'changed-matrix.py', 'push_changed')

    def commit(self, path, text):
        (self.root / path).write_text(text)
        git(self.root, 'commit', '-qam', 'change ' + path)
        return git(self.root, 'rev-parse', 'HEAD')

    def test_initial_push_builds_everything(self):
        everything = self.module.load_matrix('others', 'all')
        self.assertEqual(len(everything['include']), 2)
        for before in ('', '0' * 40):
            self.assertEqual(self.module.changed('others', 'all', before, self.base), everything)

    def test_cache_only_inventory_edit_selects_only_the_new_target(self):
        head = self.commit('nix/cache-only-platforms.json', json.dumps({'x86_64-linux': ['cached', 'added']}))
        self.assertEqual(jobs(self.module.changed('cache-only', 'all', self.base, head)),
                         [('x86_64-linux', 'added')])

    def test_recipe_edit_selects_the_changed_derivation_and_cleans_worktrees(self):
        head = self.commit('flake.nix', self.FLAKE.replace('SHARED', 'shared-updated'))
        self.assertEqual(jobs(self.module.changed('others', 'all', self.base, head)), [('x86_64-linux', 'shared')])
        self.assertEqual(len(git(self.root, 'worktree', 'list', '--porcelain').split('\n\n')), 1)
        self.assertEqual(self.module.changed('others', 'all', head, head), {'include': []})

class EventRoutingTests(unittest.TestCase):
    """main() picks the compared revisions from the GitHub event."""

    def run_main(self, kind, event, family='others', package='changed', selection=None):
        selection = {'include': []} if selection is None else selection
        with tempfile.TemporaryDirectory() as directory:
            event_path, output = Path(directory) / 'event.json', Path(directory) / 'output'
            event_path.write_text(json.dumps(event))
            env = {'GITHUB_EVENT_PATH': str(event_path), 'GITHUB_EVENT_NAME': kind, 'GITHUB_OUTPUT': str(output),
                   'GITHUB_SHA': 'merge-sha', 'GITHUB_REF': 'refs/heads/topic'}
            stdout = io.StringIO()
            with patch.dict(os.environ, env), \
                    patch('sys.argv', ['changed-matrix.py', family, '--package', package]), \
                    patch.object(changed, 'changed', return_value=selection) as compare, \
                    patch.object(changed, 'dispatched', return_value=selection) as dispatch, \
                    contextlib.redirect_stdout(stdout):
                changed.main()
            return compare, dispatch, json.loads(stdout.getvalue()), output.read_text()

    def test_pull_request_compares_the_merge_result_with_its_base(self):
        compare, dispatch, _, _ = self.run_main('pull_request', {'pull_request': {'base': {'sha': 'base-sha'}}},
                                                package='all')
        compare.assert_called_once_with('others', 'all', 'base-sha', 'merge-sha')
        dispatch.assert_not_called()

    def test_push_compares_before_and_after(self):
        compare, _, _, _ = self.run_main('push', {'before': 'old', 'after': 'new'}, family='darwin', package='all')
        compare.assert_called_once_with('darwin', 'all', 'old', 'new')

    def test_push_and_pull_request_treat_the_dispatch_sentinel_as_everything(self):
        compare, _, _, _ = self.run_main('push', {'before': 'old', 'after': 'new'}, package='changed')
        compare.assert_called_once_with('others', 'all', 'old', 'new')
        compare, _, _, _ = self.run_main('pull_request', {'pull_request': {'base': {'sha': 'base-sha'}}},
                                         package='changed')
        compare.assert_called_once_with('others', 'all', 'base-sha', 'merge-sha')

    def test_dispatch_passes_ref_and_default_branch(self):
        compare, dispatch, _, _ = self.run_main('workflow_dispatch', {'repository': {'default_branch': 'main'}})
        dispatch.assert_called_once_with('others', 'changed', 'refs/heads/topic', 'main')
        compare.assert_not_called()

    def test_has_jobs_output_follows_the_selection(self):
        job = {'system': 'x86_64-linux', 'runner': 'ubuntu-24.04', 'package': 'p'}
        _, _, printed, output = self.run_main('push', {'before': 'a', 'after': 'b'}, selection={'include': [job]})
        self.assertEqual(printed, {'include': [job]})
        self.assertEqual(output, 'has_jobs=true\n')
        _, _, printed, output = self.run_main('push', {'before': 'a', 'after': 'b'})
        self.assertEqual(printed, {'include': []})
        self.assertEqual(output, 'has_jobs=false\n')

    def test_unsupported_event_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Unsupported event'):
            self.run_main('schedule', {})


class SelectionTests(unittest.TestCase):
    def test_only_changed_added_and_failed_packages_build(self):
        names = ['unchanged', 'changed', 'added', 'broken-before', 'broken-after']
        jobs = [{'system': 'x86_64-linux', 'package': name} for name in names]
        before = dict(zip([('x86_64-linux', n) for n in names], ['same', 'old', 'absent', None, 'old']))
        after = dict(zip(before, ['same', 'new', 'new', 'new', None]))
        self.assertEqual([j['package'] for j in changed.select(jobs, before, after)], names[1:])
        self.assertEqual(changed.select(jobs[:1], before, after), [])

    def test_metadata_fast_path_excludes_recipe_and_lock_changes(self):
        self.assertTrue(changed.metadata_only(['README.md', 'ci/matrix.py', 'nix/platforms.json']))
        for path in ['flake.lock', 'flake.nix', 'nix/package-set.nix', 'pkgs/handy/default.nix', 'pkgs/handy/README.md']:
            self.assertFalse(changed.metadata_only([path]))

    def test_real_nix_identity_missing_and_broken_attributes(self):
        with tempfile.TemporaryDirectory() as directory:
            tree = Path(directory)
            (tree / 'flake.nix').write_text('''{
              outputs = {self}: { packages.x86_64-linux = {
                stable = builtins.derivation { name = "stable"; system = "x86_64-linux"; builder = "/bin/sh"; };
                broken = throw "intentional fixture failure";
              }; };
            }''')
            jobs = [{'system': 'x86_64-linux', 'package': n} for n in ['stable', 'broken', 'missing']]
            jobs.append({'system': 'aarch64-linux', 'package': 'missing'})
            result = changed.evaluate(tree, jobs, 'packages')
            self.assertTrue(result[('x86_64-linux', 'stable')].endswith('.drv'))
            self.assertIsNone(result[('x86_64-linux', 'broken')])
            self.assertEqual(result[('x86_64-linux', 'missing')], 'absent')
            self.assertEqual(result[('aarch64-linux', 'missing')], 'absent')
            self.assertEqual(changed.select(jobs[:1], result, result), [])
            source = tree / 'flake.nix'
            source.write_text(source.read_text().replace('name = "stable";', 'name = "updated";'))
            after = changed.evaluate(tree, jobs, 'packages')
            self.assertEqual(changed.select(jobs[:1], result, after), jobs[:1])




class WorkflowWiringTests(unittest.TestCase):
    def test_dispatch_defaults_to_branch_changes_and_events_keep_their_selection(self):
        for family in ('darwin', 'others'):
            text = (ROOT / '.github/workflows' / (family + '-actions.yml')).read_text()
            self.assertIn('        default: changed\n', text)
            # Push and PR runs have no inputs; they must not receive the dispatch sentinel.
            self.assertIn("SELECTED_PACKAGE: ${{ inputs.package || 'all' }}", text)
            self.assertIn('python3 ci/test-retain-build-outputs.py', text)
        others = (ROOT / '.github/workflows/others-actions.yml').read_text()
        self.assertIn('run: python3 ci/test-caddy-source.py', others)

if __name__ == '__main__':
    unittest.main()
