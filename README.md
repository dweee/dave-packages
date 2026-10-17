# dave-packages

Portable Nix packages and patches for Apple Silicon macOS, x86 Linux and ARM Linux.

## Use

```sh
nix build .#spank
nix build .#packages.aarch64-darwin.paneru
nix build .#packages.x86_64-linux.infrared
nix eval --json .#packages.aarch64-linux --apply builtins.attrNames
```

Use `overlays.default` with the pinned nixpkgs to consume the packages from
NixOS, nix-darwin or Home Manager. The current pin supports Apple Silicon Darwin
and both Linux architectures; Intel Darwin is not exposed.

## T3 Code

`t3code-nightly` and `t3code-server-nightly` share a source-build override with
the Cursor Max Mode backport. Both are built by the native catalog runners.
See [the package notes](pkgs/t3code/README.md) for the upstream fix, version,
context-tier behavior and NixOS/nix-darwin/Home Manager consumption.

## Package ownership

The catalog owns portable recipes and small patches. Application source and
larger changes live in the Paneru, Tabrix, Rekordbox MCP and SchildiChat Revenge
forks. `nix/forks.json` and `flake.lock` record their exact source revisions.
Each application fork owns its build workflows; the catalog excludes those
packages from its CI matrix. Fork inputs use public GitHub sources.

## CI and binary cache

`.github/workflows/darwin-actions.yml` builds native Apple Silicon packages;
`.github/workflows/others-actions.yml` builds native x86 and ARM Linux packages.
Pushes, pull requests and manual dispatch build the selected native packages.
The repository gate is `DAVE_PACKAGES_CI_ENABLED=true`.

Select one package or `all`. `ci/matrix.py` reads `nix/platforms.json` and excludes
fork-owned outputs. Builders use the pinned Nix Quick Install action. Optional
Attic publication uses a separate Linux publisher and cache-scoped credentials;
see [ci/ATTIC.md](ci/ATTIC.md) for configuration.

## Platform inventory

| Package | Apple Silicon macOS | x86 Linux | ARM Linux |
| --- | --- | --- | --- |
| apfs-dedupe | yes | - | - |
| applesauce | yes | - | - |
| bitwig-theme-editor | yes | yes | yes |
| byparr | - | yes | yes |
| cartographer | - | yes | - |
| codexbar-cli | - | yes | yes |
| codexbar-plasmoid | - | yes | yes |
| cursaves | yes | yes | yes |
| eel-extension | yes | yes | yes |
| gdb-mcp | yes | yes | yes |
| ghidra-mcp | yes | yes | yes |
| infrared | yes | yes | yes |
| lg-webos-dashboard | yes | yes | yes |
| matter-linux-ota-provider | - | yes | yes |
| mermaid-filter | yes | yes | yes |
| modcheck | - | yes | yes |
| openghub | - | yes | yes |
| paceman-tracker | - | yes | yes |
| paneru | yes | - | - |
| paneru-lua | yes | - | - |
| photogimp | - | yes | yes |
| prowlarr-mcp | yes | yes | yes |
| pyrekordbox | yes | yes | yes |
| rekordbox-mcp | yes | - | - |
| sable-desktop | - | yes | yes |
| schildi-revenge | yes | yes | yes |
| slopbro | yes | yes | yes |
| slskd-mcp | yes | yes | yes |
| spank | yes | - | - |
| tabrix | yes | yes | yes |
| tabrix-extension | yes | yes | yes |
| t3code-nightly | yes | yes | yes |
| t3code-server-nightly | yes | yes | yes |
| trawl | - | yes | - |
| waywall | - | yes | yes |
| wheelwizard | yes | yes | yes |
| yaas | - | yes | - |

## Licenses

See [NOTICE](NOTICE). Recipes retain upstream source locations and license
metadata; application forks retain their own licenses and author history.

Every successful build retains a downloadable Nix closure archive for one day,
independently of Attic publication.
