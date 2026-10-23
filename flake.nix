{
  description = "Dave's portable third-party Nix packages";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-zed-extensions = {
      url =
        "github:SwornSystems/nix-zed-extensions/5bf9d7730cda9bedc88c309b47f8d0e93b426b05";
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
      url =
        "github:pyproject-nix/pyproject.nix/ddc400a6883b042646d0940e65971bb7f7e96107";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url =
        "github:pyproject-nix/uv2nix/37462fae7b37be45d78f754d1c39e8813ede0f80";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };
    pyproject-build-systems = {
      url =
        "github:pyproject-nix/build-system-pkgs/953d35d03a51dbecaf3feb3fb679eb63e90ebeb4";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };
    sable = {
      url = "git+https://git.monke.fail/d/sable.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Retain native fork toolchains so catalog updates reuse their CI outputs.
    handy = {
      url = "github:dweee/Handy/d588df2c637f325847534bdd06ece5dd75dc5b4b";
    };
    # Preserve the upstream runner toolchain for reproducible cache outputs.
    virby.url =
      "github:quinneden/virby-nix-darwin/a52216470a97ef5970939acf697a00ec61beb0c6";
    mcp-nixos = {
      url =
        "github:utensils/mcp-nixos/6a517811658c21f97bd7703b35546085117fc310";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Retain the packaging flake's Node/pnpm pin and fixed dependency hashes.
    t3-code.url =
      "github:LisaScheers/t3-code-nix/41caf597ed5d2dcfe7bb398fb38dfae290bb34ba";
    nixos-jellyfin = {
      url = "github:matt1432/nixos-jellyfin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pumpkin-nixpkgs.url =
      "github:NixOS/nixpkgs/fe13242281a67641c0102cdb1087f0ebe586c7df";
    audio = {
      url = "github:polygon/audio.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-avf = {
      url = "github:nix-community/nixos-avf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cachyos-kernel.url =
      "github:xddxdd/nix-cachyos-kernel/9c08e7cff055978bbd6f10820cde38c76bd37d6c";
    darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kopuz = {
      url = "git+https://github.com/dweee/kopuz?ref=flakey";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    paneru = {
      url = "git+https://github.com/dweee/paneru?ref=flakey";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-darwin.follows = "darwin";
    };
    # Match the standalone native workflow instead of overriding its toolchain.
    tabrix = { url = "git+https://github.com/dweee/tabrix?ref=flakey"; };
    rekordbox-mcp = {
      url = "git+https://github.com/dweee/rekordbox-mcp?ref=flakey";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kuna = {
      url = "github:dweee/kuna/flakey";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    schildi-revenge = {
      url =
        "git+https://github.com/dweee/schildi-revenge?ref=flakey&submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    slskd-mcp = {
      url = "github:abl030/slskd-mcp";
      flake = false;
    };
    prowlarr-mcp = {
      url = "github:arr-mcps/prowlarr-mcp";
      flake = false;
    };
    ghidra-mcp = {
      url = "github:bethington/ghidra-mcp/v6.0.0";
      flake = false;
    };
    gdb-mcp = {
      url = "github:birdeclipse/gdb-mcp";
      flake = false;
    };
  };
  outputs = inputs@{ self, nixpkgs, ... }:
    let
      platforms = builtins.fromJSON (builtins.readFile ./nix/platforms.json);
      systems = builtins.attrNames platforms;
      cacheOnlyPlatforms =
        builtins.fromJSON (builtins.readFile ./nix/cache-only-platforms.json);
      packageOverlay = final: prev:
        import ./nix/package-set.nix { inherit inputs final prev; };
      overlay = nixpkgs.lib.composeManyExtensions [
        inputs.rust-overlay.overlays.default
        (import ./nix/xorg-compat.nix)
        packageOverlay
      ];
      pkgsFor = system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = false;
          overlays = [ overlay ];
        };
    in {
      overlays.default = overlay;
      # Deliberately excluded from packages/checks and every public artifact matrix.
      # Only the trusted cache-only workflow evaluates these unfree closures.
      cacheOnlyPackages = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ overlay ];
          };
          definitions = import ./nix/cache-only-packages.nix { inherit pkgs; };
        in nixpkgs.lib.genAttrs (cacheOnlyPlatforms.${system} or [ ])
        (name: definitions.${name}));
      nixosModules.android-avf-kernel-patches =
        import ./nix/android-avf/kernel-patches.nix;

      packages = nixpkgs.lib.genAttrs systems (system:
        let pkgs = pkgsFor system;
        in nixpkgs.lib.genAttrs platforms.${system} (name: pkgs.${name}));
      checks = nixpkgs.lib.genAttrs systems (system:
        self.packages.${system} // {
          kuna-ghidra-headless =
            (pkgsFor system).callPackage ./pkgs/ghidra-kuna/smoke-test.nix { };
        });
      formatter =
        nixpkgs.lib.genAttrs systems (system: (pkgsFor system).nixfmt);
    };
}
