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

On Linux the build also compiles node-pty from source and removes its
prebuilt binaries. node-pty's install script skips `node-gyp` whenever a
matching prebuild exists, and the upstream `pty.node` has no RUNPATH for
`libstdc++.so.6` on NixOS, so the server failed with `NodePtyModuleLoadError`.
`postInstall` loads the installed module to catch a regression at build time.

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
On macOS, `darwin.nix` builds a native `T3 Code.app` from the pinned Electron
runtime, with executable name `T3 Code`, bundle ID `com.t3tools.t3code` and
T3's icon. A script-only app that launches the shared `Electron.app` loses its
system identity even when T3 sets its Dock icon. The native bundle is signed
ad hoc and verified during the build; it is not upstream signed or notarized.
Its bootstrap points Electron at the patched application root in the Nix store,
so Home Manager `copyApps` cannot relocate the backend away from its pnpm
dependency tree. It also disables self-updates and selects the resource monitor.
The native bundle retains its name, icon and bundle ID after copying.
The existing `t3code` safeStorage name remains independent of the bundle name.

From an interactive macOS desktop, check the installed copy behavior with
`python3 pkgs/t3code/test-darwin-launch.py /nix/store/...-t3code-darwin-...`.
This reproduces Home Manager's rsync flags, verifies the copied signature, and
requires a stable backend HTTP response and main window using a disposable T3
home. It does not access the user's T3 database.

Remove the Max Mode backport once T3 or the Cursor SDK supplies the fix,
after checking long and standard context requests.
