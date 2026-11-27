# Check the setup layout and evaluate the NixOS module. Nothing here needs the game or a GPU (`mkw --selftest`
# needs the game set up, so it is not one of them).
{
  self,
  nixpkgs,
  pkgs,
}:
let
  inherit (pkgs) lib;
  nixos = nixpkgs.lib.nixosSystem {
    inherit (pkgs.stdenv.hostPlatform) system;
    modules = [
      self.nixosModules.mkw-recomp
      {
        programs.mkw-recomp.enable = true;
        boot.loader.grub.enable = false;
        fileSystems."/" = {
          device = "none";
          fsType = "tmpfs";
        };
        system.stateVersion = "26.05";
      }
    ];
  };
in
{
  # the setup's tools where machine.py and launcher_setup.cpp look for them
  mkw-recomp-setup-layout = pkgs.runCommand "mkw-recomp-setup-layout" { } ''
    s=${pkgs.mkw-recomp}/share/mkw-recomp/setup
    $s/python/bin/python3 -I -c 'import numpy, lz4'
    $s/python/bin/python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import game_fonts' "$s/src/tools/i18n"
    test -f $s/src/tools/prepare/prepare.py
    test -f $s/zig/lib/std/std.zig
    $s/zig/zig version
    $s/glslc/bin/glslc --version
    $s/glslc/bin/glslangValidator --version
    test -x "$s/glslc/bin/spirv-cross"
    $s/glslc/bin/spirv-opt --version
    $s/glslc/bin/spirv-val --version
    test -f $s/glslc/lib/libshaderc_shared.so.1
    touch $out
  '';

  mkw-recomp-nixos-module = pkgs.runCommand "mkw-recomp-nixos-module" { } ''
    grep -q 2069 ${
      pkgs.symlinkJoin {
        name = "udev-rules";
        paths = nixos.config.services.udev.packages;
      }
    }/lib/udev/rules.d/70-mkw-recomp-switch2.rules
    echo ${
      lib.escapeShellArg (toString (map (p: p.name) nixos.config.environment.systemPackages))
    } | grep -q mkw-recomp
    touch $out
  '';
}
