# Vendored Redlib update review

The outer package updater must treat Redlib as a vendored compatibility candidate,
not run a source-replacing nix-update against `pkgs/redlib`. Its named MAIN FEEDS,
cookie settings and other local changes are the maintained product.

```sh
python3 scripts/update-redlib-vendor.py --check
python3 scripts/update-redlib-vendor.py --candidate /tmp/redlib-review --build
```

Check mode resolves official upstream HEAD to a full commit and compares it with
`vendor/redlib/VENDOR.md`. It changes no repository files. `--ref refs/tags/vX.Y.Z`
selects an explicit official tag. Candidate mode refuses an existing output path,
clones official upstream, commits the complete local vendor tree (including
upstream file deletions), and performs a three-way merge of the pinned target.
All source customization is preserved as `local-customizations.patch`; upstream
changes, merge diagnostics and a JSON result remain in the output directory.
Conflicts produce nonzero status and are left for review; they never overwrite
the deployed vendor tree. Dependency regeneration or package-build failure also
returns nonzero. Without `--build`, validation is explicitly marked skipped.

`--build` probes only the Cargo dependency derivation with a deliberately invalid
hash, writes the returned hash into candidate `package.nix`, then builds that
candidate with existing nixpkgs and existing package test exclusions. Select a
supported builder with `--system` (default `x86_64-linux`). Nix needs the normal
configured remote/local build support for that system. No system switch, service
restart, deployment, commit or push is performed.

Review the merged source, `upstream.patch`, `local-customizations.patch`, the new
Cargo.lock, named-feeds tests and browser behavior. Then deliberately import the
reviewed source (excluding `.git`) and update `pkgs/redlib/default.nix` version,
base comment and Cargo hash. Keep `VENDOR.md`'s full base commit current. Rebuild
the package after import. Preference serialization compatibility is a manual
review requirement: our package skips upstream legacy preference fixtures because
the feeds field changes the bincode layout; old settings may need re-export.

The upstream `scripts/update_oauth_resources.sh` and `update_hls_js.sh` fetch
mutable external assets and are **not** automatically invoked. Their outputs must
be separately reviewed and committed to the candidate when needed; the exact
vendored files then become reproducible inputs. Running arbitrary upstream
maintenance scripts is not a substitute for a reviewed source merge.

## Runtime plugin coverage

Jellyfin plugins are mutable runtime state, outside `flake.lock` and nix-update.
Jellarr declares repositories and install-only plugin names; it does not prove
refreshing plugins. [Jellyfin's task documentation](https://jellyfin.org/docs/general/server/tasks/)
identifies the server's Update Plugins task. Validate `/ScheduledTasks`,
`/Plugins` and `/System/Info` via authenticated read-only API calls; keep keys in
the remote process and print only task state, triggers, versions, statuses and
pending-restart state. A successful package build provides no runtime evidence.

Read-only Terra evidence on 2026-09-30: Jellyfin 12.1.0; Update Plugins idle with
startup and 24-hour interval triggers; latest completion 2026-09-29 18:16:55 UTC;
all 12 installed plugins active and no pending restart. Active third-party plugin
versions were Intro Skipper 12.0.4.0, Streamyfin 0.68.1.0, Air Times 0.0.2.0,
Merge Versions 12.0.1.0, InPlayerEpisodePreview 2.4.0.3 and TheTVDB 24.0.0.0.
This proves the updater runs and installed plugins are active; it does not prove
third-party upstream manifests are complete or newer compatible versions absent.
Intro Skipper and Streamyfin dashboard setup remains a manual exception as stated
in `machines/terra/services/jellyfin/jellarr.nix`.

Official Redlib comparison on 2026-09-30: upstream HEAD and documented vendor base
both resolved to `a4d36e954cf1bd64f209cd8868c5a29edc81b374`. No source upgrade was
available. Source: <https://github.com/redlib-org/redlib>.
