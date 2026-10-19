{
  lib,
  stdenv,
  writeShellScript,
  clang,
  cmake,
  ninja,
  src,
  wiicompiled-translator,
  wiicompiled-nodtool,
}: let
  intel = stdenv.hostPlatform.isx86_64;
in
  stdenv.mkDerivation rec {
    pname = "wiicompiled-setup";
    version = "0.2.32";
    inherit src;

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      share=$out/share/wiicompiled
      mkdir -p $share/Launcher/macos $out/bin

      cp -a runtime aurora-main projects $share/
      cp Launcher/local-build-macos.command $share/Launcher/local-build-macos.command
      cp Launcher/macos/extract-disc.command $share/Launcher/macos/extract-disc.command
      cp Launcher/macos/publish-app.command $share/Launcher/macos/publish-app.command
      chmod +x $share/Launcher/local-build-macos.command \
        $share/Launcher/macos/extract-disc.command \
        $share/Launcher/macos/publish-app.command

      find $share/aurora-main/extern -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
      rm -rf $share/runtime/build

      printf '%s\n' "$out" > $share/.bundle-version

      substitute ${wrapper} $out/bin/wiicompiled-setup \
        --subst-var-by share "$share"
      chmod +x $out/bin/wiicompiled-setup

      runHook postInstall
    '';

    wrapper = writeShellScript "wiicompiled-setup-macos-wrapper" ''
      set -euo pipefail
      bundle=@share@
      cache="''${WIICOMPILED_WORKSPACE:-$HOME/Library/Application Support/WiiCompiled/workspace}"
      output_dir="''${WIICOMPILED_OUTPUT:-$HOME/Applications}"
      sync=1
      for arg in "$@"; do
        case "$arg" in
          --help|-h|--version) sync=0 ;;
        esac
      done
      if [ "$#" -eq 0 ]; then sync=0; fi
      if [ "$sync" -eq 1 ]; then
        if [ ! -f "$cache/.bundle-version" ] || \
           [ "$(cat "$bundle/.bundle-version")" != "$(cat "$cache/.bundle-version")" ]; then
          mkdir -p "$cache/Launcher/macos"
          for dir in runtime aurora-main projects; do
            rm -rf "$cache/$dir"
            cp -a "$bundle/$dir" "$cache/$dir"
          done
          cp "$bundle/Launcher/local-build-macos.command" "$cache/Launcher/local-build-macos.command"
          cp "$bundle/Launcher/macos/extract-disc.command" "$cache/Launcher/macos/extract-disc.command"
          cp "$bundle/Launcher/macos/publish-app.command" "$cache/Launcher/macos/publish-app.command"
          cp "$bundle/.bundle-version" "$cache/.bundle-version"
        fi
      fi

      if [ "''${1:-}" = "--version" ]; then
        echo ${version}
        exit 0
      fi
      if [ "$#" -eq 0 ] || [ "''${1:-}" = "--help" ] || [ "''${1:-}" = "-h" ]; then
        cat <<EOF
      Usage: wiicompiled-setup [install] [local-build-macos.command options]

        install                   Build into ~/Applications (override with WIICOMPILED_OUTPUT)
        --version                 Print the package version
        --help                    This message

      Forwards remaining flags to local-build-macos.command. The workspace is
      synced under ~/Library/Application Support/WiiCompiled/workspace.
      EOF
        exit 0
      fi

      extras=()
      if [ "''${1:-}" = "install" ]; then
        shift
        extras+=(--output-dir "$output_dir")
      fi
      # --game and --nodtool must be supplied together.
      for arg in "$@"; do
        if [ "$arg" = --game ]; then
          extras+=(--nodtool ${wiicompiled-nodtool}/bin/nodtool)
          break
        fi
      done
      # Nix clang+libcxx vs the macOS SDK breaks aurora (`cstddef`/`stddef.h`).
      # CMake/ninja come from Nix; the compiler is Apple clang on PATH.
      export PATH=${lib.makeBinPath [cmake ninja]}:/usr/bin:/usr/sbin:/bin''${PATH:+:$PATH}
      "$cache/Launcher/local-build-macos.command" \
        --workspace "$cache" \
        --translator-bin ${wiicompiled-translator}/bin/Translator.Cli \
        --cmake ${cmake}/bin/cmake \
        --ninja ${ninja}/bin/ninja \
        "''${extras[@]}" \
        "$@"

      # Finder launches the published .app directly (no Linux-style wrapper),
      # so Config.toml must name dvd_root or the runtime exits with no window.
      support_root="$HOME/Library/Application Support/WiiCompiled"
      config="$support_root/Config.toml"
      data=""
      for candidate in "$support_root/DATA" "$cache/Assets/DATA"; do
        if [ -d "$candidate/files" ] && [ -d "$candidate/sys" ]; then
          data=$candidate
          break
        fi
      done
      if [ -n "$data" ]; then
        mkdir -p "$support_root"
        toml_string() { printf '%s' "$1" | sed -e 's/\\\\/\\\\\\\\/g' -e 's/"/\\\\"/g'; }
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
        set_path dvd_root "$data"
      fi
    '';

    meta = {
      description = "WiiCompiled macOS setup (translate + compile against your own PAL dump)";
      homepage = "https://github.com/patchzyy/Wiicompiled";
      license = lib.licenses.gpl3Only;
      platforms = ["aarch64-darwin" "x86_64-darwin"];
      mainProgram = "wiicompiled-setup";
      # Upstream local-build-macos.command and runtime CMake refuse Intel Macs.
      broken = intel;
    };
  }
