#!/usr/bin/env python3
"""Exercise selection and real Nix evaluation without downloading inputs."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('changed', Path(__file__).with_name('changed-matrix.py'))
changed = importlib.util.module_from_spec(spec)
spec.loader.exec_module(changed)


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


if __name__ == '__main__':
    unittest.main()
