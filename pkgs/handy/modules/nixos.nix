{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.handy;
in
{
  options.programs.handy = {
    enable = lib.mkEnableOption "Handy offline speech-to-text";

    package = lib.mkOption {
      type = lib.types.package;
      defaultText = lib.literalExpression "dave-packages.packages.\${system}.handy";
      description = "The Handy package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # rdev grab() creates virtual input devices via /dev/uinput.
    # Default permissions are crw------- root root — open it to the input group.
    services.udev.extraRules = ''
      KERNEL=="uinput", GROUP="input", MODE="0660"
    '';
  };
}
