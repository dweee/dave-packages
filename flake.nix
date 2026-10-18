{
  description = "Dave's portable third-party Nix packages";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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
      overlay = final: prev: import ./nix/package-set.nix { inherit inputs final prev; };
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
    in
    {
      overlays.default = overlay;
      packages = nixpkgs.lib.genAttrs systems (
        system:
        let
          pkgs = pkgsFor system;
        in
        nixpkgs.lib.genAttrs platforms.${system} (name: pkgs.${name})
      );
      checks = self.packages;
      formatter = nixpkgs.lib.genAttrs systems (system: (pkgsFor system).nixfmt);
    };
}
