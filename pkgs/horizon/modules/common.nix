# What the NixOS, nix-darwin and Home Manager modules share: choosing a
# package by channel and variant, the server's options, and the script that
# lays out a server folder from them and starts horizon-server in it.
{
  lib,
  pkgs,
  horizon,
}:

let
  inherit (lib) mkOption types literalExpression;
  toml = pkgs.formats.toml { };
in
rec {
  inherit horizon;

  channelOption = mkOption {
    type = types.enum [
      "stable"
      "unstable"
      "head"
    ];
    default = "stable";
    description = ''
      Which Horizon to follow. `stable` is the newest dated Nightly (and the
      newest `launcher@` release), `unstable` the rolling Nightly, `head`
      upstream's main branch (source builds only).
    '';
  };

  variantOption = mkOption {
    type = types.enum [
      "source"
      "bin"
    ];
    default = "source";
    description = ''
      `source` builds from source (every platform, aarch64-linux included);
      `bin` wraps upstream's prebuilt archives (x86_64-linux and macOS only,
      not for `head`).
    '';
  };

  # kind: launcher, game or server.
  pick =
    {
      kind,
      channel,
      variant,
      nativeMods ? [ ],
    }:
    let
      set = horizon.channels.${channel};
      chosen =
        if kind == "launcher" then
          if variant == "bin" then horizon.launcher-bin else set.launcher
        else if variant == "bin" then
          set."${kind}-bin"
            or (throw "Horizon: no prebuilt ${kind} for the ${channel} channel; use variant = \"source\"")
        else
          set.${kind};
    in
    if nativeMods == [ ] then
      chosen
    else if variant == "bin" || kind == "launcher" then
      throw "Horizon: native mods are compiled into a source build of the game or server"
    else
      chosen.override { inherit nativeMods; };

  nativeModsOption = mkOption {
    type = types.listOf types.path;
    default = [ ];
    example = literalExpression "[ ./mods/veinminer ]";
    description = ''
      horizon-mixins bundles (folders holding a `horizon-mixin.toml`, or
      folders of them) compiled into the game. Needs `variant = "source"`.
      A bundle may only use crates the game's Cargo.lock already holds.
    '';
  };

  serverOptions =
    { defaultDataDir }:
    {
      enable = lib.mkEnableOption "a Horizon dedicated server (Minecraft: Java Edition 26.3, in Rust)";

      channel = channelOption;
      variant = variantOption;
      nativeMods = nativeModsOption;

      package = mkOption {
        type = types.package;
        description = "The Horizon server. Defaults to the one `channel`, `variant` and `nativeMods` select.";
      };

      dataDir = mkOption {
        type = types.str;
        default = defaultDataDir;
        description = "The server folder: world, vanilla lists, backups, logs and server.toml.";
      };

      eula = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether you agree to the Minecraft EULA (https://aka.ms/MinecraftEULA).
          The server refuses to start without it.
        '';
      };

      resources = mkOption {
        type = types.str;
        default = "resources";
        description = ''
          The prepared game files (the folder horizon-prepare writes, holding
          `horizon-resources.json`), relative to `dataDir` or absolute. Copy the
          contents of a `26.3` folder the launcher or `horizon-prepare` prepared
          on another computer here, or let `prepare` make it. They come from
          your own copy of Minecraft: keep them out of the Nix store and any
          binary cache. Without them the server does not start (and is not
          restarted until they are there).
        '';
      };

      prepare = {
        enable = lib.mkEnableOption ''
          preparing the game files with horizon-prepare before a start, when
          they are missing or the server's package changed. They are prepared
          in `dataDir`/.horizon/prepare and `resources` is linked to them'';
        serverJar = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The pinned 26.3 server.jar (`downloads.server.url` in the launcher's 26.3.json).";
        };
        minecraftDir = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            An official launcher game directory with 26.3 installed (played
            once): `versions/26.3/26.3.json` and `26.3.jar`, `libraries/` and
            `assets/`. Another launcher's files can be laid out so.
          '';
        };
        extraArgs = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [
            "--client-jar"
            "/srv/minecraft/26.3.jar"
          ];
          description = ''
            Further horizon-prepare flags. Newer releases also take
            --client-jar, --version-json, --libraries-dir and --assets-dir.
          '';
        };
      };

      whitelist = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        example = [ "Alex" ];
        description = ''
          Player names to whitelist. `null` leaves whitelist.json to the
          server; a list turns the whitelist on and makes it exactly these
          players at every start. In online mode the names are looked up as
          Minecraft accounts.
        '';
      };

      operators = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Like `whitelist`, for ops.json (operator level 4).";
      };

      contentMods = mkOption {
        type = types.attrsOf types.path;
        default = { };
        example = literalExpression "{ my_mod = ./my_mod.hmod; }";
        description = ''
          Content mods (`.hmod` files, or folders holding `horizon-mod.toml`),
          by mod id. They are linked into `horizon-mods/` and turned on in
          `horizon-mods.txt`. Players need the same mods.
        '';
      };

      datapacks = mkOption {
        type = types.attrsOf types.path;
        default = { };
        description = "Vanilla datapacks (zips or folders), by name, linked into the world's `datapacks/`.";
      };

      settings = mkOption {
        type = toml.type;
        default = { };
        example = literalExpression ''
          {
            server = { motd = "Horizon"; max_players = 10; };
            world = { name = "world"; difficulty = "normal"; };
            properties."spawn-protection" = 0;
            backups = { every = "6h"; keep = 12; };
          }
        '';
        description = ''
          `server.toml` (docs/hosting.md, section 4), written before every
          start: changes the game makes to it itself are not kept. Keys left
          out take vanilla 26.3's defaults. Secrets such as `api.token` or
          `discord.webhook` go in `environmentFile` instead.
        '';
      };

      port = mkOption {
        type = types.port;
        default = 25565;
        description = "The game's TCP port (`server.port`).";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open `port` in the firewall.";
      };

      environmentFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          A file of `KEY=value` lines read before every start. Any
          `HORIZON_SETTING_<section>_<key>` there is applied with
          `horizon-server config set`, so secrets stay out of the Nix store,
          e.g. `HORIZON_SETTING_discord_webhook=https://...`.
        '';
      };

      extraEnvironment = mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = {
          MIMALLOC_ALLOW_THP = "0";
        };
        description = "Environment for the server.";
      };
    };

  names = list: lib.escapeShellArgs (if list == null then [ ] else list);

  serverSettings =
    cfg:
    lib.foldl' lib.recursiveUpdate { } [
      {
        server.port = cfg.port;
        engine.resources = cfg.resources;
      }
      cfg.settings
      (lib.optionalAttrs (cfg.whitelist != null) { server.whitelist = true; })
    ];

  # Lays out cfg.dataDir and execs `horizon-server run` there. Runs as the
  # server's own user; every step is safe to repeat.
  startScript =
    cfg:
    let
      config = toml.generate "server.toml" (serverSettings cfg);
      world = cfg.settings.world.name or "world";
      server = lib.getExe' cfg.package "horizon-server";
      prepare = lib.getExe' cfg.package "horizon-prepare";
    in
    pkgs.writeShellApplication {
      name = "horizon-server-start";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.findutils
        pkgs.jq
      ];
      text = ''
        dir=${lib.escapeShellArg cfg.dataDir}
        mkdir -p "$dir"
        cd "$dir"

        ${lib.optionalString (cfg.environmentFile != null) ''
          set -a
          # shellcheck disable=SC1091
          . ${lib.escapeShellArg cfg.environmentFile}
          set +a
        ''}

        ${lib.optionalString cfg.eula ''
          printf '%s\n' '# Agreed through the Nix configuration (https://aka.ms/MinecraftEULA).' eula=true > eula.txt
        ''}

        # The declared settings, every start (the game writes its own changes back).
        install -m 600 ${config} server.toml
        while IFS='=' read -r key value; do
          section=''${key#HORIZON_SETTING_}
          ${server} --dir "$dir" config set "''${section%%_*}.''${section#*_}=$value" > /dev/null
        done < <(env | grep '^HORIZON_SETTING_[a-z]*_' || true)

        # Content mods and datapacks: links into the store are this module's to replace.
        mods=${lib.escapeShellArg (lib.concatStringsSep " " (lib.attrNames cfg.contentMods))}
        mkdir -p horizon-mods
        find horizon-mods -maxdepth 1 -type l -lname '/nix/store/*' -delete
        ${lib.concatStrings (
          lib.mapAttrsToList (id: path: ''
            ln -sfn ${path} horizon-mods/${lib.escapeShellArg id}${lib.optionalString (lib.hasSuffix ".hmod" (toString path)) ".hmod"}
          '') cfg.contentMods
        )}
        if [ -n "$mods" ]; then
          for id in $mods; do printf 'mod.%s:true\n' "$id"; done > horizon-mods.txt
        fi
        mkdir -p ${lib.escapeShellArg world}/datapacks
        find ${lib.escapeShellArg world}/datapacks -maxdepth 1 -type l -lname '/nix/store/*' -delete
        ${lib.concatStrings (
          lib.mapAttrsToList (name: path: ''
            ln -sfn ${path} ${lib.escapeShellArg world}/datapacks/${lib.escapeShellArg name}
          '') cfg.datapacks
        )}

        # Declared players: added through horizon-server, which looks names up
        # as vanilla does, and anyone else taken off.
        sync() {
          list=$1 file=$2
          read -ra add <<< "$3"
          read -ra remove <<< "$4"
          shift 4
          [ -e "$file" ] || echo '[]' > "$file"
          for name in "$@"; do
            if ! jq -e --arg n "$name" 'any(.[]; (.name | ascii_downcase) == ($n | ascii_downcase))' "$file" > /dev/null; then
              ${server} --dir "$dir" "''${add[@]}" "$name" || echo "warning: could not add $name to the $list" >&2
            fi
          done
          jq -r '.[].name' "$file" | while read -r name; do
            keep=
            for wanted in "$@"; do
              if [ "''${wanted,,}" = "''${name,,}" ]; then keep=1; fi
            done
            [ -n "$keep" ] || ${server} --dir "$dir" "''${remove[@]}" "$name" || true
          done
        }
        ${lib.optionalString (cfg.whitelist != null) ''
          sync whitelist whitelist.json "whitelist add" "whitelist remove" ${names cfg.whitelist}
        ''}
        ${lib.optionalString (cfg.operators != null) ''
          sync operators ops.json op deop ${names cfg.operators}
        ''}

        # Last, so the folder is laid out even while the game files are missing.
        resources=${lib.escapeShellArg cfg.resources}
        case $resources in /*) ;; *) resources=$dir/$resources ;; esac
        ${lib.optionalString cfg.prepare.enable ''
          root="$dir/.horizon/prepare"
          version=$(jq -r .minecraft.version ${cfg.package}/libexec/horizon/research-lock.json)
          if [ ! -e "$resources/horizon-resources.json" ] \
            || [ "$(cat "$dir/.horizon/prepared-by" 2>/dev/null || true)" != ${cfg.package} ]; then
            echo "Preparing the game files in $root"
            if ! HORIZON_PREPARE_ROOT="$root" ${prepare} --prepare \
              ${
                lib.optionalString (
                  cfg.prepare.serverJar != null
                ) "--server-jar ${lib.escapeShellArg cfg.prepare.serverJar}"
              } \
              ${
                lib.optionalString (
                  cfg.prepare.minecraftDir != null
                ) "--minecraft-dir ${lib.escapeShellArg cfg.prepare.minecraftDir}"
              } \
              ${lib.escapeShellArgs cfg.prepare.extraArgs}; then
              echo "error: horizon-prepare failed; see the lines above" >&2
              exit 78
            fi
            echo ${cfg.package} > "$dir/.horizon/prepared-by"
          fi
          if [ ! -e "$resources" ] || [ -L "$resources" ]; then
            ln -sfn "$root/.local/horizon-client/$version" "$resources"
          fi
        ''}
        if [ ! -e "$resources/horizon-resources.json" ]; then
          echo "error: no prepared game files in $resources: copy them there or set prepare.enable" >&2
          exit 78
        fi

        exec ${server} --dir "$dir" run
      '';
    };

  serverEnvironment =
    cfg:
    {
      HORIZON_NO_UPDATE_CHECK = "1";
    }
    // cfg.extraEnvironment;

  # `horizon-server` for the operator: the declared folder, as the server's user.
  adminCommand =
    {
      cfg,
      user ? null,
    }:
    pkgs.writeShellScriptBin "horizon-server-admin" ''
      ${lib.optionalString (user != null) ''
        if [ "$(id -un)" != ${lib.escapeShellArg user} ]; then
          exec /run/wrappers/bin/sudo -u ${lib.escapeShellArg user} -- "$0" "$@"
        fi
      ''}
      exec ${lib.getExe' cfg.package "horizon-server"} --dir ${lib.escapeShellArg cfg.dataDir} "$@"
    '';
}
