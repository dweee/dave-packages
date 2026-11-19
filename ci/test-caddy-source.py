#!/usr/bin/env python3
"""Exercise Caddy's source-FOD contract without fetching or compiling outputs."""
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
# shallow=1: CI build jobs check out one commit, which has no revCount.
FLAKE = 'git+file://' + str(ROOT) + '?shallow=1'


def evaluate(body):
    return subprocess.run(['nix', 'eval', '--impure', '--json', '--no-update-lock-file',
                           '--no-write-lock-file', '--expr',
                           'let f = builtins.getFlake ' + json.dumps(FLAKE) + '; in ' + body],
                          text=True, capture_output=True)


class CaddySource(unittest.TestCase):
    def test_native_exports_preserve_toolchain_and_install_checks(self):
        # Run this contract on its native runner; do not cross-evaluate fleets.
        system = subprocess.check_output(
            ['nix', 'eval', '--impure', '--raw', '--expr', 'builtins.currentSystem'], text=True)
        for system in [system]:
            with self.subTest(system=system):
                result = evaluate('''let
                  p=f.packages.%s.caddy-custom;
                  base=f.inputs.nixpkgs.legacyPackages.%s.caddy;
                in {
                  go=p.go.version; baseGo=base.go.version;
                  checks=p.doInstallCheck;
                  manualPin=builtins.match ".*go get github.com/go-json-experiment/json@.*" p.src.buildPhase != null;
                  vendorSteps=builtins.length (f.inputs.nixpkgs.lib.splitString "go mod vendor" p.src.buildPhase) - 1;
                }''' % (system, system))
                self.assertEqual(result.returncode, 0, result.stderr)
                result = json.loads(result.stdout)
                self.assertTrue(result['checks'])
                self.assertEqual(result['go'], result['baseGo'])
                self.assertFalse(result['manualPin'])
                self.assertEqual(result['vendorSteps'], 1)


    def test_tailscale_plugin_is_new_enough_for_go_1_27_netmaps(self):
        # caddy-tailscale before 2026-08-26 pins tailscale.com v1.90.9, whose
        # tailcfg.SSHAction json `format:nano` tag Go 1.27 rejects: every tsnet
        # node then fails PollNetMap and Tailscale-bound vhosts go dark.
        system = subprocess.check_output(
            ['nix', 'eval', '--impure', '--raw', '--expr', 'builtins.currentSystem'], text=True)
        result = evaluate('''let p=f.packages.%s.caddy-custom; in
          builtins.match ".*github.com/tailscale/caddy-tailscale@v0.0.0-([0-9]{14})-[0-9a-f]{12}.*" p.src.buildPhase''' % system)
        self.assertEqual(result.returncode, 0, result.stderr)
        stamp = json.loads(result.stdout)
        self.assertIsNotNone(stamp, 'caddy-tailscale pseudo-version not found in the source build phase')
        self.assertGreaterEqual(stamp[0], '20260826180304')

if __name__ == '__main__': unittest.main()
