{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.stemlab;
in {
  options.programs.stemlab = {
    enable = lib.mkEnableOption "StemLab local music stem separation";
    package = lib.mkPackageOption pkgs "stemlab" {};
  };
  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];
  };
}
