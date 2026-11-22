# NixOS module: programs.mkw-recomp. Installs the start screen (nix/package.nix), lets the logged-in user open the
# Switch 2 controllers over USB, and makes sure Vulkan drivers are there. The game itself is not built here: the
# start screen's setup builds it from the player's own copy into their data folder (nix/README.md).
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
    mkDefault
    types
    literalExpression
    ;
in
{
  options.programs.mkw-recomp = {
    enable = mkEnableOption "mkw-recomp, the native recompilation of Mario Kart World (needs your own dump)";

    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.mkw-recomp;
      defaultText = literalExpression "mkw-recomp.packages.\${system}.mkw-recomp";
      description = ''
        The mkw-recomp package. By default the setup downloads NVIDIA's nvdisasm and ptxas at runtime.
        Enable `programs.nix-ld` to run those binaries on NixOS, or use the overlay with a package set
        that allows `mkw-recomp-nvidia-tools` and set `pkgs.mkw-recomp.override { withNvidiaTools = true; }`.
      '';
    };

    controllers.udev = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Give the logged-in user access (`uaccess`) to the Switch 2 Pro Controller, Joy-Con 2 and GameCube
        controller over USB. Their second USB interface needs a command before they report input
        (README.md "Switch 2 controllers"), which SDL3 sends through usbfs; without access only Bluetooth works.
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # Vulkan 1.3 (README.md "Requirements"); the runtime finds the drivers in /run/opengl-driver
    hardware.graphics.enable = mkDefault true;

    # USB ids from README.md "Switch 2 controllers over USB": 2069 Pro Controller, 2066/2067 Joy-Con R/L, 2073 GameCube
    services.udev.packages = mkIf cfg.controllers.udev [
      (pkgs.writeTextDir "lib/udev/rules.d/70-mkw-recomp-switch2.rules" ''
        # mkw-recomp (nix/modules/nixos.nix): Switch 2 controllers for the logged-in user
        SUBSYSTEM=="usb", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="2066|2067|2069|2073", TAG+="uaccess"
        KERNEL=="hidraw*", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="2066|2067|2069|2073", TAG+="uaccess"
      '')
    ];

    # The write watch (runtime/platform/linux_mem.c) opens userfaultfd with UFFD_USER_MODE_ONLY, which
    # vm.unprivileged_userfaultfd = 0 (the default) still allows: no sysctl needed.
  };
}
