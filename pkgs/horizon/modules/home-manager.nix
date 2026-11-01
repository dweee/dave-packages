# programs.horizon and services.horizon-server for one user: a systemd user
# service on Linux, a launchd agent on macOS.
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
  start = common.startScript cfg;
in
{
  imports = [ ./package-set.nix ];

  options.programs.horizon = import ./client-options.nix {
    inherit lib pkgs common;
    cfg = game;
  };

  options.services.horizon-server = common.serverOptions {
    defaultDataDir = "${config.xdg.dataHome}/horizon-server";
  };

  config = lib.mkMerge [
    (lib.mkIf game.enable {
      home.packages =
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
          message = "services.horizon-server.openFirewall needs the NixOS module: Home Manager has no firewall.";
        }
      ];

      home.packages = [ (common.adminCommand { inherit cfg; }) ];

      systemd.user.services.horizon-server = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        Unit = {
          Description = "Horizon dedicated server";
          After = [ "network-online.target" ];
        };
        Service = {
          ExecStart = lib.getExe start;
          Environment = lib.mapAttrsToList (k: v: "${k}=${v}") (common.serverEnvironment cfg);
          TimeoutStopSec = 180;
          Restart = "on-failure";
          RestartSec = 10;
          RestartPreventExitStatus = 78;
        };
        # A user service keeps running logged out only with lingering
        # (loginctl enable-linger, or users.users.<name>.linger on NixOS).
        Install.WantedBy = [ "default.target" ];
      };

      launchd.agents.horizon-server = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        enable = true;
        config = {
          ProgramArguments = [ (lib.getExe start) ];
          EnvironmentVariables = common.serverEnvironment cfg;
          KeepAlive.SuccessfulExit = false;
          RunAtLoad = true;
          ProcessType = "Interactive";
          ExitTimeOut = 180;
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/horizon-server.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/horizon-server.log";
        };
      };
    })
  ];
}
