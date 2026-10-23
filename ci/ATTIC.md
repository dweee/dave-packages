# Private Flakey cache publication

The catalog and five application forks publish package closures to **https://attic.monke.fail/flakey**, a private Attic cache. Its signing
key is `flakey:mDx4DiNpH5w1Pl8OAKFFWq1ZsypA9lbaFKNiRWhqYE8=`.
There is one destination. Publisher helpers reject any other endpoint or cache.

## Repository setup

An Attic administrator issues a dedicated token with only pull and push on
`flakey`, valid for at most 90 days:

```sh
umask 077
token_file=/absolute/path/to/github-flakey-token
atticadm make-token --sub github-packages --validity 90d --pull flakey --push flakey > "$token_file"
```

Save the token privately to a file; do not paste it into commands, logs or Git.
On a machine with authenticated GitHub CLI, set the existing secret and enable
variables. This reads the token directly from the file without printing it:

```sh
token_file=/absolute/path/to/github-flakey-token
for repo in dave-packages kopuz paneru tabrix schildi-revenge rekordbox-mcp; do
  gh secret set ATTIC_TOKEN --repo "dweee/$repo" < "$token_file"
  gh variable set ATTIC_ENDPOINT --repo "dweee/$repo" --body https://attic.monke.fail
  gh variable set ATTIC_CACHE --repo "dweee/$repo" --body flakey
  gh variable set ATTIC_SUBSTITUTER --repo "dweee/$repo" --body https://attic.monke.fail/flakey
  gh variable set ATTIC_PUBLIC_KEY --repo "dweee/$repo" --body 'flakey:mDx4DiNpH5w1Pl8OAKFFWq1ZsypA9lbaFKNiRWhqYE8='
  gh variable set ATTIC_PUSH_ENABLED --repo "dweee/$repo" --body true
  if test "$repo" = dave-packages; then
    gh variable set DAVE_PACKAGES_CI_ENABLED --repo "dweee/$repo" --body true
  else
    gh variable set DAVE_FORK_CI_ENABLED --repo "dweee/$repo" --body true
    gh variable set GUARDED_UPSTREAM_SYNC_ENABLED --repo "dweee/$repo" --body false
  fi
done
```

Endpoint/cache/key variables are also set for compatibility with existing repo
administration. The native publisher and read helper pin the values above.
Rotate the secret before its token expires. No host credential is reused.

## Trusted reads and writes

Only a push or manual dispatch on the repository's default branch receives
`ATTIC_TOKEN`. The read helper creates `$RUNNER_TEMP/flakey-attic.netrc` with mode
0600 and configures Nix's `netrc-file`; the token does not enter Nix expressions,
derivations, the store or artifacts. The netrc authenticates to `attic.monke.fail`.
Native catalog jobs remove this credential and its managed Nix configuration
before exporting build data, including when an earlier build step fails.

The catalog optionally permits a separate **pull-only** `ATTIC_PULL_TOKEN` for
one explicitly reviewed owner PR head. All three conditions must hold: the PR
head belongs to this repository, the workflow actor is the repository owner, and
its exact head commit equals the nonempty `ATTIC_APPROVED_PR_SHA` variable.
The helper independently checks the GitHub event metadata and requires JWT
claims granting exactly `flakey: {r: 1}`, with expiry within 90 days. It rejects
write/admin permissions, other caches and future validity dates before creating
any credential file. Attic verifies the JWT signature on authentication.

This is an operational opt-in under the existing trust in same-repository
writers and owner-reviewed source. A PR workflow can itself be edited by a
repository writer; the SHA condition is not a secret access boundary against
such a writer. Fork PRs, unapproved heads, changed heads and other actors do not
run the pull-secret step. They use the official upstream cache. No PR can enter
the separate default-branch publisher, and the push credential is never supplied
to a PR build. Existing CI enable switches remain respected.

To opt in after reviewing the complete PR commit, mint a distinct pull-only
credential valid for at most 90 days and save it privately:

```sh
umask 077
pull_token_file=/absolute/path/to/github-flakey-pull-token
atticadm make-token --sub github-packages-reviewed-read --validity 90d --pull flakey > "$pull_token_file"
gh secret set ATTIC_PULL_TOKEN --repo dweee/dave-packages < "$pull_token_file"
# Replace PR_NUMBER with the reviewed owner PR number.
approved_sha=$(gh pr view PR_NUMBER --repo dweee/dave-packages --json headRefOid --jq .headRefOid)
gh variable set ATTIC_APPROVED_PR_SHA --repo dweee/dave-packages --body "$approved_sha"
```

A new PR commit requires a new review and variable update. Remove the variable
to disable the opt-in: `gh variable delete ATTIC_APPROVED_PR_SHA --repo dweee/dave-packages`.
This reuses normal signature-checked Nix substitution; all ordinary package
builds, recursive public closure guards and composed decompiler checks still run.

Native builders use the pinned Nix quick installer with Nix 2.34.7 on
`ubuntu-24.04`, `ubuntu-24.04-arm`, and `macos-15`. Linux kernel builders reclaim
unused .NET, Android and GHC SDK space and allow up to six hours per package.
The catalog builds one package per matrix job, rather than a complete host.

Only successful default-branch push/dispatch runs enter the separate publisher.
It installs the pinned Attic client from the official cache with local builds
disabled, imports selected NAR data without executing it, verifies the runtime
closure, restores upstream signatures, then pushes roots and runtime closures.
Selected output roots are pushed first with `--no-closure` and
`--ignore-upstream-cache-filter`, so even roots already signed upstream get
narinfo in `flakey`. A second normal closure push retains upstream filtering
for dependencies. Either push failing fails publication.
The token is stored in a temporary mode-0600 Attic configuration, removed from
the client's environment, never passed in command arguments, and removed after
success or failure. Failed publication fails the job.

The four shared upstream synchronization jobs are paused behind
`GUARDED_UPSTREAM_SYNC_ENABLED` (unset or false): their pinned shared
controller builds with public logs and exports public closure artifacts without
this migration's recursive policy. They receive no Attic secret and have cache
publication disabled. Resume them only after the shared controller applies the
same pre-build and export checks. Native PR/push/dispatch builds remain enabled;
a merge to the default branch triggers the guarded native publisher.

## Cache-only unfree builds

`cache-only.yml` builds and pushes in the same native job. It has no PR trigger,
no closure archive export, no artifact upload/download, and no release/backup
job. Its name is excluded from the backup workflow triggers. Both planning and
execution require a default-branch push or dispatch; existing CI/cache enable
variables and the repository's scoped `ATTIC_TOKEN` apply.

`nix/cache-only-platforms.json` is a separate allowlist, exposed as
`cacheOnlyPackages`, never as `packages` or `checks`. It covers VeraCrypt,
ffmpeg-full (including the ROCm variant), NVIDIA 580 for the catalog's
CachyOS server kernel, Keyguard/JNI and StemLab's noncommercial dependency
closure on their supported native platforms. All derivation outputs and runtime
closures are pushed directly to private `flakey`. No binaries or closure archives
leave the job except via authenticated Attic. Build/upload diagnostics and output
paths are captured locally and deleted, including on failure; public logs show
only generic success/failure. A recursive pre-build check and a runtime check
still reject all Wii/disc and subnetter references.

The public artifact workflows remain free-only. Their restrictive Nixpkgs import
and closure guards do not change. Cache-only outputs cannot be selected by their
matrices. The existing per-repository token files and owner secret commands
require no additional GitHub secret or private repository.

## Public build and backup policy

These repositories and their closure artifacts/releases are public. Before any
package build with logs, `ci/public-closure.py` captures and inspects the entire
recursive derivation graph. It rejects the disc input, VeraCrypt, proprietary
NVIDIA 580, ffmpeg-full and subnetter, including transitive references. Failure
prints a generic diagnostic without the rejected path or evaluator output.
Nixpkgs is imported with `allowUnfree = false` as an independent evaluation gate.

Only these Wii attributes are approved, and each still requires the recursive
derivation check: `wiicompiled-native-prebuilt`, `wiicompiled-translator`,
`wiicompiled-setup`, and `wiicompiled-setup-unwrapped`. Final/translated/disc
attributes are rejected before evaluation. Disc-dependent outputs remain on premises. Unfree outputs use only the separate
cache-only workflow above, or on-prem builders, and may be stored only in the
private cache.

Immediately before any NAR archive is created, the export helper checks the
selected outputs' complete runtime closure again. The publisher checks imported
runtime closures before supplying the write credential. No job exports the
whole runner store. Selected free closures are retained as immutable Actions
artifacts for one day; the existing `Preserve package backups` workflow may
copy those archives to public prereleases. These are public redistribution,
which is why the closure policy runs before the archive exists.

Transfers default to a maximum of 4 GiB uncompressed. The T3 package family uses
8 GiB: its measured native Darwin runtime closure is 5,418,932,840 bytes. Export
and import use the same bound, preserving the complete recovery archive.
`ATTIC_MAX_CLOSURE_MIB` configures other packages; `ATTIC_T3_MAX_CLOSURE_MIB`
configures T3. Both accept 1–8192 MiB. An oversize closure still fails before
publication rather than silently dropping data. Runtime policy checks precede
size reporting, and failure diagnostics never print arbitrary exception details.
Publication retries the observed transient server/database-lock and connection-timeout failures up to five times with exponential backoff. One two-hour deadline covers both root and closure uploads plus backoff. Permission and other permanent errors fail immediately; an exhausted retry budget still fails publication.

Build summaries show build and upload duration. Cache success still requires
checking the consumer's exact output store path and authenticated narinfo URL.

## Credential-free checks

```sh
python3 ci/test-push-attic.py
python3 ci/test-transfer-attic.py
python3 ci/test-public-closure.py
python3 ci/test-configure-attic-read.py
python3 ci/test-public-source.py
```

The source boundary check covers first-party package metadata and documentation,
rejecting operator paths, encrypted secrets and private report material. It
complements independent history and credential scans; vendored upstream code
and localization fixtures need their own provenance review.

To recover a permitted archive, download its `packages-RUN_ID` release assets,
join any numbered ZIP parts, verify the supplied checksums, and import its NAR
with `gzip -dc closure.nar.gz | nix-store --import`. Use `outputs.txt` as the
publisher manifest after repairing cache access; reapply the runtime guard.
