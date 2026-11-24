# Linux CLI built from the pinned steipete/CodexBar release tag, with the
# Unlid provider patch. nixpkgs#codexbar is the Darwin menu-bar app only.
# The psimaker Plasma widget shells out to `codexbar`.
{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchSwiftPMDeps,
  swift,
  swiftpm,
  pkg-config,
  makeWrapper,
  removeReferencesTo,
  libredirect,
  procps,
  sqlite,
  which,
  gh,
  nix,
  python3,
  writeShellApplication,
}:
let
  pin = lib.importJSON ./cli-pin.json;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "codexbar-cli";
  inherit (pin) version;

  src = fetchFromGitHub {
    owner = "steipete";
    repo = "CodexBar";
    rev = pin.revision;
    inherit (pin) hash;
  };

  patches = [
    # Resolve only the CLI's dependencies on Linux (no Sparkle binary artifact)
    # and find sqlite3 through pkg-config.
    ./patches/cli-linux-dependencies.patch
    # Unlid balance, holds and spend provider with API-key account selection
    # (d/codexbar 52dd6a1cd without its docs; the post-0.84.0 setup-route
    # metadata is dropped).
    ./patches/cli-unlid-provider.patch
  ];

  nativeBuildInputs = [
    swift
    swiftpm
    pkg-config
    makeWrapper
    removeReferencesTo
  ];
  buildInputs = [ sqlite ];

  # Reads Package.resolved from the unpatched source.
  swiftpmDeps = fetchSwiftPMDeps {
    inherit (finalAttrs) pname version src;
    hash = pin.swiftpmDepsHash;
  };
  swiftpmFlags = [
    "--product"
    "CodexBarCLI"
  ];
  env.CODEXBAR_SQLITE3_LIB_DIR = "${lib.getLib sqlite}/lib";

  # BoringSSL (swift-crypto) embeds its source paths through __FILE__, which
  # would keep the 72 MiB vendored SwiftPM sources in the runtime closure.
  # The guard fails the build if any vendor path comes back.
  disallowedReferences = [
    finalAttrs.swiftpmDeps
    finalAttrs.swiftpmDeps.vendorStaging
  ];
  # The default strip keeps the 13 MiB symbol table; nothing needs it.
  stripAllList = [ "libexec" ];

  # Mirror the upstream release layout: plugin scripts and VERSION sit beside
  # the real executable in libexec, where Swift resolves /proc/self/exe even
  # when launched by the wrapper.
  installPhase = ''
    runHook preInstall
    binPath="$(swiftpmBinPath)"
    dest=$out/libexec/codexbar
    mkdir -p $dest $out/bin
    install -m755 "$binPath/CodexBarCLI" $dest/CodexBarCLI
    remove-references-to -t ${finalAttrs.swiftpmDeps.vendorStaging} $dest/CodexBarCLI
    ln -s CodexBarCLI $dest/codexbar
    printf '%s\n' "$version" > $dest/VERSION
    if [ -d "$binPath/CodexBar_CodexBarCore.bundle" ]; then
      cp -R "$binPath/CodexBar_CodexBarCore.bundle" $dest/
    else
      cp -R "$binPath/CodexBar_CodexBarCore.resources" $dest/CodexBar_CodexBarCore.bundle
    fi
    # Upstream hardcodes these FHS paths. In particular, a failed launch of
    # /usr/bin/which reaches Process.terminationStatus and traps with SIGILL.
    # Keep the executable beside its bundle and redirect filesystem checks
    # and process launches without adding host-global compatibility links.
    makeWrapper $dest/CodexBarCLI $out/bin/codexbar \
      --prefix LD_PRELOAD : ${libredirect}/lib/libredirect.so \
      --prefix NIX_REDIRECTS : /usr/bin/which=${which}/bin/which:/bin/ps=${procps}/bin/ps:/usr/bin/ps=${procps}/bin/ps
    ln -s codexbar $out/bin/CodexBarCLI
    install -Dm644 LICENSE $out/share/licenses/codexbar-cli/LICENSE
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR/codexbar-home"
    export XDG_CONFIG_HOME="$HOME/.config"
    mkdir -p "$XDG_CONFIG_HOME"
    $out/bin/codexbar --help >/dev/null
    $out/bin/CodexBarCLI --version
    # No credentials or provider CLIs in the sandbox: normal usage errors
    # are expected, but crashes and missing packaged resources are not.
    # Kiro runs /usr/bin/which; Antigravity runs /bin/ps; Unlid is patched in.
    test -f $out/libexec/codexbar/CodexBar_CodexBarCore.bundle/unlid.js
    for provider in openai kiro antigravity unlid; do
      status=0
      $out/bin/codexbar usage --format json --json-only --provider "$provider" \
        >"$TMPDIR/$provider.json" 2>"$TMPDIR/$provider.stderr" || status=$?
      if [ "$status" -gt 1 ] || grep -Eq \
        "no bundled provider plugin|Missing CLI '/(usr/)?bin/(ps|which)" \
        "$TMPDIR/$provider.json" "$TMPDIR/$provider.stderr"; then
        cat "$TMPDIR/$provider.json" "$TMPDIR/$provider.stderr" >&2
        echo "codexbar-cli: $provider install check failed (exit $status)" >&2
        exit 1
      fi
    done
    runHook postInstallCheck
  '';

  passthru.updateScript = [
    (lib.getExe (writeShellApplication {
      name = "update-codexbar-cli";
      runtimeInputs = [
        gh
        nix
        python3
      ];
      text = ''
        exec python3 ${./update.py} --pin-file pkgs/codexbar/cli-pin.json --apply "$@"
      '';
    }))
  ];

  meta = {
    description = "CLI for AI coding-provider usage limits";
    homepage = "https://github.com/steipete/CodexBar";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "codexbar";
  };
})
