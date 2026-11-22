# NixOS: Hookshot's system side. The package (the builder, its compiler and the Vulkan back end), graphics, and the
# udmabuf device the game imports GPU memory through (the readme's "On Linux": fast imports on AMD/RADV).
#
# Building and playing are per user: the Home Manager module (homeManagerModules.hookshot), or `hookshot-build` and
# `hookshot` by hand. Nothing made from the game is put in the Nix store.
self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.hookshot;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    mkDefault
    types
    ;
in
{
  options.programs.hookshot = {
    enable = mkEnableOption "Hookshot, the Ocarina of Time (Switch 2) recompilation built from your own copy";

    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.hookshot;
      defaultText = lib.literalExpression "hookshot.packages.\${pkgs.stdenv.hostPlatform.system}.hookshot";
      description = "The Hookshot builder package (`hookshot-build`, `hookshot`, `hookshot-builder`).";
    };

    installPackage = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to put the package in `environment.systemPackages`. Turn off when every user gets it from the Home
        Manager module instead (that one sets the game folder and the dump for its launcher).
      '';
    };

    udmabuf = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Load the `udmabuf` kernel module and give access to `/dev/udmabuf`, which the game uses for fast GPU memory
          imports. Without it the game falls back to host-pointer imports, which can be much slower on AMD/RADV
          (NVIDIA's own driver does not use it).
        '';
      };
      group = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "udmabuf";
        description = ''
          `null`: the active local desktop session gets access (systemd-logind `uaccess`), the readme's preferred rule.
          A group name: that group (created here) gets read/write access instead, for SSH or service users; add the
          players to it with `users.users.<name>.extraGroups`. Do not use a group that grants other devices (`kvm`).
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
        message = "programs.hookshot: Hookshot builds for x86_64-linux only.";
      }
    ];

    environment.systemPackages = lib.optional cfg.installPackage cfg.package;

    # Vulkan 1.3 with mesh shaders, through the system's driver (/run/opengl-driver)
    hardware.graphics.enable = mkDefault true;

    boot.kernelModules = lib.optional cfg.udmabuf.enable "udmabuf";
    users.groups = lib.optionalAttrs (cfg.udmabuf.enable && cfg.udmabuf.group != null) {
      ${cfg.udmabuf.group} = { };
    };
    # (70-: before 73-seat-late.rules, which turns uaccess tags into ACLs; services.udev.extraRules lands in 99-local)
    services.udev.packages = lib.optional cfg.udmabuf.enable (
      pkgs.writeTextDir "lib/udev/rules.d/70-hookshot-udmabuf.rules" (
        if cfg.udmabuf.group == null then
          ''
            SUBSYSTEM=="misc", KERNEL=="udmabuf", TAG+="uaccess"
          ''
        else
          ''
            SUBSYSTEM=="misc", KERNEL=="udmabuf", GROUP="${cfg.udmabuf.group}", MODE="0660"
          ''
      )
    );
  };
}
