{
  description = "Dave's portable third-party Nix packages";
  inputs = {
    llama-cpp-inkling = {
      url = "github:ggml-org/llama.cpp/29b52d398b294509746ec0a3f28948a3107c0213";
      flake = false;
    };
    nixpkgs.url = "github:nixos/nixpkgs/58d0d3e9d527ca7263be6a45d1f86eacdc700dab";
    nix-zed-extensions = {
      url = "github:SwornSystems/nix-zed-extensions/0ca9e9c917b649b074080fec0247c00ee77dd3cd";
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
      url = "github:cjpais/Handy/a822741f9c697b6f6a00c557e4817bf59ae70867";
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
      url = "github:oxalica/rust-overlay/f88aa8dea8f4136a0897fd7baddb3a07481f29f6";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pumpkin-nixpkgs.url = "github:NixOS/nixpkgs/50f77b992c17416658da7676adf072058a7ad0be";
    audio = {
      url = "github:polygon/audio.nix/3da0962c21f0de2559fb5185a9fd4e10fc9ae326";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-avf = {
      url = "github:nix-community/nixos-avf/d0a62c3f64b45a39570fde31a3a490b214bf19ee";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/a7007e69122c80d09252224b19cc5ad466627217";
    darwin = {
      url = "github:nix-darwin/nix-darwin/594c680c429be020d7130cc2b17d43c4760d17c7";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kopuz = {
      url = "git+https://github.com/dweee/kopuz.git?ref=tested&rev=5774303ca54c503dc692ab6ffafc18a1955fa81b";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    paneru = {
      url = "git+https://github.com/dweee/paneru.git?ref=tested&rev=6e30aac5b5e3ef6ea73215f875792cb4df0abd04";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-darwin.follows = "darwin";
    };
    # Match the standalone native workflow instead of overriding its toolchain.
    tabrix = {
      url = "git+https://github.com/dweee/tabrix.git?ref=tested&rev=4e49d5f549ee2112b39eb15d1d7a07596d98d796";
    };
    rekordbox-mcp = {
      url = "git+https://github.com/dweee/rekordbox-mcp.git?ref=tested&rev=b508c391bf59a83e63a50423cab8981322e32272";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kuna-src = {
      url = "github:Noelo-Lab/kuna/9ce03fa874c298db4dc284da1bed54c6b7348d8f";
      flake = false;
    };
    schildi-revenge = {
      url = "git+https://github.com/dweee/schildi-revenge.git?ref=tested&rev=0997c85512b7b561e41984ef220c02995310f02e&submodules=1";
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
      url = "github:bethington/ghidra-mcp/5bcb9e98b0cb135cbf7521494d1134f6877caf33";
      flake = false;
    };
    # Jellarr's own flake: consumers take its NixOS module from this same pin.
    jellarr = {
      url = "github:venkyr77/jellarr/de530bc0117eb4018598a67245e748623a6ce6dc";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wiicompiled = {
      url = "git+https://github.com/patchzyy/Wiicompiled.git?ref=main&rev=8ad99be22fd8fb4b6262a92afe1f6451b54632b1&submodules=1";
      flake = false;
    };
    hookshot-src = {
      url = "git+https://github.com/ItsNotRexed/Hookshot.git?ref=main&rev=38b90dfe70abcd9e9a9c09d17b70808c16f0153d";
      flake = false;
    };
    mkw-recomp-src = {
      url = "github:adriadam10/mkw-recomp/a808ce226c30544f4e1b70be86075de67aa27352";
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
