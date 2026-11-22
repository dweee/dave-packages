catalog:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  common = import ./module-common.nix {
    inherit
      catalog
      lib
      pkgs
      config
      ;
  };
  cfg = common.cfg;
in
{
  options.programs.wiicompiled = import ./options.nix { inherit lib; };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      nixpkgs.overlays = [ common.overlay ];
      environment.systemPackages = common.wiiPackages;
      assertions = common.assertions;
    })
    (lib.mkIf (cfg.enable && cfg.enableGame) {
      services.udev.packages = lib.mkAfter [ pkgs.dolphin-emu ];
      systemd.tmpfiles.rules =
        let
          ccacheDir = import ./pkgs/ccache-dir.nix;
        in
        [ "d ${ccacheDir.path} ${ccacheDir.mode} ${ccacheDir.owner} ${ccacheDir.group} -" ];
      nix.settings.extra-sandbox-paths = [ (import ./pkgs/ccache-dir.nix).path ];
    })
  ];
}
