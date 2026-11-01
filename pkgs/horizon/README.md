# Horizon

[Horizon](https://playhorizon.dev) ([source](https://github.com/horizon-rust/horizon)) is an
unofficial native implementation of Minecraft: Java Edition 26.3, in Rust. It holds none of
Mojang's code or data: `horizon-prepare` derives the game files from your own copy of
Minecraft. Not an official Minecraft product; not approved by or associated with Mojang or
Microsoft.

## Packages

| Attribute | What | Platforms |
| --- | --- | --- |
| `horizon-launcher` | the launcher, from the newest `launcher@X.Y.Z` | Linux, macOS |
| `horizon-launcher-git` | the launcher, from main | Linux, macOS |
| `horizon-launcher-bin` | upstream's launcher build | x86_64 Linux, macOS |
| `horizon`, `-unstable`, `-git` | the game: horizon-client, horizon-ctl, horizon-prepare, horizon-server | Linux, macOS |
| `horizon-server`, `-unstable`, `-git` | the server build: the game without sound or controllers as horizon-engine, horizon-prepare, horizon-server | Linux (aarch64 too), macOS |
| `horizon-bin` | upstream's game folders | x86_64 Linux, macOS |
| `horizon-server-bin` | upstream's server folder (macOS: the game folder) | x86_64 Linux, macOS |
| `horizon-mixins` | the tool that applies native mods to the game's source | Linux, macOS |

The channels:

- **stable** (no suffix): the newest dated Nightly, `nightly-YYYY-MM-DD`. Since 2026-10-28 the
  game ships only Nightlies; the launcher keeps semver releases.
- **unstable**: the rolling `nightly` release, which can include pull requests the team picked
  before they merged.
- **head** (`-git`): main's newest commit.

Source builds pin a Nightly's source commit, which upstream keeps for good as the tag
`nightly-source/<date>-<short>`, and set `HORIZON_VERSION`/`HORIZON_NIGHTLY` as upstream's
release builds do, so the game and `--version` say which Nightly they are. Dated Nightly
releases (their prebuilt archives) are deleted after seven days: the `-bin` pins stay
fetchable only while the updater keeps them current, or from a binary cache. The rolling Nightly's
archives are replaced in place by the next Nightly, so its prebuilt packages
(`channels.unstable.{game-bin,server-bin}`, the modules' `channel = "unstable"; variant = "bin"`)
are not in the catalog's package outputs or CI; prefer the source build for that channel.

`legacyPackages.<system>.horizonPackages` holds every channel and variant:
`channels.<stable|unstable|head>.{launcher, game, server, game-bin, server-bin}`.

### Layout

Each package installs upstream's release folder in `libexec/horizon` (the programs side by side
with `research-lock.json`, `crates/horizon-prepare`, `tools` and the exporters' Java sources, as
`xtask package` lays it out) and wraps the programs in `bin`:

- `horizon-prepare` needs a writable folder: without `--root` it prepares in a copy of the
  folder's sources under `$HORIZON_PREPARE_ROOT`, else `$XDG_DATA_HOME/horizon/prepare`. It has
  JDK 25 for the exporters, which it compiles against your jars on first use (upstream's
  release archives carry them precompiled; the source build compiles them at preparation).
- `horizon-server` has `HORIZON_NO_UPDATE_CHECK=1`: Nix updates it.
- On Linux, `horizon-launcher` runs in an FHS environment (`fhs.nix`): the game builds it
  installs are upstream's ordinary Linux programs. The environment also has the C toolchain,
  pkg-config files and headers the launcher's native-mod builds need, and JDK 25.
  Self-update is off; the menu entry it writes starts `horizon-launcher` from `PATH`.
- On macOS, `horizon-launcher-bin` installs upstream's signed `Horizon.app`.

## Modules

`nixosModules.horizon`, `darwinModules.horizon` and `homeManagerModules.horizon` share their
options (`modules/`). Each picks packages by `channel` (`stable`, `unstable`, `head`) and
`variant` (`source`, `bin`) from the catalog's own builds, so a host gets the binary cache's
outputs; with the overlay, `pkgs.horizonPackages` is used instead.

```nix
{
  programs.horizon.enable = true;      # the launcher
  programs.horizon.game.enable = true; # and the game itself

  services.horizon-server = {
    enable = true;
    eula = true;              # https://aka.ms/MinecraftEULA
    openFirewall = true;      # NixOS only
    whitelist = [ "Alex" ];   # exactly these players, at every start
    operators = [ "Alex" ];
    settings = {
      server = { motd = "Horizon"; max_players = 10; view_distance = 12; };
      world = { name = "world"; difficulty = "normal"; };
      properties."spawn-protection" = 0;
    };
    contentMods.my_mod = ./my_mod.hmod;
    datapacks.my-pack = ./my-pack.zip;
    nativeMods = [ ./mods/veinminer ];  # compiled into the engine (variant = "source")
  };
}
```

The NixOS server is a hardened system service (`/var/lib/horizon-server`, its own user); Home
Manager runs a systemd user service or a launchd agent; nix-darwin a launchd agent of the
primary user. Each writes `server.toml` from `settings` before every start (changes the game
makes to it are not kept), writes `eula.txt`, links content mods into `horizon-mods/` and turns
them on in `horizon-mods.txt`, links datapacks into the world, then reconciles the whitelist and
operators through `horizon-server` itself, which looks names up as vanilla does. Secrets go in
`environmentFile` as `HORIZON_SETTING_<section>_<key>=value` lines (applied with
`horizon-server config set`). `horizon-server-admin` runs `horizon-server` on the declared folder
as the server's user: `horizon-server-admin status`, `panel`, `cmd say hi`, `backup`.

### Game files

The server needs files prepared from Minecraft 26.3. They are derived from Mojang's files:
keep them out of the Nix store and any shared binary cache. Either:

- prepare on a computer with Minecraft, with the launcher or `horizon-prepare --prepare
  --server-jar server.jar`, and copy the prepared `26.3` folder's contents to
  `<dataDir>/resources` (`resources` names another folder); or
- set `prepare.enable`, with `prepare.serverJar` and `prepare.minecraftDir` (or
  `prepare.extraArgs` with `--client-jar`, `--version-json`, `--libraries-dir`,
  `--assets-dir`) naming files on the server; it prepares when `horizon-prepare --check` finds
  the files missing or out of date.

### Online mode

`online_mode = true`, the default, checks accounts with Mojang: players who sign in with the
official Minecraft launcher join with their own accounts. Horizon's own client cannot sign in
to a Microsoft account yet, so it joins offline servers only, and an offline server lets anyone
who reaches it join under any name. A public server should stay in online mode.

### Mods

- **Content mods** (`.hmod`): data and assets. `contentMods` on the server; players install the
  same mods from the launcher's Mods page.
- **Native mods** (horizon-mixins bundles, `.hnmod`): Rust compiled into the game. On a server,
  `nativeMods` builds the engine with them (`horizon-server.override { nativeMods = [ ... ]; }`
  outside the modules); a bundle may use only the crates the game's `Cargo.lock` holds. The
  launcher builds players' native mods itself, in its FHS environment.
- **Datapacks**: `datapacks`.

## Updates

`update.py` pins all three channels in `sources.json`: source revisions and hashes, the vendored
crates' hashes, the launcher and Nightly archives from upstream's `SHA256SUMS`, and the
horizon-mixins commit the launcher uses. `.github/workflows/horizon-updates.yml` runs it every
six hours and opens a review PR; `update.py --check` reports candidates to the version monitor.

```sh
python3 pkgs/horizon/update.py                    # all channels
python3 pkgs/horizon/update.py --channel head     # one
python3 pkgs/horizon/update.py --check            # report only
```

## Toward nixpkgs

`launcher.nix`, `game.nix`, `bin.nix`, `fhs.nix` and `mixins.nix` are ordinary `callPackage`
recipes. Each takes its version, revision and hashes as `pin`, one entry of `sources.json`; for
nixpkgs, inline the stable entry, drop `pin`, and add `passthru.updateScript`. The layout maps to
`pkgs/by-name/ho/horizon{,-server,-launcher,-mixins}`; `horizon-server` is `game.nix` with
`headless = true`, and `horizon-launcher` is `fhs.nix` around `launcher.nix`. The modules follow
nixpkgs' module conventions, and `checks.nix`'s VM test is a NixOS test.
