{
  description = "Dave's portable third-party Nix packages";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/55bfb4d7437bd4e09ab7cba58a43bd68eb310044";
    nix-zed-extensions = {
      url = "github:SwornSystems/nix-zed-extensions/3db83197114bbea472c99bcc5f658b296d6cd296";
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
      url = "github:pyproject-nix/build-system-pkgs/6171a3484937e14cdf2316ed9a60f1c27b6cb71e";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };
    # Retain native fork toolchains so catalog updates reuse their CI outputs.
    handy = {
      url = "github:dweee/Handy/f42d7d5822c235ac2ed3ef8ac5ea5569915531fa";
    };
    # Preserve the upstream runner toolchain for reproducible cache outputs.
    virby.url = "github:quinneden/virby-nix-darwin/a52216470a97ef5970939acf697a00ec61beb0c6";
    mcp-nixos = {
      url = "github:utensils/mcp-nixos/2e88096695bef9c41c5fa9157211d52a45d9a913";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Retain the packaging flake's Node/pnpm pin and fixed dependency hashes.
    t3-code.url = "github:LisaScheers/t3-code-nix/bc596519d3066122146c90233b130a8b6d101197";
    nixos-jellyfin = {
      url = "github:matt1432/nixos-jellyfin/ad9153c014bfa35d627aa9b692e2b5bd63e993f2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay/96a0986b0486341fbc163fa2fabc6d3b44cdcbf1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pumpkin-nixpkgs.url = "github:NixOS/nixpkgs/52ff023d11cc4f258b278976c465c66b226d5d13";
    audio = {
      url = "github:polygon/audio.nix/3da0962c21f0de2559fb5185a9fd4e10fc9ae326";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-avf = {
      url = "github:nix-community/nixos-avf/d0a62c3f64b45a39570fde31a3a490b214bf19ee";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/aea3c6c98fe348e8d1b768fa4dd46a81c87d05e1";
    darwin = {
      url = "github:nix-darwin/nix-darwin/ff0e21a414d4547183396da1b44a66f2577b65e9";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kopuz = {
      url = "git+https://github.com/dweee/kopuz.git?ref=tested&rev=73dbe7739ed43989a2ccb03a49f4132deaedaebb";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    paneru = {
      url = "git+https://github.com/dweee/paneru.git?ref=tested&rev=0a27a6b941417700a0eea20d4bbfaae4f85ebcac";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-darwin.follows = "darwin";
    };
    # Match the standalone native workflow instead of overriding its toolchain.
    tabrix = { url = "git+https://github.com/dweee/tabrix.git?ref=tested&rev=bcb4210c53a95e33b3621b3d4e78bf7a60831fe9"; };
    rekordbox-mcp = {
      url = "git+https://github.com/dweee/rekordbox-mcp.git?ref=tested&rev=c478ff3ff13d6b849639843a8bad9c79260a2f3c";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kuna = {
      url = "github:dweee/kuna/1ce312946631c8fb338bfce03a2906073ffa841b";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    schildi-revenge = {
      url = "git+https://github.com/dweee/schildi-revenge.git?ref=tested&rev=cde49b8c637d2a9d8e44add739edbb2a2a162e6f&submodules=1";
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
