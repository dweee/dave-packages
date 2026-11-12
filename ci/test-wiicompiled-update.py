#!/usr/bin/env python3
"""Owner identity, immutable source and input-only update regressions."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('wii_update', ROOT / 'pkgs/wiicompiled/update.py')
u = importlib.util.module_from_spec(spec)
spec.loader.exec_module(u)


class WiiUpdate(unittest.TestCase):
    def setUp(self):
        self.lock = json.loads((ROOT / 'flake.lock').read_text())
        self.current = u.inputs.root_node(self.lock, 'wiicompiled')['locked']
        self.snapshot = {'version': 1, 'locked': copy.deepcopy(self.current)}

    def test_no_change_apply_never_writes_or_runs_nix(self):
        with patch.object(u.inputs, 'run', side_effect=AssertionError('unexpected mutation')):
            self.assertFalse(u.update(self.snapshot, True)['changed'])

    def test_discovery_uses_maintained_canonical_policy(self):
        with patch.object(u.inputs, 'run', return_value=json.dumps({'locked': self.current})) as run:
            self.assertEqual(u.discover(), self.snapshot)
        self.assertIn(u.SOURCE, run.call_args.args)
        self.assertIn('--refresh', run.call_args.args)

    def test_private_sources_branches_and_missing_submodules_fail_closed(self):
        for key, value in [('url', 'https://git.monke.fail/d/wiicompiled.git'),
                           ('ref', 'main'), ('submodules', False), ('rev', 'flakey'),
                           ('type', 'github'), ('narHash', 'unknown')]:
            snapshot = copy.deepcopy(self.snapshot)
            snapshot['locked'][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                u.update(snapshot, True)

    def test_same_revision_different_hash_rejected(self):
        self.snapshot['locked']['narHash'] = 'sha256-' + 'A' * 43 + '='
        with self.assertRaisesRegex(ValueError, 'hash changed'):
            u.update(self.snapshot, True)

    def test_update_requires_clean_checkout(self):
        self.snapshot['locked']['rev'] = 'a' * 40
        with patch.object(u.inputs, 'run', return_value=' M source.nix'), self.assertRaisesRegex(ValueError, 'clean'):
            u.update(self.snapshot, True)

    def test_input_handler_inventory_and_public_matrix(self):
        policy = json.loads((ROOT / 'ci/package-updates.json').read_text())
        self.assertEqual(policy['inputHandlers']['wiicompiled']['script'], 'pkgs/wiicompiled/update.py')
        platforms = json.loads((ROOT / 'nix/platforms.json').read_text())
        for system, packages in platforms.items():
            names = {n for n in packages if n.startswith('wiicompiled')}
            expected = {'wiicompiled-translator', 'wiicompiled-native-prebuilt', 'wiicompiled-setup'}
            if system.endswith('linux'):
                expected.add('wiicompiled-setup-unwrapped')
            self.assertEqual(names, expected)
        self.assertFalse((ROOT / 'pkgs/wiicompiled/source').exists())
        self.assertIn('inputs.wiicompiled + "/nix/overlay.nix"', (ROOT / 'nix/package-set.nix').read_text())


if __name__ == '__main__':
    unittest.main()
