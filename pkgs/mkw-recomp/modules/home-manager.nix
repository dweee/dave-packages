# Home Manager module: programs.mkw-recomp. Installs the start screen for one user, with its desktop entry, and
# optionally another data folder and MKW_* switches baked into the launcher. The data folder holds what the setup
# builds from the player's dump (the game library, SPIR-V, saves, settings, caches), so it is never managed by Nix:
# the start screen writes its own mkw.ini there.
self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.mkw-recomp;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    literalExpression
    ;
  defaultDataDir = "${config.xdg.dataHome}/mkw-recomp";

  # the launcher with dataDir and environment set; desktop entry and icon come with it from the package
  wrapped =
    if cfg.dataDir == defaultDataDir && cfg.environment == { } then
      cfg.package
    else
      pkgs.symlinkJoin {
        name = "${cfg.package.name}-wrapped";
        paths = [ cfg.package ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          rm $out/bin/mkw-recomp
          makeWrapper ${lib.getExe cfg.package} $out/bin/mkw-recomp \
            --set-default MKW_RECOMP_HOME ${lib.escapeShellArg cfg.dataDir} \
            ${lib.concatStringsSep " " (
              lib.mapAttrsToList (
                k: v: "--set-default ${lib.escapeShellArg k} ${lib.escapeShellArg (toString v)}"
              ) cfg.environment
            )}
        '';
        inherit (cfg.package) meta;
      };
in
{
  options.programs.mkw-recomp = {
    enable = mkEnableOption "mkw-recomp, the native recompilation of Mario Kart World (needs your own dump)";

    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.mkw-recomp;
      defaultText = literalExpression "mkw-recomp.packages.\${system}.mkw-recomp";
      description = "The mkw-recomp package.";
    };

    dataDir = mkOption {
      type = types.str;
      default = defaultDataDir;
      defaultText = literalExpression ''"''${config.xdg.dataHome}/mkw-recomp"'';
      example = "/mnt/games/mkw-recomp";
      description = ''
        Where the runtime runs from and the setup builds the game (about 1.1 GB with the RomFS read from the
        dump in place, plus the dump's size with it copied out). The start screen's "Choose game folder" can still pick another installation.
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
      example = literalExpression "{ MKW_MESH_COMPUTE = 1; }";
      description = ''
        `MKW_*` switches the launcher starts the runtime with, unless already set in the environment.
        `uv run tools/run/envs.py` in the repository lists them. Settings the player sees belong in the start
        screen instead.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isLinux;
        message = "programs.mkw-recomp: only Linux is supported for now (the runtime has no macOS platform layer).";
      }
    ];
    home.packages = [ wrapped ];
  };
}
