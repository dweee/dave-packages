# Refreshing the Caddy plugin source

`nix/package-set.nix` owns the seven exact plugin specifications and the recursive
source hash. The locked nixpkgs supplies Caddy, its Go toolchain and the xcaddy
fetcher. A nixpkgs change can alter all three even when the plugin list is unchanged.
The `fixedOutputHashes` inventory in `ci/tracking-inputs.json` identifies this
additional review/build obligation; a successful no-build input check is not a
source-hash or native build proof.

The source currently pins `go-json-experiment/json` to upstream merge commit
`dc5f05c800f19f9b0114acbbd240674f16b2762f` ([upstream PR203](https://github.com/go-json-experiment/json/pull/203)).
The older shim brought by Tailscale aliases `SkipFunc` and `DiscardUnknownMembers`,
which were removed from Go's JSON-v2 API. This changes that one transitive module,
keeps JSON-v2 enabled, and leaves Caddy, Go and all plugin specifications intact.
The recipe fails closed if the upstream vendoring step changes instead of silently
omitting this pin.

For a refresh, keep the already selected flake inputs and plugin versions fixed:

1. Instantiate the exact `packages.<system>.caddy-custom.src` FOD using the
   repository's Git-filtered flake. Use a permitted evaluator and trusted native
   builder; on constrained machines copy the derivation to the builder and inspect
   metadata there rather than importing its vendor or native closure.
2. Regenerate the source through Nix with a fake hash and substitution disabled
   **for that source probe only**. Record the reported actual hash. No hash is
   accepted merely because another CI run printed it.
3. Build the source again with the measured hash. Inspect its complete `go.mod`,
   `go.sum` and `vendor/modules.txt`: Caddy and all seven plugin versions must match,
   the exact JSON compatibility revision must resolve to its expected pseudo-version,
   and every replacement or additional transitive change must be explained. Keep
   those records and the source NAR identity as review evidence.
4. Update only the recipe's measured hash metadata. Run
   `python3 ci/test-caddy-source.py`, then build the exact native `caddy-custom`.
   Keep its inherited install/version/plugin checks enabled. Verify `caddy version`,
   `caddy build-info`, and `caddy list-modules --packages --versions` from that output.
5. Check repeatability through a Nix source rebuild/check and confirm another
   update would leave the recipe unchanged. Inspect the affected Linux package and
   check outputs with `ci/public-closure.py` before publishing. Normal native CI,
   independent review and cache/channel gates still apply.

Do not move a plugin to a floating ref, substitute an older Caddy/Go toolchain,
disable JSON-v2, bypass an install check, or run an unrestricted flake update to
make a source hash match. A changed graph requires a new measured source proof.
