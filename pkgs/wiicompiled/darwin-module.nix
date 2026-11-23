catalog:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  common = import ./module-common.nix {
    inherit
      catalog
      lib
      pkgs
      config
      ;
  };
  cfg = common.cfg;
  packRoot = cfg.retroRewind.packRoot;
  rrUser = if cfg.retroRewind.user != null then cfg.retroRewind.user else config.system.primaryUser;
  home = config.users.users.${rrUser}.home;
  support = "${home}/Library/Application Support/WiiCompiled";
in
{
  options.programs.wiicompiled = import ./options.nix { inherit lib; };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      nixpkgs.overlays = [ common.overlay ];
      environment.systemPackages = common.wiiPackages;
      assertions = common.assertions;
    })
    # Finder .app bundles have no wrapper. dvd_root can be the store extract.
    # Riivolution XML uses /RetroRewind6/... relative to the overlay parent, so
    # a nix store pack cannot be retro_rewind_root (parent would be /nix/store).
    (lib.mkIf (cfg.enable && cfg.enableGame) {
      nix.settings.extra-sandbox-paths = [
        (import ./pkgs/ccache-dir.nix).path
      ];
      system.activationScripts.wiicompiledCcache.text =
        let
          ccacheDir = import ./pkgs/ccache-dir.nix;
        in
        ''
          install -d -m ${ccacheDir.mode} -o ${ccacheDir.owner} -g ${ccacheDir.group} ${ccacheDir.path}
          chown ${ccacheDir.owner}:${ccacheDir.group} ${ccacheDir.path}
          chmod ${ccacheDir.mode} ${ccacheDir.path}
        '';
      system.activationScripts.wiicompiledSupport.text = ''
        support=${lib.escapeShellArg support}
        config="$support/Config.toml"
        sd="$support/Riivolution"
        mkdir -p "$support" "$sd/riivolution/save" "$sd/RetroRewind6"

        toml_string() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
        set_path() {
          local key=$1 value=$2 encoded line temporary
          encoded=$(toml_string "$value"); line="$key = \"$encoded\""; temporary="$config.tmp"
          touch "$config"
          if grep -q '^[[:space:]]*\[paths\][[:space:]]*$' "$config"; then
            awk -v key="$key" -v line="$line" '
              /^[[:space:]]*\[paths\][[:space:]]*$/ { print; print line; inside = 1; next }
              inside && /^[[:space:]]*\[/ { inside = 0 }
              inside && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" { next }
              { print }
            ' "$config" > "$temporary"
          else
            { cat "$config"; printf '\n[paths]\n%s\n' "$line"; } > "$temporary"
          fi
          mv "$temporary" "$config"
        }
        set_path dvd_root ${lib.escapeShellArg "${common.game}/share/wiicompiled/DATA"}
        ${lib.optionalString (packRoot != null) ''
          for n in ${lib.escapeShellArg (toString packRoot)}/*; do
            ln -sfn "$n" "$sd/RetroRewind6/$(basename "$n")"
          done
          set_path retro_rewind_root "$sd/RetroRewind6"
        ''}
        chown -R ${lib.escapeShellArg rrUser} "$support" || true
      '';
    })
  ];
}
