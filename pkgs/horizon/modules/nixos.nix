# programs.horizon (the launcher and the game) and services.horizon-server.
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
in
{
  imports = [ ./package-set.nix ];

  options.programs.horizon = import ./client-options.nix {
    inherit lib pkgs common;
    cfg = game;
  };

  options.services.horizon-server =
    common.serverOptions { defaultDataDir = "/var/lib/horizon-server"; }
    // {
      user = lib.mkOption {
        type = lib.types.str;
        default = "horizon-server";
        description = "The user the server runs as.";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = "horizon-server";
        description = "The server's group.";
      };
    };

  config = lib.mkMerge [
    (lib.mkIf game.enable {
      environment.systemPackages =
        lib.optional game.launcher.enable game.launcher.package
        ++ lib.optional game.game.enable game.game.package;
      hardware.graphics.enable = lib.mkDefault true;
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
      ];

      users.users = lib.mkIf (cfg.user == "horizon-server") {
        horizon-server = {
          isSystemUser = true;
          inherit (cfg) group;
          home = cfg.dataDir;
        };
      };
      users.groups = lib.mkIf (cfg.group == "horizon-server") { horizon-server = { }; };

      environment.systemPackages = [
        (common.adminCommand {
          inherit cfg;
          inherit (cfg) user;
        })
      ];

      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

      systemd.tmpfiles.settings.horizon-server.${cfg.dataDir}.d = {
        inherit (cfg) user group;
        mode = "0750";
      };

      systemd.services.horizon-server = {
        description = "Horizon dedicated server";
        wantedBy = [ "multi-user.target" ];
        # Online mode and name lookups need Mojang's services.
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        environment = common.serverEnvironment cfg;
        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = cfg.dataDir;
          ExecStart = lib.getExe (common.startScript cfg);
          # SIGTERM makes the supervisor stop the game cleanly; saving a big
          # world takes a moment (upstream's own unit, horizon-server service print).
          TimeoutStopSec = 180;
          Restart = "on-failure";
          RestartSec = 10;
          # 78: no game files, or preparing them failed. Not worth retrying.
          RestartPreventExitStatus = 78;
          # Preparing runs Java, whose JIT needs writable executable memory.
          ReadWritePaths = [ cfg.dataDir ];
          UMask = "0027";
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectSystem = "strict";
          ProtectHome = !(lib.hasPrefix "/home/" cfg.dataDir);
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          SystemCallArchitectures = "native";
          CapabilityBoundingSet = "";
        };
      };
    })
  ];
}
