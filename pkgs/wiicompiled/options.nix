{ lib }: {
  enable = lib.mkEnableOption "WiiCompiled setup (does not ship game data)";

  enableGame = lib.mkEnableOption ''
    Translated native game derivation. Requires isoHash and a local disc
    extractor. The output contains disc data and translated code. Build
    in a local store with automatic cache uploads disabled.
  '';

  isoName = lib.mkOption {
    type = lib.types.str;
    default = "RMCP01.iso";
    description = "Filename used by requireFile (any dump format WiiCompiled accepts).";
  };

  discExtractor = lib.mkOption {
    type = lib.types.nullOr lib.types.package;
    default = null;
    description = "Your local disc extraction package with a nodtool-compatible bin/nodtool.";
  };

  hostCpu = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "apple-m4";
    description = ''
      Named compiler CPU/ISA for translated codegen (`-mcpu` on aarch64,
      `-march` on x86_64). Unset uses the portable floor (`apple-m1` on
      Apple Silicon, `x86-64-v3` on x86_64). Never `"native"` — Nix strips
      that flag.
    '';
  };

  isoHash = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    description = ''
      NAR/file hash of YOUR dump, from `nix-store --add-fixed sha256 /path/to/dump`.
      Not a globally unique PAL identifier — dump containers differ. After extract,
      the derivation still requires the PAL RMCP01 main.dol / StaticR.rel pins.
    '';
  };

  retroRewind = {
    wfcPayload = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.package lib.types.path);
      default = null;
      description = "Your local PAL Retro-WFC payload.RMCPD00.bin file.";
    };

    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Account that owns Application Support/WiiCompiled. Unset uses
        system.primaryUser on nix-darwin.
      '';
    };

    packRoot = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.package lib.types.path);
      default = null;
      example = lib.literalExpression "pkgs.retro-rewind-pack";
      description = ''
        Wheel Wizard / Riivolution RetroRewind6 pack (Code.pul + xml + tracks).
        With enableGame, the native RetroRewind product is translated and linked
        (Linux: wiicompiled-retro; Darwin: RetroRewind.app). Darwin also copies
        pack entries into Application Support: a store path cannot be the
        Riivolution overlay root (parent would be /nix/store).
      '';
    };
  };
}
