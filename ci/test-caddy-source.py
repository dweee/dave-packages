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
    def test_immutable_json_fix_preserves_toolchain_and_install_checks(self):
        result = evaluate('''let p=f.packages.x86_64-linux.caddy-custom; in {
          go=p.go.version; baseGo=f.inputs.nixpkgs.legacyPackages.x86_64-linux.caddy.go.version; checks=p.doInstallCheck;
          pinned=builtins.match ".*go get github.com/go-json-experiment/json@[0-9a-f]{40} && go mod vendor.*" p.src.buildPhase != null;
          vendorSteps=builtins.length (f.inputs.nixpkgs.lib.splitString "go mod vendor" p.src.buildPhase) - 1;
        }''')
        self.assertEqual(result.returncode, 0, result.stderr)
        result = json.loads(result.stdout)
        self.assertTrue(result['checks'])
        self.assertEqual(result['go'], result['baseGo'])
        self.assertTrue(result['pinned'])
        self.assertEqual(result['vendorSteps'], 1)

    def test_upstream_builder_drift_fails_instead_of_omitting_transitive_pin(self):
        result = evaluate('''let pkgs = import f.inputs.nixpkgs {
          system="x86_64-linux";
          overlays=[(final: prev: { caddy = prev.caddy // {
            withPlugins = args: (prev.caddy.withPlugins args).overrideAttrs (old: {
              src = old.src.overrideAttrs { buildPhase="upstream changed the vendoring phase"; };
            });
          }; }) f.overlays.default];
        }; in pkgs.caddy-custom.src.drvPath''')
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue('assertion' in result.stderr or 'not equal' in result.stderr, result.stderr)


if __name__ == '__main__': unittest.main()
