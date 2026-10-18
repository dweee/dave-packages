# Overlay factory: `(import ./overlay.nix flakeSelf) final prev`
# `flakeSelf` is the flake source (or any checkout) used as the WiiCompiled tree.
#
# Build graph (crane-style layers):
#   nodtool / FetchContent / translator fileset
#     -> native-prebuilt (aurora + Crypto++ + vendored deps; substitutable)
#     -> disc extract (user-supplied ISO; substitutable)
#     -> translated C++ (disc + translator + runtime/src; substitutable)
#     -> game link/compile (runtime + prebuilt + generated; substitutable)
flakeSelf: final: prev: let
  inherit (final) lib;
  sources = import ./pkgs/sources.nix {inherit lib;};
in {
  wiicompiled-nodtool = final.callPackage ./pkgs/nodtool.nix {};
  wiicompiled-translator = final.callPackage ./pkgs/translator.nix {src = sources.translator;};
  wiicompiled-native-prebuilt = final.callPackage ./pkgs/native-prebuilt.nix {
    src = sources.nativePrebuilt;
  };
  wiicompiled-setup =
    if final.stdenv.hostPlatform.isDarwin
    then final.callPackage ./pkgs/setup-macos.nix {src = sources.setup;}
    else final.callPackage ./pkgs/setup.nix {src = sources.setup;};
}
