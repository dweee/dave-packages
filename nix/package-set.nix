{
  inputs,
  final,
  prev,
}:
let
  inherit (prev) lib;
  system = prev.stdenv.hostPlatform.system;
  platforms = builtins.fromJSON (builtins.readFile ./platforms.json);
  definitions = {
    kopuz = inputs.kopuz.packages.${system}.kopuz;
    applesauce = final.callPackage ../pkgs/applesauce { };
    apfs-dedupe = final.callPackage ../pkgs/apfs-dedupe { };
    spank = final.callPackage ../pkgs/spank { };
    wheelwizard = final.callPackage ../pkgs/wheelwizard { };
    cursaves = final.callPackage ../pkgs/cursaves { };
    bitwig-theme-editor = final.callPackage ../pkgs/bitwig-theme-editor { };
    pyrekordbox = final.python3Packages.callPackage ../pkgs/pyrekordbox { };
    mermaid-filter = final.callPackage ../pkgs/mermaid-filter { };
    infrared = final.callPackage ../pkgs/infrared { };
    eel-extension = final.callPackage ../pkgs/eel-extension { };
    slopbro = final.callPackage ../pkgs/slopbro { };
    lg-webos-dashboard = final.callPackage ../pkgs/lg-webos-mqtt { };
    matter-linux-ota-provider = final.callPackage ../pkgs/matter-linux-ota-provider { };
    byparr = final.callPackage ../pkgs/byparr { };
    openghub = final.callPackage ../pkgs/openghub { };
    yaas = final.callPackage ../pkgs/yaas { };
    trawl = final.callPackage ../pkgs/trawl { };
    sable-desktop = final.callPackage ../pkgs/sable-desktop { };
    codexbar-cli = final.callPackage ../pkgs/codexbar/cli.nix { };
    codexbar-plasmoid = final.callPackage ../pkgs/codexbar/plasmoid.nix { };
    photogimp = final.callPackage ../pkgs/photogimp { };
    modcheck = final.callPackage ../pkgs/mcsr/modcheck.nix { };
    paceman-tracker = final.callPackage ../pkgs/mcsr/paceman.nix { };
    waywall = prev.callPackage ../pkgs/mcsr/waywall.nix { inherit (prev) waywall; };
    cartographer = final.callPackage ../pkgs/cartographer {
      inherit (final.linuxPackages) kernel;
      kernelModuleMakeFlags = final.linuxPackages.kernelModuleMakeFlags;
    };
    schildi-revenge = inputs.schildi-revenge.packages.${system}.schildi-revenge;
    slskd-mcp = final.callPackage ../pkgs/slskd-mcp { src = inputs.slskd-mcp; };
    prowlarr-mcp = final.callPackage ../pkgs/prowlarr-mcp { src = inputs.prowlarr-mcp; };
    ghidra-mcp = final.callPackage ../pkgs/ghidra-mcp { src = inputs.ghidra-mcp; };
    gdb-mcp = final.callPackage ../pkgs/gdb-mcp { src = inputs.gdb-mcp; };
    rekordbox-mcp = inputs.rekordbox-mcp.packages.${system}.rekordbox-mcp;
    paneru = inputs.paneru.packages.${system}.paneru;
    paneru-lua = inputs.paneru.packages.${system}.paneru-lua;
    tabrix = inputs.tabrix.packages.${system}.tabrix;
    tabrix-extension = inputs.tabrix.packages.${system}.tabrix-extension;
  };
in
lib.genAttrs (platforms.${system} or [ ]) (name: definitions.${name})
