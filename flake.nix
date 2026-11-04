{
  description = "Dave's portable third-party Nix packages";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/1d060086d60cb76a40cf37109f979d88a5bd6396";
    nix-zed-extensions = {
      url = "github:SwornSystems/nix-zed-extensions/8aba0ab32a726cb9ee228123c9ef4c4f967e79b5";
      flake = false;
    };
    mcp-nix = {
      url = "github:felixdorn/mcp-nix/01302a8ea726c59d521c194937ea9bb5c803d25a";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.pyproject-build-systems.follows = "pyproject-build-systems";
    };
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix/bf7d4b1d6de61db02fd4e748395634f03006e5de";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix/c361746c7d630d98b972378290547c8d35542a7a";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs/461a6a8540307fb9c05b8f6ad29e9720d2a621db";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };
    # Retain native fork toolchains so catalog updates reuse their CI outputs.
    handy = {
      url = "github:dweee/Handy/d5f4c5b5bfdda3a58a6512fc7331ff40bc18facd";
    };
    # Preserve the upstream runner toolchain for reproducible cache outputs.
    virby.url = "github:quinneden/virby-nix-darwin/a52216470a97ef5970939acf697a00ec61beb0c6";
    mcp-nixos = {
      url = "github:utensils/mcp-nixos/2e88096695bef9c41c5fa9157211d52a45d9a913";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Retain the packaging flake's Node/pnpm pin and fixed dependency hashes.
    t3-code.url = "github:LisaScheers/t3-code-nix/a63a7a785b9ad73e160c6782b3042e6eefa4d098";
    nixos-jellyfin = {
      url = "github:matt1432/nixos-jellyfin/ad9153c014bfa35d627aa9b692e2b5bd63e993f2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay/7fcafdf6f0761462d68012aba6a627be3f008d68";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pumpkin-nixpkgs.url = "github:NixOS/nixpkgs/feb1bf872d5309565fe94a7dc31a47aaf861a915";
    audio = {
      url = "github:polygon/audio.nix/3da0962c21f0de2559fb5185a9fd4e10fc9ae326";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-avf = {
      url = "github:nix-community/nixos-avf/d0a62c3f64b45a39570fde31a3a490b214bf19ee";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/f20c85dac2eef06564ebc27729264f4f75ae7e1c";
    darwin = {
      url = "github:nix-darwin/nix-darwin/ff0e21a414d4547183396da1b44a66f2577b65e9";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kopuz = {
      url = "git+https://github.com/dweee/kopuz.git?ref=tested&rev=8a8ea7b8111100b655c53b386f9a868cdae0900e";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    paneru = {
      url = "git+https://github.com/dweee/paneru.git?ref=tested&rev=4e1e4f144fe980dd55a8755e63886150e2ba4cbf";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-darwin.follows = "darwin";
    };
    # Match the standalone native workflow instead of overriding its toolchain.
    tabrix = { url = "git+https://github.com/dweee/tabrix.git?ref=tested&rev=90bd73baf5fafdebb2cc0fa31c0cd26002600578"; };
    rekordbox-mcp = {
      url = "git+https://github.com/dweee/rekordbox-mcp.git?ref=tested&rev=dc3e239ee37b1830c621b1141eee25ddd53646f6";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kuna = {
      url = "github:dweee/kuna/6df1a5c3de87d61968db89df1201fd722d62ef3c";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    schildi-revenge = {
      url = "git+https://github.com/dweee/schildi-revenge.git?ref=tested&rev=a01cf51d1796c0c3883ac5c770af430b45a3c840&submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    slskd-mcp = {
      url = "github:abl030/slskd-mcp/08e4373f41fddcceff8ea3240323e0c6258a373e";
      flake = false;
    };
    prowlarr-mcp = {
      url = "github:arr-mcps/prowlarr-mcp/e83c2300b157e87850c3bac056be6985ab245c3b";
      flake = false;
    };
    ghidra-mcp = {
      url = "github:bethington/ghidra-mcp/8cd2078e10b9ba28b188cb84ce5b9051a904b995";
      flake = false;
    };
    gdb-mcp = {
      url = "github:birdeclipse/gdb-mcp/8ea9afb62a94e3942e50ee5d850c7cad2c7df6b7";
      flake = false;
    };
  };
  outputs =
    inputs@{ self, nixpkgs, ... }:
    # GitHub builders must never need the private fleet's source credentials.
    assert builtins.all (
      node: builtins.match ".*git[.]monke[.]fail.*" (node.locked.url or "") == null
    ) (builtins.attrValues (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes);
    let
      platforms = builtins.fromJSON (builtins.readFile ./nix/platforms.json);
      systems = builtins.attrNames platforms;
      cacheOnlyPlatforms = builtins.fromJSON (builtins.readFile ./nix/cache-only-platforms.json);
      packageOverlay = final: prev: import ./nix/package-set.nix { inherit inputs final prev; };
      overlay = nixpkgs.lib.composeManyExtensions [
        inputs.rust-overlay.overlays.default
        (import ./nix/xorg-compat.nix)
        packageOverlay
      ];
      # The modules choose from the catalog's own Horizon builds, so a host gets
      # the binary cache's outputs; pkgs.horizonPackages (the overlay) or
      # horizon.packageSet still override them.
      horizonModule =
        module:
        { lib, pkgs, ... }:
        {
          imports = [ module ];
          horizon.packageSet = lib.mkOverride 1100 (
            pkgs.horizonPackages or self.legacyPackages.${pkgs.stdenv.hostPlatform.system}.horizonPackages
          );
        };
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = false;
          overlays = [ overlay ];
        };
    in
    {
      overlays.default = overlay;
      # Deliberately excluded from packages/checks and every public artifact matrix.
      # Only the trusted cache-only workflow evaluates these unfree closures.
      cacheOnlyPackages = nixpkgs.lib.genAttrs systems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ overlay ];
          };
          definitions = import ./nix/cache-only-packages.nix { inherit pkgs; };
        in
        nixpkgs.lib.genAttrs (cacheOnlyPlatforms.${system} or [ ]) (name: definitions.${name})
      );
      nixosModules.android-avf-kernel-patches = import ./nix/android-avf/kernel-patches.nix;
      # Horizon (pkgs/horizon/README.md): the launcher, the game and a server.
      nixosModules.horizon = horizonModule ./pkgs/horizon/modules/nixos.nix;
      darwinModules.horizon = horizonModule ./pkgs/horizon/modules/darwin.nix;
      homeManagerModules.horizon = horizonModule ./pkgs/horizon/modules/home-manager.nix;
      # Every Horizon channel and variant, built as `packages` are.
      legacyPackages = nixpkgs.lib.genAttrs systems (system: {
        inherit ((pkgsFor system)) horizonPackages;
      });

      packages = nixpkgs.lib.genAttrs systems (
        system:
        let
          pkgs = pkgsFor system;
        in
        nixpkgs.lib.genAttrs platforms.${system} (name: pkgs.${name})
      );
      checks = nixpkgs.lib.genAttrs systems (
        system:
        self.packages.${system}
        // {
          kuna-ghidra-headless = (pkgsFor system).callPackage ./pkgs/ghidra-kuna/smoke-test.nix { };
        }
        // import ./pkgs/horizon/checks.nix {
          inherit self inputs system;
          pkgs = pkgsFor system;
        }
      );
      formatter = nixpkgs.lib.genAttrs systems (system: (pkgsFor system).nixfmt);
    };
}
