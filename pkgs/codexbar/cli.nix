# Linux CLI from steipete/CodexBar release tarballs. nixpkgs#codexbar is the
# Darwin menu-bar app only. The psimaker Plasma widget shells out to `codexbar`.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  curl,
  libredirect,
  libxml2,
  procps,
  sqlite,
  which,
}:
let
  pname = "codexbar-cli";
  version = "0.83.0";

  assets = {
    x86_64-linux = {
      name = "CodexBarCLI-v${version}-linux-x86_64.tar.gz";
      hash = "sha256-4njrChttYgtchMFX37FoYKgkd69uxzMLa2+1x/Jym1s=";
    };
    aarch64-linux = {
      name = "CodexBarCLI-v${version}-linux-aarch64.tar.gz";
      hash = "sha256-uxKJfJNVVfq6lR0MAm9CKRKpIdh9shKVwwKIqkcAQrU=";
    };
  };

  asset =
    assets.${stdenv.hostPlatform.system}
      or (throw "${pname} is only packaged for x86_64-linux and aarch64-linux");
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/steipete/CodexBar/releases/download/v${version}/${asset.name}";
    inherit (asset) hash;
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs =
    map lib.getLib [
      curl
      libxml2
      sqlite
    ]
    ++ [ stdenv.cc.cc.lib ];

  # Plugin scripts and VERSION sit beside the real executable in libexec,
  # where Swift resolves /proc/self/exe even when launched by the wrapper.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/libexec/codexbar $out/bin
    cp -a CodexBarCLI codexbar VERSION CodexBar_CodexBarCore.bundle $out/libexec/codexbar/
    chmod 755 $out/libexec/codexbar/CodexBarCLI $out/libexec/codexbar/codexbar
    # Upstream hardcodes these FHS paths. In particular, a failed launch of
    # /usr/bin/which reaches Process.terminationStatus and traps with SIGILL.
    # Keep the executable beside its bundle and redirect filesystem checks
    # and process launches without adding host-global compatibility links.
    makeWrapper $out/libexec/codexbar/CodexBarCLI $out/bin/codexbar \
      --prefix LD_PRELOAD : ${libredirect}/lib/libredirect.so \
      --prefix NIX_REDIRECTS : /usr/bin/which=${which}/bin/which:/bin/ps=${procps}/bin/ps:/usr/bin/ps=${procps}/bin/ps
    ln -s codexbar $out/bin/CodexBarCLI
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
    # Kiro runs /usr/bin/which; Antigravity runs /bin/ps.
    for provider in openai kiro antigravity; do
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

  meta = {
    description = "CLI for AI coding-provider usage limits";
    homepage = "https://github.com/steipete/CodexBar";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "codexbar";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
