{
  catalog,
  lib,
  pkgs,
  config,
}:
let
  cfg = config.programs.wiicompiled;
  overlay = catalog.overlay;
  wiiPkgs = pkgs.extend overlay;
  game = wiiPkgs.wiicompiled.override (
    {
      inherit (cfg) discExtractor;
      iso = pkgs.requireFile {
        name = cfg.isoName;
        sha256 = cfg.isoHash;
        message = ''
          WiiCompiled needs your legally dumped PAL RMCP01 image in the Nix store:

            nix-store --add-fixed sha256 /path/to/${cfg.isoName}

          Put the printed hash in programs.wiicompiled.isoHash.
        '';
      };
    }
    // lib.optionalAttrs (cfg.retroRewind.packRoot != null) {
      retroRewind = cfg.retroRewind.packRoot;
      retroWfcPayload = cfg.retroRewind.wfcPayload;
    }
    // lib.optionalAttrs (cfg.hostCpu != null) {
      inherit (cfg) hostCpu;
    }
  );
in
{
  inherit cfg overlay game;
  wiiPackages = [
    catalog.publicPackages.${pkgs.stdenv.hostPlatform.system}.wiicompiled-setup
  ]
  ++ lib.optional cfg.enableGame game;
  assertions = [
    {
      assertion = cfg.hostCpu != "native";
      message = ''
        programs.wiicompiled.hostCpu cannot be "native". Pass a named CPU
        (apple-m4, apple-m1, x86-64-v3, …); Nix strips -mcpu=native.
      '';
    }
    {
      assertion = (!cfg.enableGame) || (cfg.isoHash != null);
      message = "programs.wiicompiled.enableGame requires programs.wiicompiled.isoHash";
    }
    {
      assertion = !cfg.enableGame || cfg.discExtractor != null;
      message = "programs.wiicompiled.enableGame requires a local discExtractor";
    }
    {
      assertion = cfg.retroRewind.packRoot == null || cfg.retroRewind.wfcPayload != null;
      message = "programs.wiicompiled.retroRewind.packRoot requires a local retroRewind.wfcPayload";
    }
    {
      assertion =
        (!cfg.enableGame) || !(pkgs.stdenv.hostPlatform.isDarwin && pkgs.stdenv.hostPlatform.isx86_64);
      message = "programs.wiicompiled.enableGame is not supported on Intel Macs (upstream is Apple Silicon only)";
    }
    {
      assertion = (cfg.retroRewind.packRoot == null) || cfg.enableGame;
      message = "programs.wiicompiled.retroRewind.packRoot requires programs.wiicompiled.enableGame";
    }
  ];
}
