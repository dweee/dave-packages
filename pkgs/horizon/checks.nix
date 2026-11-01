# Horizon module checks: a NixOS VM that lays out and starts a server, and an
# evaluation of the nix-darwin module. No Minecraft files exist here, so the
# server is expected to stop at "no prepared game files".
{
  self,
  inputs,
  system,
  pkgs,
}:

let
  inherit (pkgs) lib;
  linux = lib.hasSuffix "-linux" system;
  darwin = lib.hasSuffix "-darwin" system;
in
lib.optionalAttrs linux {
  horizon-server-module = pkgs.testers.runNixOSTest {
    name = "horizon-server-module";
    nodes.machine = {
      imports = [ self.nixosModules.horizon ];
      services.horizon-server = {
        enable = true;
        eula = true;
        openFirewall = true;
        # Offline: names get offline UUIDs without asking Mojang.
        settings.server.online_mode = false;
        settings.world.difficulty = "hard";
        whitelist = [ "Alex" ];
        operators = [ "Alex" ];
        contentMods.test_mod = pkgs.writeText "test_mod.hmod" "";
        datapacks.test = pkgs.writeTextDir "pack.mcmeta" ''{"pack":{"pack_format":80,"description":"test"}}'';
      };
      programs.horizon = {
        enable = true;
        launcher.enable = false;
      };
    };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      # No game files here: the folder is laid out, then the start stops (78, not retried).
      machine.wait_until_succeeds("journalctl -u horizon-server | grep -q 'no prepared game files'", timeout=120)
      machine.succeed("systemctl show -p ExecMainStatus horizon-server | grep -q '=78'")
      d = "/var/lib/horizon-server"
      machine.succeed(f"grep -q '^eula=true' {d}/eula.txt")
      machine.succeed(f"grep -q 'port = 25565' {d}/server.toml")
      machine.succeed(f"grep -q 'difficulty = \"hard\"' {d}/server.toml")
      machine.succeed(f"grep -q 'Alex' {d}/whitelist.json")
      machine.succeed(f"grep -q 'Alex' {d}/ops.json")
      machine.succeed(f"test -L {d}/horizon-mods/test_mod.hmod")
      machine.succeed(f"grep -q '^mod.test_mod:true' {d}/horizon-mods.txt")
      machine.succeed(f"test -L {d}/world/datapacks/test")
      machine.succeed("horizon-server-admin config --json | grep -q hard")
    '';
  };
}
// lib.optionalAttrs darwin {
  horizon-darwin-module =
    let
      configuration = inputs.darwin.lib.darwinSystem {
        inherit system;
        modules = [
          self.darwinModules.horizon
          {
            system.stateVersion = 6;
            system.primaryUser = "player";
            users.users.player.home = "/Users/player";
            programs.horizon.enable = true;
            services.horizon-server = {
              enable = true;
              eula = true;
              whitelist = [ "Alex" ];
            };
          }
        ];
      };
    in
    # Evaluation only: the agent's program, without building the server.
    pkgs.writeText "horizon-darwin-module" (
      builtins.unsafeDiscardStringContext (
        builtins.head configuration.config.launchd.user.agents.horizon-server.serviceConfig.ProgramArguments
      )
    );
}
