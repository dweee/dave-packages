# programs.horizon and services.horizon-server on nix-darwin. The server runs
# as a launchd agent of `services.horizon-server.user` (the primary user by
# default), as `horizon-server service install` sets it up on macOS.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  common = import ./common.nix {
    inherit lib pkgs;
    horizon = config.horizon.packageSet;
  };
  game = config.programs.horizon;
  cfg = config.services.horizon-server;
  home = config.users.users.${cfg.user}.home or "/Users/${cfg.user}";
in
{
  imports = [ ./package-set.nix ];

  options.programs.horizon = import ./client-options.nix {
    inherit lib pkgs common;
    cfg = game;
  };

  options.services.horizon-server =
    common.serverOptions { defaultDataDir = "${home}/Library/Application Support/Horizon Server"; }
    // {
      user = lib.mkOption {
        type = lib.types.str;
        default = config.system.primaryUser;
        defaultText = lib.literalExpression "config.system.primaryUser";
        description = "The user whose launchd agent runs the server.";
      };
    };

  config = lib.mkMerge [
    (lib.mkIf game.enable {
      environment.systemPackages =
        lib.optional game.launcher.enable game.launcher.package
        ++ lib.optional game.game.enable game.game.package;
    })

    (lib.mkIf cfg.enable {
      services.horizon-server.package = lib.mkDefault (
        common.pick {
          kind = "server";
          inherit (cfg) channel variant nativeMods;
        }
      );

      assertions = [
        {
          assertion = cfg.eula;
          message = "services.horizon-server.eula must be true: the server needs the Minecraft EULA agreed to.";
        }
        {
          assertion = !cfg.openFirewall;
          message = "services.horizon-server.openFirewall: allow the server in the macOS application firewall instead.";
        }
      ];

      environment.systemPackages = [ (common.adminCommand { inherit cfg; }) ];

      launchd.user.agents.horizon-server = {
        serviceConfig = {
          ProgramArguments = [ (lib.getExe (common.startScript cfg)) ];
          EnvironmentVariables = common.serverEnvironment cfg;
          KeepAlive.SuccessfulExit = false;
          RunAtLoad = true;
          ProcessType = "Interactive";
          ExitTimeOut = 180;
          StandardOutPath = "/tmp/horizon-server.${cfg.user}.log";
          StandardErrorPath = "/tmp/horizon-server.${cfg.user}.log";
        };
      };
    })
  ];
}
