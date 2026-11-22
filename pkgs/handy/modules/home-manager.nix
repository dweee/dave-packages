# Home-manager module for Handy speech-to-text
#
# Provides a systemd user service or a macOS LaunchAgent for autostart.
# Usage: imports = [ dave-packages.homeManagerModules.handy ];
#        services.handy.enable = true;
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.handy;
in
{
  options.services.handy = {
    enable = lib.mkEnableOption "Handy speech-to-text user service";

    package = lib.mkOption {
      type = lib.types.package;
      defaultText = lib.literalExpression "dave-packages.packages.\${system}.handy";
      description = "The Handy package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
    systemd.user.services.handy = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      Unit = {
        Description = "Handy speech-to-text";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${cfg.package}/bin/handy";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
    launchd.agents.handy = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      enable = true;
      config = {
        ProgramArguments = [
          "${cfg.package}/bin/handy"
          "--start-hidden"
        ];
        RunAtLoad = true;
        LimitLoadToSessionType = "Aqua";
      };
    };
  };
}
