# programs.horizon: the launcher (installs, prepares and starts the game,
# hosts servers, builds native mods) and, optionally, the game itself.
{
  lib,
  pkgs,
  common,
  cfg,
}:

let
  inherit (lib) mkOption types literalExpression;
in
{
  enable = lib.mkEnableOption "Horizon, Minecraft: Java Edition 26.3 rewritten in Rust";
  channel = common.channelOption;
  variant = common.variantOption;

  launcher = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Install the Horizon launcher.";
    };
    variant = mkOption {
      type = types.enum [
        "source"
        "bin"
      ];
      default = if pkgs.stdenv.hostPlatform.isDarwin && cfg.channel != "head" then "bin" else cfg.variant;
      defaultText = literalExpression ''if isDarwin then "bin" else programs.horizon.variant'';
      description = "As `variant`, for the launcher; on macOS the prebuilt app bundle by default.";
    };
    package = mkOption {
      type = types.package;
      default = common.pick {
        kind = "launcher";
        inherit (cfg) channel;
        inherit (cfg.launcher) variant;
      };
      defaultText = "the launcher `channel` and `launcher.variant` select";
      description = "The launcher. On Linux it runs in an FHS environment, so the game builds it installs run.";
    };
  };

  game = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Also install the game itself (horizon-client, horizon-ctl,
        horizon-prepare, horizon-server) from Nix, beside the launcher's own
        installs.
      '';
    };
    nativeMods = common.nativeModsOption;
    package = mkOption {
      type = types.package;
      default = common.pick {
        kind = "game";
        inherit (cfg) channel variant;
        inherit (cfg.game) nativeMods;
      };
      defaultText = "the game `channel`, `variant` and `game.nativeMods` select";
      description = "The game.";
    };
  };
}
