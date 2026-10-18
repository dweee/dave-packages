# TPSBar for braco

Upstream: https://github.com/PingGai/Pumpkin-TPSBar

Pinned at ae4271716bce76519944681c4b105c16f34f8643 and rebuilt against the
`pumpkin-nixpkgs` input’s Pumpkin 0.2 source, including its exact WIT interfaces. Upstream pins
a different API revision. `pumpkin-0.2.patch` adapts immutable plugin lifecycle hooks with a mutex for the
scheduler task ID and uses the consuming command/text builder API.

Build with `nix build ./pkgs/pumpkin-tpsbar`. The package is a portable WASI
component built on x86_64 Linux; it also runs on braco’s ARM server. It needs
Pumpkin’s host imports and cannot run as a standalone binary or Darwin service.

On NixOS, import the package using the same nixpkgs, pumpkin-nixpkgs and rust-overlay inputs as
`flake.nix`, then install `tpsbar.wasm` into the Pumpkin plugins directory.
`machines/braco/minecraft.nix` manages the component, config and exact-hash
approval for only `fs.read.data` and `fs.write.data`. Player preferences stay in
the persisted `plugins/data/tpsbar` directory. The old directory is copied once
when adopting Pumpkin 0.2. Unknown plugin permissions are unaffected.

Braco uses a one-second refresh, English fallback, and permission level zero so
every player can run `/tpsbar`. It starts hidden for each player; toggles persist.
`/tpsbar by mspt`, `/tpsbar by tps` and `/tpsbar by ping` select the progress metric.

Validation: source builds against the pinned API and loads in an isolated copy
of the same Pumpkin server. Live rollout uses the existing scoped runtime
pre-start override; the next normal NixOS deployment adopts the declaration.
