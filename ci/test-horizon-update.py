#!/usr/bin/env python3
import base64
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('horizon_update', ROOT / 'pkgs/horizon/update.py')
u = importlib.util.module_from_spec(spec)
spec.loader.exec_module(u)
pubspec = importlib.util.spec_from_file_location('horizon_publisher', ROOT / 'ci/package-updates.py')
pub = importlib.util.module_from_spec(pubspec)
pubspec.loader.exec_module(pub)
HASH = 'sha256-' + 'A' * 43 + '='


class Horizon(unittest.TestCase):
    def fixtures(self):
        releases = [
            {'tag_name': 'launcher@1.2.3', 'draft': False, 'prerelease': False},
            {'tag_name': 'nightly-2026-11-07', 'name': 'Nightly 2026-11-07', 'draft': False,
             'body': 'Source: commit ' + 'b' * 40},
            {'tag_name': 'nightly', 'name': 'Nightly 2026-11-08', 'draft': False,
             'body': 'Source: commit ' + 'c' * 40},
        ]
        def commit(repo, ref):
            return ('e' * 40 if repo == u.MIXINS else 'a' * 40 if ref.startswith('launcher@') else 'd' * 40, '2026-11-12')
        return releases, commit

    def test_real_resolver_apply_all_channels_then_frozen_noop(self):
        releases, commit = self.fixtures()
        with patch.object(u, 'releases', return_value=releases), patch.object(u, 'commit', side_effect=commit), \
             patch.object(u, 'asset_pins', return_value={}), patch.object(u, 'mixins_rev', return_value='e' * 40) as mixins, \
             patch.object(u, 'source_hash', return_value=HASH), patch.object(u, 'cargo_hash', return_value=HASH) as cargo:
            new, changes = u.resolve({}, ['stable', 'unstable', 'head'], 'x86_64-linux', False)
            self.assertTrue(changes)
            self.assertEqual(new['game']['stable']['rev'], 'b' * 40)
            self.assertEqual(new['game']['unstable']['rev'], 'c' * 40)
            self.assertEqual(new['game']['head']['rev'], 'd' * 40)
            self.assertEqual(new['launcher']['stable']['rev'], 'a' * 40)
            self.assertEqual(new['mixins']['rev'], 'e' * 40)
            cargo.reset_mock()
            again, changes = u.resolve(new, ['stable', 'unstable', 'head'], 'x86_64-linux', False)
            self.assertEqual(again, new)
            self.assertEqual(changes, [])
            cargo.assert_not_called()
            self.assertEqual(mixins.call_args.args, ('a' * 40,))

    def test_check_uses_selected_new_launcher_for_mixins(self):
        releases, commit = self.fixtures()
        old = {'launcher': {'stable': {'rev': 'f' * 40}}}
        with patch.object(u, 'releases', return_value=releases), patch.object(u, 'commit', side_effect=commit), \
             patch.object(u, 'asset_pins', return_value={}), patch.object(u, 'mixins_rev', return_value='e' * 40) as mixins, \
             patch.object(u, 'source_hash', side_effect=AssertionError('check must not hash')):
            u.resolve(old, ['stable'], 'x86_64-linux', True)
            mixins.assert_called_once_with('a' * 40)
            self.assertEqual(old['launcher']['stable']['rev'], 'f' * 40)

    def test_snapshot_replay_never_falls_back_to_network(self):
        url = 'https://api.github.com/repos/' + u.REPO + '/commits/main'
        with patch.object(u, 'REPLAY', {url: base64.b64encode(b'{"sha":"frozen"}').decode()}), \
             patch.object(u.urllib.request, 'urlopen', side_effect=AssertionError('network forbidden')):
            self.assertEqual(u.fetch(url), {'sha': 'frozen'})
            with self.assertRaises(ValueError):
                u.fetch(url + '-missing')

    def test_cargo_hash_uses_git_filtered_source(self):
        mismatch = subprocess.CompletedProcess([], 1, '', 'got: ' + HASH)
        with patch.object(u, 'nix', return_value=mismatch) as nix:
            self.assertEqual(u.cargo_hash('game', {'rev': 'a' * 40}, 'x86_64-linux'), HASH)
        expression = nix.call_args.args[-1]
        self.assertIn('git+file://', expression)
        self.assertNotIn('getFlake "path:', expression)

    def test_binary_assets_keep_only_published_supported_pairs(self):
        asset = {'name': 'SHA256SUMS', 'browser_download_url': 'https://example.invalid/sums'}
        with patch.object(u, 'fetch', return_value=('00' * 32 + '  horizon-linux-x86_64.tar.gz\n').encode()):
            pins = u.asset_pins({'tag_name': 'nightly-2026-11-07', 'assets': [asset]}, u.GAME_ASSETS)
        self.assertEqual(set(pins), {'x86_64-linux'})
        self.assertNotIn('aarch64-linux', pins)

    def test_publisher_accepts_data_and_rejects_injected_sources(self):
        content = json.loads((ROOT / 'pkgs/horizon/sources.json').read_text())
        self.assertEqual(pub.normalized('pkgs/horizon/sources.json', json.dumps(content).encode()), '<generated Horizon pins>')
        for change in ['unexpected', 'private-url', 'unsupported-platform']:
            bad = copy.deepcopy(content)
            if change == 'unexpected': bad['script'] = 'executable'
            elif change == 'private-url': bad['bin']['stable']['game']['x86_64-linux']['url'] = 'https://git.monke.fail/private'
            else: bad['bin']['stable']['game']['aarch64-linux'] = bad['bin']['stable']['game']['x86_64-linux']
            with self.subTest(change=change), self.assertRaises(ValueError):
                pub.normalized('pkgs/horizon/sources.json', json.dumps(bad).encode())

    def test_workflows_reuse_guarded_publisher_without_legacy_closures(self):
        caller = (ROOT / '.github/workflows/horizon-updates.yml').read_text()
        workflow = (ROOT / '.github/workflows/package-updates.yml').read_text()
        self.assertIn('uses: ./.github/workflows/package-updates.yml', caller)
        self.assertNotIn('gh pr close', caller)
        self.assertNotIn('automation/horizon-', caller)
        self.assertIn('workflow_call:', workflow)
        self.assertIn('ci/package-updates.py publish', workflow)
        self.assertIn('ci/public-closure.py', workflow)
        self.assertIn('legacyPackages.$system.horizonPackages.packages', workflow)


if __name__ == '__main__': unittest.main()
