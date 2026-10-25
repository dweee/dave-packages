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

## Reverse engineering

`kuna` supplies the standalone source-built CLI and agent skill. `rea` supplies
plain REA 6.7.0 and its generated skill; `ghidra-kuna` supplies a separate Ghidra
installation with Kuna's native core. `rea-kuna` combines these for stdio MCP
use and supports both headless Ghidra and the direct Kuna provider.

```sh
nix shell .#kuna .#rea-kuna
nix build .#checks.x86_64-linux.kuna-ghidra-headless
```

Install `kuna` and `rea-kuna` for agent use; the wrapper retains Ghidra without
changing an ordinary GUI command. See [the launcher notes](pkgs/rea-kuna/README.md)
for client registration, complete skill directories, environment overrides and
backend limitations. Package installation does not edit client configuration.
Raw REA's install check covers MCP initialization, tool discovery and native PTY
creation. The composed headless check also compiles and executes recovered C.

## T3 Code

`t3code-nightly` and `t3code-server-nightly` share a source-build override with
the Cursor Max Mode backport. Both are built by the native catalog runners.
See [the package notes](pkgs/t3code/README.md) for the upstream fix, version,
context-tier behavior and NixOS/nix-darwin/Home Manager consumption.

On Darwin the overlay's `spotify` excludes `favicon.ico` from LLVM stripping:
the strip tool mistakes its ICO header for COFF and corrupts/expands the icon.
Spicetify inherits the exclusion. This unfree package is exposed through
`cacheOnlyPackages.aarch64-darwin.spotify`, outside public runtime exports.

## Package ownership

The catalog owns portable recipes and small patches. Application source and
larger changes live in the Kopuz, Paneru, Tabrix, Rekordbox MCP and SchildiChat Revenge
forks, including the Kuna packaging fork. `nix/forks.json` and `flake.lock` record their exact source revisions.
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
| ghidra-kuna | yes | yes | yes |
| infrared | yes | yes | yes |
| kuna | yes | yes | yes |
| kopuz | yes | yes | yes |
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
| rea | yes | yes | yes |
| rea-kuna | yes | yes | yes |
| rekordbox-mcp | yes | - | - |
| sable-desktop | - | yes | yes |
| schildi-revenge | yes | yes | yes |
| slopbro | yes | yes | yes |
| slskd-mcp | yes | yes | yes |
| spank | yes | - | - |
| tabrix | yes | yes | yes |
| tabrix-extension | yes | yes | yes |
| tokscale | yes | yes | yes |
| trawl | - | yes | - |
| waywall | - | yes | yes |
| wheelwizard | yes | yes | yes |
| yaas | - | yes | - |

## Licenses

See [NOTICE](NOTICE). Recipes retain upstream source locations and license
metadata; application forks retain their own licenses and author history.

Every successful build retains a downloadable Nix closure archive for one day,
independently of Attic publication.
