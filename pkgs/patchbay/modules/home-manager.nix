# programs.patchbay for home-manager.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.patchbay;
  common = import ./common.nix { inherit lib cfg; };
  # Folder names under <root>/mods and <root>/maps: one path component, no
  # "." or "..". Mod ids follow mod.schema.json; map folders may also start
  # with a digit ("6.1.4") like the workspace's maps/<build>.
  validName = pattern: name: builtins.match pattern name != null;
  namedPaths =
    pattern:
    lib.types.addCheck (lib.types.attrsOf lib.types.path) (
      values: lib.all (validName pattern) (builtins.attrNames values)
    );
  modName = "[A-Za-z][A-Za-z0-9_.-]*";
  mapName = "[A-Za-z0-9][A-Za-z0-9_.-]*";
  q = lib.escapeShellArg;
  # <root>/mods/<name> and <root>/maps/<name> -> the folder copied there
  folders =
    lib.mapAttrs' (name: lib.nameValuePair "mods/${name}") cfg.mods
    // lib.mapAttrs' (name: lib.nameValuePair "maps/${name}") cfg.mapPacks;
  # What both activation blocks start from: the declared folders and those an earlier activation
  # copied (<root>/.hm-managed, "<mods|maps>/<name><TAB><source>" per line).
  preamble = ''
    patchbayRoot=${q cfg.root}
    declare -A patchbayWant=(${
      lib.concatStrings (lib.mapAttrsToList (rel: source: " [${q rel}]=${q "${source}"}") folders)
    } ) patchbayHad=()
    if [[ -f $patchbayRoot/.hm-managed ]]; then
      while IFS=$'\t' read -r rel src; do
        if [[ -n $rel ]]; then patchbayHad[$rel]=$src; fi
      done <"$patchbayRoot/.hm-managed"
    fi
  '';
in
{
  options.programs.patchbay = import ./options.nix { inherit lib pkgs cfg; } // {
    root = lib.mkOption {
      type = lib.types.addCheck lib.types.str (
        value: lib.hasPrefix "/" value && !lib.hasInfix "\n" value
      );
      default = "${config.xdg.dataHome}/bml";
      defaultText = lib.literalExpression ''"''${config.xdg.dataHome}/bml"'';
      example = "/home/alice/BML";
      description = ''
        BML's writable folder, exported as `BML_ROOT`. The `patchbay` command
        copies the loader here from the Nix store and keeps mods, maps,
        sessions and logs here. Must be an absolute path. Per-user settings
        (`bml.properties`) stay in
        `$XDG_CONFIG_HOME/bml` and are never managed by this module.
      '';
    };

    mods = lib.mkOption {
      type = namedPaths modName;
      default = { };
      example = lib.literalExpression "{ my-mod = ./mods/my-mod; }";
      description = ''
        Mod folders copied to `<root>/mods/<name>` on activation (BML refuses
        a linked mod folder). Names follow the mod id rule
        (`[A-Za-z][A-Za-z0-9_.-]*`). Declaring a mod installs it; ticking it
        in the Patchbay window still decides whether it loads. A copy is
        replaced when its source changes and removed when it is no longer
        declared; other folders in `<root>/mods` are never touched, and one
        of the same name stops the activation.
      '';
    };

    mapPacks = lib.mkOption {
      type = namedPaths mapName;
      default = { };
      example = lib.literalExpression ''
        {
          "6.1.4" = ./maps/6.1.4;
          "linux-6.1.4" = ./maps/linux-6.1.4;
        }
      '';
      description = ''
        Unpacked map pack folders (each holding `map.json` and `builds.json`)
        copied to `<root>/maps/<name>` on activation, as `mods` are, keyed by
        build, e.g. `6.1.4`, `linux-6.1.4` or `macos-6.1.4`. Names match
        `[A-Za-z0-9][A-Za-z0-9_.-]*`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    inherit (common) assertions;
    home.packages = common.packages;
    home.sessionVariables = common.variables // {
      BML_ROOT = cfg.root;
    };
    # Before anything is written: a declared folder may only replace one an earlier activation
    # copied, or a link into the Nix store (how earlier versions of this module installed them).
    home.activation.patchbayCheck = lib.hm.dag.entryBefore [ "writeBoundary" ] (
      preamble
      + ''
        for rel in "''${!patchbayWant[@]}"; do
          dst=$patchbayRoot/$rel
          if [[ ( -e $dst || -L $dst ) && ! -v patchbayHad[$rel] ]] \
            && ! [[ -L $dst && $(readlink -- "$dst") == /nix/store/* ]]; then
            errorEcho "programs.patchbay: $dst exists and was not copied there by home-manager; move it away first."
            exit 1
          fi
        done
      ''
    );
    # After the old generation's links are gone: copy each declared folder in as a real, writable
    # tree, replace a copy whose source changed and remove one no longer declared.
    home.activation.patchbay = lib.hm.dag.entryAfter [ "linkGeneration" ] (
      preamble
      + ''
        for rel in "''${!patchbayHad[@]}"; do
          if [[ ! -v patchbayWant[$rel] ]]; then
            verboseEcho "programs.patchbay: removing $patchbayRoot/$rel"
            run rm -rf -- "''${patchbayRoot:?}/$rel"
          fi
        done
        for rel in "''${!patchbayWant[@]}"; do
          src=''${patchbayWant[$rel]} dst=$patchbayRoot/$rel new=$patchbayRoot/.hm-staging/new
          if [[ ''${patchbayHad[$rel]-} == "$src" && -d $dst && ! -L $dst ]]; then
            verboseEcho "programs.patchbay: $dst is up to date"
            continue
          fi
          verboseEcho "programs.patchbay: copying $src to $dst"
          run mkdir -p -- "$patchbayRoot/.hm-staging" "$(dirname -- "$dst")"
          run rm -rf -- "$new"
          run cp -RL -- "$src" "$new"
          run chmod -R u+w -- "$new"
          run rm -rf -- "$dst"
          run mv -- "$new" "$dst"
        done
        if [[ -d $patchbayRoot/.hm-staging ]]; then run rm -rf -- "$patchbayRoot/.hm-staging"; fi
        if [[ ''${#patchbayWant[@]} -gt 0 || -f $patchbayRoot/.hm-managed ]]; then
          if [[ -v DRY_RUN ]]; then
            echo "write $patchbayRoot/.hm-managed"
          else
            for rel in "''${!patchbayWant[@]}"; do
              printf '%s\t%s\n' "$rel" "''${patchbayWant[$rel]}"
            done | LC_ALL=C sort >"$patchbayRoot/.hm-managed.new"
            mv -f -- "$patchbayRoot/.hm-managed.new" "$patchbayRoot/.hm-managed"
          fi
        fi
      ''
    );
  };
}
