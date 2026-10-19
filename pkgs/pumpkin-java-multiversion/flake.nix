{
  description = "Java multiversion compiled against the accompanying Pumpkin server API";
  inputs = {
    pumpkin-nixpkgs.url = "github:NixOS/nixpkgs/fe13242281a67641c0102cdb1087f0ebe586c7df";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {
    nixpkgs,
    rust-overlay,
    pumpkin-nixpkgs,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [rust-overlay.overlays.default];
    };
  in {
    packages.${system}.default = pkgs.callPackage ./nix/package.nix {pumpkin = pumpkin-nixpkgs.legacyPackages.${system}.pumpkin;};
  };
}
