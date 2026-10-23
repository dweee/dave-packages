{ inputs, final, prev, }:
let
  inherit (prev) lib;
  system = prev.stdenv.hostPlatform.system;
  platforms = builtins.fromJSON (builtins.readFile ./platforms.json);
  t3code = import ../pkgs/t3code { inherit inputs system; };
  fixes = import ./host-fixes.nix final prev;
  mopidy = import ./mopidy-4.nix final prev;
  wii =
    import ../pkgs/wiicompiled/source/nix/overlay.nix ../pkgs/wiicompiled/source
    final prev;
  avfSystem = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules =
      [ inputs.nixos-avf.nixosModules.avf ./android-avf/kernel-patches.nix ];
  };
  cachyos =
    (prev.extend inputs.nix-cachyos-kernel.overlays.pinned).cachyosKernels;
  definitions = {
    virby-vm-runner = inputs.virby.packages.${system}.vm-runner;
    ha-mcp = prev.callPackage ../pkgs/ha-mcp { inherit (prev) ha-mcp; };
    atuin = prev.callPackage ../pkgs/atuin { inherit (prev) atuin; };
    handy = inputs.handy.packages.${system}.handy;
    mcp-nixos = import ../pkgs/mcp-nixos {
      pkgs = final;
      upstream = inputs.mcp-nixos;
    };
    inherit (t3code) t3code-nightly t3code-server-nightly;
    chow-phaser = final.callPackage "${inputs.audio}/chow/chow-phaser.nix" { };
    chow-centaur =
      final.callPackage "${inputs.audio}/chow/chow-centaur.nix" { };
    chow-kick =
      (final.callPackage "${inputs.audio}/chow/chow-kick.nix" { }).overrideAttrs
      (old: {
        patches = (old.patches or [ ])
          ++ [ ../pkgs/chow/rectangle-dimensions.patch ];
        # The pinned chowdsp_wdf subproject still declares CMake 3.1 policies.
        cmakeFlags = (old.cmakeFlags or [ ])
          ++ [ "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" ];
      });
    chow-tape-model =
      (final.callPackage "${inputs.audio}/chow/chow-tape-model.nix"
        { }).overrideAttrs (old: {
          # The bundled RTNeural still declares CMake 3.1 policies.
          cmakeFlags = (old.cmakeFlags or [ ])
            ++ [ "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" ];
          # Backport JUCE ce8aff22c31c4d932a8414bc6f6185381dc970db for std::exchange.
          postPatch = (old.postPatch or "") + ''
            substituteInPlace modules/JUCE/modules/juce_core/system/juce_StandardHeader.h \
              --replace-fail '#include <unordered_set>' $'#include <unordered_set>\n#include <utility>'
          '';
        });
    chow-multitool =
      (final.callPackage "${inputs.audio}/chow/chow-multitool.nix"
        { }).overrideAttrs (old: {
          patches = (old.patches or [ ])
            ++ [ ../pkgs/chow/rectangle-dimensions.patch ];
          cmakeFlags = (old.cmakeFlags or [ ])
            ++ [ "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" ];
        });
    papu = final.callPackage "${inputs.audio}/vst/papu.nix" { };
    paulxstretch = final.callPackage "${inputs.audio}/vst/paulxstretch.nix" { };

    inherit (fixes) redlib dorion;
    jetbrains-jdk-patched = prev.jetbrains.jdk-no-jcef-21.overrideAttrs (old: {
      patches = (old.patches or [ ])
        ++ [ ../pkgs/keyguard/jdk-8312488-jpackage-exit-crash.patch ];
      preBuild = (old.preBuild or "") + ''
        configureFlags+=("--with-jobs=''${NIX_BUILD_CORES}")
      '';
    });
    sable = inputs.sable.packages.${system}.sable;
    sable-web = inputs.sable.packages.${system}.sable-web;
    homeassistant-base =
      prev.home-assistant.overrideAttrs (_: { doInstallCheck = false; });
    homeassistant = import ../pkgs/homeassistant/package.nix { pkgs = prev; };
    # Publish build tools separately from the extensions that use them.
    zed-rust-toolchain = final.cargo-auditable-cargo-wrapper.override {
      cargo = final.rust-bin.stable.latest.minimal.override {
        targets = [ "wasm32-wasip2" ];
      };
    };
    wasi-sdk =
      prev.callPackage "${inputs.nix-zed-extensions}/pkgs/wasi-sdk" { };
    mcp-nix = inputs.mcp-nix.packages.${system}.default;
    zed-nix-extension = import ../pkgs/zed-nix-extension {
      pkgs = final;
      inherit inputs;
    };
    tauon = final.callPackage ../pkgs/tauon-darwin.nix { };
    splayer-next = final.callPackage ../pkgs/splayer-next-darwin { };
    spotatui = final.callPackage ../pkgs/spotatui { };
    t3code = t3code.t3code-nightly;
    jellyfin-web =
      inputs.nixos-jellyfin.packages.${system}.jellyfin-web.override {
        forceEnableBackdrops = true;
        forceDisablePreferFmp4 = true;
      };
    caddy-custom = prev.caddy.withPlugins {
      plugins = [
        "github.com/caddyserver/transform-encoder@v0.0.0-20260417205707-a6a89df4bc65"
        "github.com/caddy-dns/porkbun@v0.3.1"
        "github.com/mholt/caddy-webdav@v0.0.0-20260127042217-fa2f366b0d75"
        "github.com/caddy-dns/njalla@v0.0.0-20250823094507-f709141f1fe6"
        "github.com/tailscale/caddy-tailscale@v0.0.0-20260106222316-bb080c4414ac"
        "github.com/caddyserver/cache-handler@v0.16.0"
        "github.com/darkweak/storages/simplefs/caddy@v0.0.19"
      ];
      hash = "sha256-8e0cAIe8TWc1xLPzt02gXIC/xTPAs9jMeLMG62z4aUc=";
    };
    matrix-tuwunel = final.callPackage ../pkgs/matrix-tuwunel {
      inherit (prev) matrix-tuwunel;
    };
    mlx-audio-separator = final.callPackage ../pkgs/mlx-audio-separator { };
    pumpkin = inputs.pumpkin-nixpkgs.legacyPackages.${system}.pumpkin;
    pumpkin-voice = final.callPackage ../pkgs/pumpkin-voice/nix/package.nix { };
    pumpkin-tpsbar =
      final.callPackage ../pkgs/pumpkin-tpsbar/nix/package.nix { };
    pumpkin-java-multiversion =
      final.callPackage ../pkgs/pumpkin-java-multiversion/nix/package.nix { };
    linux-android-avf = avfSystem.config.boot.kernelPackages.kernel;
    linux-cachyos-server = cachyos.linuxPackages-cachyos-server.kernel;
    inherit (wii)
      wiicompiled-native-prebuilt wiicompiled-translator wiicompiled-setup;
    wiicompiled-nodtool = wii.wiicompiled-nodtool;
    wiicompiled-setup-unwrapped = wii.wiicompiled-setup.setupUnwrapped;

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
    matter-linux-ota-provider =
      final.callPackage ../pkgs/matter-linux-ota-provider { };
    byparr = final.callPackage ../pkgs/byparr { };
    openghub = final.callPackage ../pkgs/openghub { };
    yaas = final.callPackage ../pkgs/yaas { };
    trawl = final.callPackage ../pkgs/trawl { };
    sable-desktop = final.callPackage ../pkgs/sable-desktop { };
    sable-desktop-legacy = final.callPackage ../pkgs/sable-desktop-legacy { };
    codexbar-cli = final.callPackage ../pkgs/codexbar/cli.nix { };
    codexbar-plasmoid = final.callPackage ../pkgs/codexbar/plasmoid.nix { };
    photogimp = final.callPackage ../pkgs/photogimp { };
    modcheck = final.callPackage ../pkgs/mcsr/modcheck.nix { };
    paceman-tracker = final.callPackage ../pkgs/mcsr/paceman.nix { };
    waywall =
      prev.callPackage ../pkgs/mcsr/waywall.nix { inherit (prev) waywall; };
    cartographer = final.callPackage ../pkgs/cartographer {
      inherit (final.linuxPackages) kernel;
      kernelModuleMakeFlags = final.linuxPackages.kernelModuleMakeFlags;
    };
    schildi-revenge = inputs.schildi-revenge.packages.${system}.schildi-revenge;
    slskd-mcp = final.callPackage ../pkgs/slskd-mcp { src = inputs.slskd-mcp; };
    prowlarr-mcp =
      final.callPackage ../pkgs/prowlarr-mcp { src = inputs.prowlarr-mcp; };
    ghidra-mcp =
      final.callPackage ../pkgs/ghidra-mcp { src = inputs.ghidra-mcp; };
    kuna = inputs.kuna.packages.${system}.kuna;
    rea = final.callPackage ../pkgs/rea { };
    ghidra-kuna = final.callPackage ../pkgs/ghidra-kuna { };
    rea-kuna = final.callPackage ../pkgs/rea-kuna { };
    gdb-mcp = final.callPackage ../pkgs/gdb-mcp { src = inputs.gdb-mcp; };
    rekordbox-mcp = inputs.rekordbox-mcp.packages.${system}.rekordbox-mcp;
    paneru = inputs.paneru.packages.${system}.paneru;
    paneru-lua = inputs.paneru.packages.${system}.paneru-lua;
    tabrix = inputs.tabrix.packages.${system}.tabrix;
    tabrix-extension = inputs.tabrix.packages.${system}.tabrix-extension;
  };
in lib.genAttrs (platforms.${system} or [ ]) (name:
  if builtins.hasAttr name definitions then
    definitions.${name}
  else if builtins.hasAttr name mopidy then
    mopidy.${name}
  else
    prev.${name})

// {
  wiicompiled-nodtool = wii.wiicompiled-nodtool;
} // lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
  inherit (fixes) spotify;
}
