{
  description = "Dave's portable third-party Nix packages";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-zed-extensions = {
      url = "github:SwornSystems/nix-zed-extensions/5bf9d7730cda9bedc88c309b47f8d0e93b426b05";
      flake = false;
    };
    sable = {
      url = "git+https://git.monke.fail/d/sable.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    t3-code.url = "github:LisaScheers/t3-code-nix";
    nixos-jellyfin = {
      url = "github:matt1432/nixos-jellyfin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pumpkin-nixpkgs.url = "github:NixOS/nixpkgs/fe13242281a67641c0102cdb1087f0ebe586c7df";
    audio = {
      url = "github:polygon/audio.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-avf = {
      url = "github:nix-community/nixos-avf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/9c08e7cff055978bbd6f10820cde38c76bd37d6c";
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
    tabrix = {
      url = "git+https://github.com/dweee/tabrix?ref=flakey";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rekordbox-mcp = {
      url = "git+https://github.com/dweee/rekordbox-mcp?ref=flakey";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kuna = {
      url = "github:dweee/kuna/flakey";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    schildi-revenge = {
      url = "git+https://github.com/dweee/schildi-revenge?ref=flakey&submodules=1";
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
  outputs =
    inputs@{ self, nixpkgs, ... }:
    let
      platforms = builtins.fromJSON (builtins.readFile ./nix/platforms.json);
      systems = builtins.attrNames platforms;
      packageOverlay = final: prev: import ./nix/package-set.nix { inherit inputs final prev; };
      overlay = nixpkgs.lib.composeManyExtensions [
        inputs.rust-overlay.overlays.default
        (import ./nix/xorg-compat.nix)
        packageOverlay
      ];
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
      nixosModules.eri-kernel-patches = import ./nix/eri/kernel-patches.nix;

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
      );
      formatter = nixpkgs.lib.genAttrs systems (system: (pkgsFor system).nixfmt);
    };
}
