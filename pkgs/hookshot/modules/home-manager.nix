# Home Manager: Hookshot for one user. The launcher and the builder know the game folder, the dump and the language;
# a user service builds (or rebuilds) the game there, and can run by itself after the package changes.
#
# The dump is a path *string* on purpose: a Nix path literal (./game.nup) would be copied into the Nix store, and from
# there into a binary cache. Nothing made from the game goes into the store: the game folder and the build files
# (~/.cache/hookshot-builder) stay in your home.
self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.hookshot;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    literalExpression
    ;

  languages = [
    "en-US"
    "en-GB"
    "fr"
    "fr-CA"
    "de"
    "it"
    "es"
    "es-419"
    "pt-BR"
    "nl"
    "pl"
    "ru"
    "ja"
    "ko"
    "zh-Hans"
    "zh-Hant"
  ];

  envValue = v: if lib.isBool v then (if v then "1" else "0") else toString v;

  # The package with this user's choices as defaults (the desktop entries start these too)
  defaults = [
    "--set-default HOOKSHOT_GAME_DIR ${lib.escapeShellArg cfg.gameDir}"
  ]
  ++ lib.optional (cfg.dump != null) "--set-default HOOKSHOT_DUMP ${lib.escapeShellArg cfg.dump}"
  ++ lib.optional (cfg.language != null) "--set-default HOOKSHOT_LANGUAGE ${cfg.language}";
  finalPackage = pkgs.symlinkJoin {
    name = "${cfg.package.name}-configured";
    paths = [ cfg.package ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for b in hookshot hookshot-build hookshot-builder; do
        wrapProgram $out/bin/$b ${lib.concatStringsSep " " defaults}
      done
    '';
    inherit (cfg.package) meta;
  };

  stamp = "${cfg.gameDir}/.hookshot-nix-package";
  buildScript = pkgs.writeShellScript "hookshot-build-service" ''
    set -eu
    dir=${lib.escapeShellArg cfg.gameDir}
    if [ -f "$dir/image.bin" ]; then
      # (a folder built before keeps the game files it was built from: no dump needed)
      ${finalPackage}/bin/hookshot-build --update "$dir" ${lib.escapeShellArgs cfg.buildFlags}
    elif [ -n "''${HOOKSHOT_DUMP:-}" ]; then
      ${finalPackage}/bin/hookshot-build ${lib.escapeShellArgs cfg.buildFlags}
    else
      echo "hookshot-build: no game in $dir and no dump set (programs.hookshot.dump)" >&2
      exit 1
    fi
    printf '%s\n' ${cfg.package} > ${lib.escapeShellArg stamp}
  '';
in
{
  options.programs.hookshot = {
    enable = mkEnableOption "Hookshot for this user: the launcher, the builder and a build service";

    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.hookshot;
      defaultText = literalExpression "hookshot.packages.\${pkgs.stdenv.hostPlatform.system}.hookshot";
      description = "The Hookshot builder package.";
    };

    finalPackage = mkOption {
      type = types.package;
      readOnly = true;
      default = finalPackage;
      defaultText = literalExpression "the package, its commands defaulting to this module's folder, dump and language";
      description = "The package as installed, with this module's settings.";
    };

    gameDir = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/Games/Hookshot";
      defaultText = literalExpression ''"''${config.home.homeDirectory}/Games/Hookshot"'';
      description = "The game folder `hookshot-build` writes and `hookshot` starts. About 25 GB once built.";
    };

    dump = mkOption {
      type = types.nullOr (types.strMatching "/.*");
      default = null;
      example = "/mnt/games/dumps/ocarina.nup";
      description = ''
        Your copy of the game: a `.nup` file, or a folder with `romfs/` and `exefs/` in it, at program
        `0400486024DEC000`, update v131072. An absolute path string, never a Nix path, so the game is not copied into
        the Nix store. Only the first build needs it: the game folder keeps the files an update rebuilds from.
      '';
    };

    language = mkOption {
      type = types.nullOr (types.enum languages);
      default = null;
      example = "en-GB";
      description = "The game's language. `null`: the folder's own, else en-US.";
    };

    buildFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "--jobs"
        "8"
        "--fsr"
      ];
      description = "More arguments for `nx2/make_game.py` when the service builds.";
    };

    rebuildOnChange = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Start the build service in the background on activation when the package differs from the one the game folder
        was built with (or there is no game yet and a dump is set). A build takes 10 to 45 minutes and about 60 GB.
        Off: run `systemctl --user start hookshot-build` yourself after a flake bump.
      '';
    };

    environment = mkOption {
      type = types.attrsOf (
        types.oneOf [
          types.str
          types.int
          types.bool
        ]
      );
      default = { };
      example = literalExpression ''
        {
          RX_VK_LOW_SPEC = true;
          HOS_WINDOW_SIZE = "1920x1080";
        }
      '';
      description = ''
        The game's switches (docs/development.md), written to `hookshot_env.txt` in the game folder. Booleans are
        written as 1 and 0. The environment still wins over the file. Empty: the file is left to you.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
        message = "programs.hookshot: Hookshot builds for x86_64-linux only.";
      }
      {
        assertion = cfg.dump == null || !(lib.hasPrefix builtins.storeDir cfg.dump);
        message = "programs.hookshot.dump: the game must not be in the Nix store; give the path of your own copy.";
      }
      {
        assertion = cfg.environment == { } || lib.hasPrefix "${config.home.homeDirectory}/" cfg.gameDir;
        message = "programs.hookshot.environment: gameDir must be inside the home directory to manage hookshot_env.txt.";
      }
    ];

    home.packages = [ finalPackage ];

    home.sessionVariables = {
      HOOKSHOT_GAME_DIR = cfg.gameDir;
    }
    // lib.optionalAttrs (cfg.dump != null) { HOOKSHOT_DUMP = cfg.dump; }
    // lib.optionalAttrs (cfg.language != null) { HOOKSHOT_LANGUAGE = cfg.language; };

    home.file = mkIf (cfg.environment != { }) {
      "${lib.removePrefix "${config.home.homeDirectory}/" cfg.gameDir}/hookshot_env.txt".text =
        "# Written by Home Manager (programs.hookshot.environment)\n"
        + lib.concatStrings (lib.mapAttrsToList (k: v: "${k}=${envValue v}\n") cfg.environment);
    };

    systemd.user.services.hookshot-build = {
      Unit = {
        Description = "Build Hookshot from your copy of the game into ${cfg.gameDir}";
        Documentation = [ "https://git.notrexed.dev/Hookshot/Hookshot#build-from-source" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${buildScript}";
        Environment = [
          "HOOKSHOT_GAME_DIR=${cfg.gameDir}"
        ]
        ++ lib.optional (cfg.dump != null) "HOOKSHOT_DUMP=${cfg.dump}"
        ++ lib.optional (cfg.language != null) "HOOKSHOT_LANGUAGE=${cfg.language}";
        # (a long, heavy build: kept out of the desktop's way)
        Nice = 10;
        IOSchedulingClass = "idle";
        CPUSchedulingPolicy = "batch";
        TimeoutStartSec = "3h";
      };
    };

    home.activation.hookshotRebuild = mkIf cfg.rebuildOnChange (
      lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
        want=${cfg.package}
        have=$(cat ${lib.escapeShellArg stamp} 2>/dev/null || true)
        if [ "$have" != "$want" ] && { [ -f ${lib.escapeShellArg "${cfg.gameDir}/image.bin"} ] || ${
          lib.boolToString (cfg.dump != null)
        }; }; then
          run ${pkgs.systemd}/bin/systemctl --user start --no-block hookshot-build.service || true
        fi
      ''
    );
  };
}
