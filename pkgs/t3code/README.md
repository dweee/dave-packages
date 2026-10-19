# T3 Code Cursor Max Mode backport

`t3code-nightly` and `t3code-server-nightly` override the source packages from
LisaScheers/t3-code-nix, pinned to T3 Code `0.1.1-nightly.20261017.3272`.
The desktop and headless launchers share one patched server build. Linux x86,
Linux ARM and Apple Silicon macOS use their native catalog runners.

The patch is the unmodified diff from [T3 PR #18700](https://github.com/pingdotgg/t3code/pull/18700),
head `f50aad2422`, credited there to Matthew Feroz and emcee6798. It fixes
[issue #15788](https://github.com/pingdotgg/t3code/issues/15788): the Cursor SDK
omits `RequestedModel.maxMode`, so Grok's advertised 500K selection fails and
other long-context models can silently use their standard window.

Only explicit context tiers above 300,000 tokens turn on Max Mode. Standard
tiers, existing Max Mode values, unrelated messages and caller objects remain
unchanged. Cursor bills Max Mode according to the account's plan. The build
runs the upstream offline SDK request/serialization tests; these verify the
real SDK request path without credentials or model calls. An authenticated
turn and effective context-window measurement are separate runtime checks.

Consume the catalog's exact outputs rather than rebuilding against a host's
different nixpkgs pin:

```nix
# NixOS, nix-darwin or Home Manager package list
environment.systemPackages = [
  inputs.dave-packages.packages.${pkgs.stdenv.hostPlatform.system}.t3code-nightly
];
```

Use `home.packages` for a standalone Home Manager configuration. A headless
T3 service can set its package to `t3code-server-nightly` from the same set.
The source build uses Nix's Electron launcher on macOS instead of rewriting
the official application's signed bundle. Remove the backport once T3 or the
Cursor SDK supplies the fix, after checking long and standard context requests.
