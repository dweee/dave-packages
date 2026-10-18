# TPSBar for Pumpkin

Upstream: https://github.com/PingGai/Pumpkin-TPSBar

Pinned at `ae4271716bce76519944681c4b105c16f34f8643` and rebuilt against the
`pumpkin-nixpkgs` input's Pumpkin 0.2 source and exact WIT interfaces.
`pumpkin-0.2.patch` adapts plugin lifecycle hooks with a mutex for the scheduler
task ID and uses the consuming command/text builder API.

```sh
nix build .#pumpkin-tpsbar
```

Install `tpsbar.wasm` into the Pumpkin plugins directory. It is a portable WASI
component for x86_64 and ARM server hosts and needs Pumpkin's host imports.
It cannot run as a standalone binary or Darwin service.

Review and approve the component's `fs.read.data` and `fs.write.data` permissions.
Player preferences live under `plugins/data/tpsbar` in the persistent server
directory. Configure refresh interval, fallback language and command permission
level for the deployment. `/tpsbar` toggles the display; `by mspt`, `by tps` and
`by ping` select the progress metric.
