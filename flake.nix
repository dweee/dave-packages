{
  description = "Dave's portable third-party Nix packages";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/2786a2a72088ecf32aea5b3ec52099e6a7cff78f";
    nix-zed-extensions = {
      url = "github:SwornSystems/nix-zed-extensions/898bc0f07436ef200354b40ba9554c2161c8675f";
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
    # Retain native fork toolchains so catalog updates reuse their CI outputs.
    handy = {
      url = "github:dweee/Handy/b2f592d4252cd4296d5f18db637536de0a499048";
    };
    # Preserve the upstream runner toolchain for reproducible cache outputs.
    virby.url = "github:quinneden/virby-nix-darwin/a52216470a97ef5970939acf697a00ec61beb0c6";
    mcp-nixos = {
      url = "github:utensils/mcp-nixos/2b0b86ceda72ec5c5d0d78ac3130ccf024f6a7ff";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Retain the packaging flake's Node/pnpm pin and fixed dependency hashes.
    t3-code.url = "github:LisaScheers/t3-code-nix/f6696d0e300fef84b55aa3c655902983daffb46d";
    nixos-jellyfin = {
      url = "github:matt1432/nixos-jellyfin/2b464890ce33c84b5affdcfa98ed62b03f0d3fe0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay/52db20539ec0ba063479d66092992d9efcf456ff";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pumpkin-nixpkgs.url = "github:NixOS/nixpkgs/2ce3c67a3687fca89a7342d40bfa28aff0b6a114";
    audio = {
      url = "github:polygon/audio.nix/3da0962c21f0de2559fb5185a9fd4e10fc9ae326";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-avf = {
      url = "github:nix-community/nixos-avf/d0a62c3f64b45a39570fde31a3a490b214bf19ee";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/3547834022c7faca65918abbd8645c855d20cc35";
    darwin = {
      url = "github:nix-darwin/nix-darwin/f673885103fa92c1c5b1d16b8bf2b858906809e2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kopuz = {
      url = "git+https://github.com/dweee/kopuz.git?ref=tested&rev=e2d481d58054545146a76638f601d81341dc1118";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    paneru = {
      url = "git+https://github.com/dweee/paneru.git?ref=tested&rev=27a92e5abf2aa299aace42b177f43a877b918e17";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-darwin.follows = "darwin";
    };
    # Match the standalone native workflow instead of overriding its toolchain.
    tabrix = {
      url = "git+https://github.com/dweee/tabrix.git?ref=tested&rev=24e20b017f0ef3c34de75e9c93c502ede0859541";
    };
    rekordbox-mcp = {
      url = "git+https://github.com/dweee/rekordbox-mcp.git?ref=tested&rev=01198a79d0dfd74cbc1f5a8e0b88184e49aa0ed8";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kuna = {
      url = "github:dweee/kuna/6cc1f99dc4a59e6070643e01baebec0dfd72435b";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    schildi-revenge = {
      url = "git+https://github.com/dweee/schildi-revenge.git?ref=tested&rev=019b74e8fc9339f314d8ef7797468e5447914c76&submodules=1";
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
      url = "github:dweee/ghidra-mcp/2ef97b699efadedae6ff4c5ea4263ec60e5f629e";
      flake = false;
    };
    # Jellarr's own flake: consumers take its NixOS module from this same pin.
    jellarr = {
      url = "github:venkyr77/jellarr/de530bc0117eb4018598a67245e748623a6ce6dc";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wiicompiled = {
      url = "git+https://github.com/dweee/Wiicompiled.git?ref=flakey&rev=0efc70ee6c5925b5d3c2c6d2eb79e92d9ae93bac&submodules=1";
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
          rea-ghidra-headless = (pkgsFor system).callPackage ./pkgs/ghidra-kuna/smoke-test.nix {
            ghidra-kuna = (pkgsFor system).rea-kuna.ghidra-kuna;
            openjdk25 = (pkgsFor system).jdk21;
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
