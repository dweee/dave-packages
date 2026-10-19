{ pkgs, inputs }:
let
  inherit (pkgs) lib;
  extensionPkgs = pkgs.extend (
    lib.composeManyExtensions [
      inputs.rust-overlay.overlays.default
      (import "${inputs.nix-zed-extensions}/overlays")
    ]
  );
  # WASI needs rustc/cargo/std, without the default profile's docs and linters.
  buildZedRustExtension =
    extensionPkgs.callPackage "${inputs.nix-zed-extensions}/pkgs/buildZedRustExtension"
      {
        rust-bin.stable.latest.default = extensionPkgs.rust-bin.stable.latest.minimal;
      };
  # Carry the injection changes from zed-extensions/nix#49 and
  # nix-community/tree-sitter-nix#166 on current upstream sources.
  nixGrammar = extensionPkgs.zed-grammars.nix_nix.overrideAttrs (old: {
    version = "929f53586dcc-injections";
    src = pkgs.fetchFromGitHub {
      owner = "nix-community";
      repo = "tree-sitter-nix";
      rev = "929f53586dcc0611d2c9406886d9d18033ed71bc";
      hash = "sha256-fAdq5luxS6klTenlFOztDSnCgtE9JfA+VJpYcDAJz/Q=";
    };
    patches = (old.patches or [ ]) ++ [ ./zed-patches/tree-sitter-nix-injections.patch ];
    nativeBuildInputs = old.nativeBuildInputs ++ [
      pkgs.nodejs
      pkgs.tree-sitter
      pkgs.writableTmpDirAsHomeHook
    ];
    # Regenerate instead of carrying a large, stale generated-parser patch.
    postPatch = (old.postPatch or "") + ''
      tree-sitter generate --abi 15
    '';
    doCheck = true;
    nativeCheckInputs = [ pkgs.stdenv.cc ];
    checkPhase = ''
      runHook preCheck
      # Upstream keeps its corpus at corpus/, while the newer CLI expects
      # test/corpus. Test the regenerated C parser in an isolated directory.
      mkdir -p "$TMPDIR/zed-nix-tests/test"
      # The CLI also needs the grammar metadata when running corpus tests.
      cp -r . "$TMPDIR/zed-nix-tests"
      cp -r corpus "$TMPDIR/zed-nix-tests/test/corpus"
      # Run the parser corpus independently of upstream's highlighting tests.
      rm -rf "$TMPDIR/zed-nix-tests/test/highlight"
      pushd "$TMPDIR/zed-nix-tests"
      # The test runner compiles a native parser; avoid wasi-sdk's clang.
      CC=${pkgs.stdenv.cc}/bin/cc tree-sitter test --overview-only
      popd
      runHook postCheck
    '';
  });
  nixExtension =
    (extensionPkgs.zed-extensions.nix.override {
      inherit buildZedRustExtension;
      zed-grammars = extensionPkgs.zed-grammars // {
        nix_nix = nixGrammar;
      };
    }).overrideAttrs
      (old: {
        version = "0.1.5-injections";
        src = pkgs.fetchFromGitHub {
          owner = "zed-extensions";
          repo = "nix";
          rev = "429479c09c5a597f31b8b53c3950cf96cec6e1f4";
          hash = "sha256-hKb4l+BDt0OrL9PuG2uLczS92iwE3FiDt8We6pSbjds=";
        };
        patches = (old.patches or [ ]) ++ [ ./zed-patches/nix-injections.patch ];
        # Keep the manifest aligned with the patched upstream grammar we bundle.
        postPatch = (old.postPatch or "") + ''
          substituteInPlace extension.toml \
            --replace-fail ea1d87f7996be1329ef6555dcacfa63a69bd55c6 \
              929f53586dcc0611d2c9406886d9d18033ed71bc
        '';
      });
in
nixExtension
