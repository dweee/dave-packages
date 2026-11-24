{
  description = "Dave's portable third-party Nix packages";
  inputs = {
    llama-cpp-inkling = {
      url = "github:ggml-org/llama.cpp/29b52d398b294509746ec0a3f28948a3107c0213";
      flake = false;
    };
    nixpkgs.url = "github:nixos/nixpkgs/2786a2a72088ecf32aea5b3ec52099e6a7cff78f";
    nix-zed-extensions = {
      url = "github:SwornSystems/nix-zed-extensions/174e3c8db102500e006538331fba46d3fc45b543";
      flake = false;
    };
    mcp-nix = {
      url = "github:felixdorn/mcp-nix/d9cfbbf0cb80e1bb55c58b7bbbcab9040dddb560";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.pyproject-build-systems.follows = "pyproject-build-systems";
    };
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix/d43f0e74444c1f266c640fc49ce6ce6fb69d33c3";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix/c361746c7d630d98b972378290547c8d35542a7a";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs/bdbc5f8dd2ad6136bb2ccecb14f6ec343965b194";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };
    handy-src = {
      url = "github:cjpais/Handy/f2483011d60fccab639d3c33f40b3456e92f2940";
      flake = false;
    };
    # Preserve the toolchain used to build Handy 0.10.0.
    handy-nixpkgs.url = "github:NixOS/nixpkgs/40aa5a0e9ff16a78d4b5d5c39e72f0382cb44061";
    bun2nix = {
      url = "github:nix-community/bun2nix/c843f477b15f51151f8c6bcc886954699440a6e1";
      inputs.nixpkgs.follows = "handy-nixpkgs";
      # bun2nix 2.0.8 evaluates formatters for all listed systems.
      inputs.systems.url = "github:nix-systems/triplet/6de7bc09397911ce03636afbcf6118745ab2cda0";
    };
    # Preserve the upstream runner toolchain for reproducible cache outputs.
    virby.url = "github:quinneden/virby-nix-darwin/a52216470a97ef5970939acf697a00ec61beb0c6";
    mcp-nixos = {
      url = "github:utensils/mcp-nixos/2b0b86ceda72ec5c5d0d78ac3130ccf024f6a7ff";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Retain the packaging flake's Node/pnpm pin and fixed dependency hashes.
    nixos-jellyfin = {
      url = "github:matt1432/nixos-jellyfin/c93abed0d744ab1a5cd9369ced8e523b8108a9b8";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay/ea2084066e0f3fed86a76a2654658ed2eb998046";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pumpkin-nixpkgs.url = "github:NixOS/nixpkgs/ce9fc27f80cee11ec0c9a8e7723fe680bd5ec7f8";
    audio = {
      url = "github:polygon/audio.nix/3da0962c21f0de2559fb5185a9fd4e10fc9ae326";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-avf = {
      url = "github:nix-community/nixos-avf/d0a62c3f64b45a39570fde31a3a490b214bf19ee";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/920a3823872b21640181fe8065a5fb35fcb06e3f";
    darwin = {
      url = "github:nix-darwin/nix-darwin/663d8b962a11cda261b6e9f14e03911fac94baf0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kopuz = {
      url = "git+https://github.com/dweee/kopuz.git?ref=tested&rev=444343ce12587234c17026cc32390525ed852b17";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    paneru = {
      url = "git+https://github.com/dweee/paneru.git?ref=tested&rev=5b578859f18e9832978f9147ea12240560ddc2bb";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-darwin.follows = "darwin";
    };
    # Match the standalone native workflow instead of overriding its toolchain.
    tabrix = {
      url = "git+https://github.com/dweee/tabrix.git?ref=tested&rev=d247b03664254b787a5d478adcf8883da358dac9";
    };
    rekordbox-mcp = {
      url = "git+https://github.com/dweee/rekordbox-mcp.git?ref=tested&rev=9e4562e2150048b44f4b2d96d435a2b77f4f01a3";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kuna-src = {
      url = "github:Noelo-Lab/kuna/9ce03fa874c298db4dc284da1bed54c6b7348d8f";
      flake = false;
    };
    schildi-revenge = {
      url = "git+https://github.com/dweee/schildi-revenge.git?ref=tested&rev=f79fee114e2fe66dfa180c346f8d1d195f13310b&submodules=1";
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
      url = "github:bethington/ghidra-mcp/a57b56d71fffd5ea2560625521246014518575a7";
      flake = false;
    };
    # Jellarr's own flake: consumers take its NixOS module from this same pin.
    jellarr = {
      url = "github:venkyr77/jellarr/de530bc0117eb4018598a67245e748623a6ce6dc";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wiicompiled = {
      url = "git+https://github.com/patchzyy/Wiicompiled.git?ref=main&rev=6e41ad0495e9bb6e7c85817392ffc9a6711c38f9&submodules=1";
      flake = false;
    };
    hookshot-src = {
      url = "git+https://github.com/ItsNotRexed/Hookshot.git?ref=main&rev=38b90dfe70abcd9e9a9c09d17b70808c16f0153d";
      flake = false;
    };
    mkw-recomp-src = {
      url = "github:adriadam10/mkw-recomp/a10de49f2e2ea1badbb898ee1a249df4e24213a7";
      flake = false;
    };
    # Swift and SwiftPM 6.2.4+ are required by Pared.
    pared-nixpkgs.url = "github:NixOS/nixpkgs/04906337b6d53e8bb0eaf0470ae9f070a4d4eb55";
    pared = {
      url = "github:4evy/pared/26c34ec7df3d39924650b852e8d8aab57874e9ee";
      inputs.nixpkgs.follows = "pared-nixpkgs";
    };
    patchbay-src = {
      url = "github:shaboogen-dev/Patchbay/b3c88526599eb680dee25050070cbcaa38b3eab1";
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
      buildOnlyPackages = builtins.fromJSON (builtins.readFile ./nix/build-only-packages.json);
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
      handyModule =
        namespace: module:
        { lib, pkgs, ... }:
        {
          imports = [ module ];
          ${namespace}.handy.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.handy;
        };
      patchbayModule =
        module:
        { lib, pkgs, ... }:
        {
          imports = [ module ];
          programs.patchbay.package = lib.mkDefault (
            pkgs.patchbay or self.packages.${pkgs.stdenv.hostPlatform.system}.patchbay
          );
        };
      # Packages, Horizon modules and checks share the same pure package set.
      # A plain function would rebuild the bootstrap/fixed point on every call.
      pkgsBySystem = nixpkgs.lib.genAttrs systems (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = false;
          overlays = [ overlay ];
        }
      );
      pkgsFor = system: pkgsBySystem.${system};
    in
    {
      overlays.default = overlay;
      overlays.freebsd-desktop = import ./nix/freebsd-desktop.nix;
      overlays.freebsd-server = import ./nix/freebsd-server.nix;
      # Mopidy 4 and its extensions (nix/mopidy-4.nix), including mopidyPackages,
      # for consumers that build Mopidy environments from their own package set.
      overlays.mopidy-4 = import ./nix/mopidy-4.nix;
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
      nixosModules.hookshot = import ./pkgs/hookshot/modules/nixos.nix self;
      homeManagerModules.hookshot = import ./pkgs/hookshot/modules/home-manager.nix self;
      darwinModules.hookshot = import ./pkgs/hookshot/modules/darwin.nix self;
      nixosModules.mkw-recomp = import ./pkgs/mkw-recomp/modules/nixos.nix self;
      homeManagerModules.mkw-recomp = import ./pkgs/mkw-recomp/modules/home-manager.nix self;
      darwinModules.mkw-recomp = import ./pkgs/mkw-recomp/modules/darwin.nix self;
      lib.trimCodexDesktop =
        pkgs: package: pkgs.callPackage ./pkgs/codex-desktop { codex-desktop = package; };
      lib.wiicompiled = import ./pkgs/wiicompiled/recipes.nix;
      nixosModules.wiicompiled = import ./pkgs/wiicompiled/module.nix {
        inherit overlay;
        publicPackages = self.packages;
      };
      homeManagerModules.wiicompiled = import ./pkgs/wiicompiled/hm-module.nix {
        inherit overlay;
        publicPackages = self.packages;
      };
      darwinModules.wiicompiled = import ./pkgs/wiicompiled/darwin-module.nix {
        inherit overlay;
        publicPackages = self.packages;
      };
      nixosModules.android-avf-kernel-patches = import ./nix/android-avf/kernel-patches.nix;
      # Horizon (pkgs/horizon/README.md): the launcher, the game and a server.
      nixosModules.horizon = horizonModule ./pkgs/horizon/modules/nixos.nix;
      darwinModules.horizon = horizonModule ./pkgs/horizon/modules/darwin.nix;
      homeManagerModules.horizon = horizonModule ./pkgs/horizon/modules/home-manager.nix;
      nixosModules.handy = handyModule "programs" ./pkgs/handy/modules/nixos.nix;
      darwinModules.handy = handyModule "programs" ./pkgs/handy/modules/darwin.nix;
      homeManagerModules.handy = handyModule "services" ./pkgs/handy/modules/home-manager.nix;
      nixosModules.patchbay = patchbayModule ./pkgs/patchbay/modules/system.nix;
      darwinModules.patchbay = patchbayModule ./pkgs/patchbay/modules/system.nix;
      homeManagerModules.patchbay = patchbayModule ./pkgs/patchbay/modules/home-manager.nix;
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
        removeAttrs self.packages.${system} (buildOnlyPackages.${system} or [ ])
        // {
          freebsd-overlays = import ./nix/freebsd-overlays-check.nix { pkgs = pkgsFor system; };
          kuna-ghidra-headless = (pkgsFor system).callPackage ./pkgs/ghidra-kuna/smoke-test.nix { };
          rea-ghidra-headless = (pkgsFor system).callPackage ./pkgs/ghidra-kuna/smoke-test.nix {
            ghidra-kuna = (pkgsFor system).rea-kuna.ghidra-kuna;
            openjdk25 = (pkgsFor system).jdk21;
          };
        }
        // nixpkgs.lib.optionalAttrs (self.packages.${system} ? hookshot) {
          hookshot-prerequisites = (pkgsFor system).callPackage ./pkgs/hookshot/checks.nix { };
        }
        // nixpkgs.lib.optionalAttrs (self.packages.${system} ? mkw-recomp) (
          import ./pkgs/mkw-recomp/checks.nix {
            inherit self nixpkgs;
            pkgs = pkgsFor system;
          }
        )
        // {
          pared-activation = (pkgsFor system).callPackage ./pkgs/pared/activation-check.nix {
            source = inputs.pared.outPath;
          };
        }
        // import ./pkgs/horizon/checks.nix {
          inherit self inputs system;
          pkgs = pkgsFor system;
        }
        // (
          let
            mcpStdioSmoke = (pkgsFor system).callPackage ./nix/mcp-stdio-smoke.nix { };
            available = name: self.packages.${system} ? ${name};
          in
          nixpkgs.lib.optionalAttrs (available "gdb-mcp") {
            gdb-mcp-stdio = mcpStdioSmoke {
              package = self.packages.${system}.gdb-mcp;
              tools = [
                "dbg_start"
                "dbg_terminate"
                "dbg_raw_command"
              ];
            };
          }
          // nixpkgs.lib.optionalAttrs (available "ghidra-mcp") {
            ghidra-mcp-compatibility = (pkgsFor system).callPackage ./pkgs/ghidra-mcp/compatibility-test.nix {
              extension = self.packages.${system}.ghidra-mcp.extension;
            };
            ghidra-mcp-stdio = mcpStdioSmoke {
              package = self.packages.${system}.ghidra-mcp;
              # Static tools only; schema tools need a running Ghidra.
              tools = [
                "connect_instance"
                "list_instances"
                "import_file"
              ];
            };
          }
        )
      );
      devShells.x86_64-linux.package-updates =
        let
          pkgs = pkgsFor "x86_64-linux";
        in
        pkgs.mkShell {
          packages = [
            pkgs.git
            pkgs.gh
            pkgs.python3
            # nix-update 1.16 reads metadata.path with legacy Nix commands.
            # Nix 2.35 metadata may name a Git source that is not materialized;
            # prefetch copies it before nix-instantiate/nix-build consume it.
            (pkgs.nix-update.overrideAttrs (old: {
              postPatch = (old.postPatch or "") + ''
                substituteInPlace nix_update/options.py \
                  --replace-fail '["nix", "flake", "metadata", "--json"]' \
                  '["nix", "flake", "prefetch", "--json", "."]' \
                  --replace-fail 'metadata.get("path")' 'metadata.get("storePath")'
              '';
            }))
            pkgs.nix-prefetch-git
            pkgs.yq-go
          ];
        };
      formatter = nixpkgs.lib.genAttrs systems (system: (pkgsFor system).nixfmt);
    };
}
