{ config, lib, ... }:
let
  cfg = config.programs.handy;
in
{
  options.programs.handy = {
    enable = lib.mkEnableOption "Handy offline speech-to-text";
    package = lib.mkOption {
      type = lib.types.package;
      defaultText = lib.literalExpression "dave-packages.packages.aarch64-darwin.handy";
      description = "The Handy application package to install.";
    };
    autostart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start Handy hidden in each user's graphical login session.";
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    launchd.user.agents.handy = lib.mkIf cfg.autostart {
      serviceConfig = {
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
