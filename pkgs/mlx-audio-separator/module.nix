{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.mlx-audio-separator;
  supported = pkgs.stdenv.hostPlatform.system == "aarch64-darwin";
in {
  options.programs.mlx-audio-separator = {
    enable = lib.mkEnableOption "MLX-native audio stem separation on Apple Silicon";
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default =
        if supported
        then pkgs.mlx-audio-separator
        else null;
      defaultText = lib.literalExpression "pkgs.mlx-audio-separator on aarch64-darwin, null elsewhere";
      example = lib.literalExpression "pkgs.mlx-audio-separator";
      description = "MLX separator package to install.";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = supported && cfg.package != null;
        message = "programs.mlx-audio-separator requires Apple Silicon macOS and a package.";
      }
    ];
    home.packages = lib.optional (cfg.package != null) cfg.package;
  };
}
