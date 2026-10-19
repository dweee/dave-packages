{
  cacert,
  matrix-tuwunel,
  python3,
  symlinkJoin,
}: let
  unwrapped = matrix-tuwunel.overrideAttrs (old: {
    # Each database test creates its own CPU-scaled worker pool. Concurrent
    # pools exhaust container task limits; keep all tests, running one at a time.
    dontUseCargoParallelTests = true;
    patches =
      (old.patches or [])
      ++ [./authenticated-media-redirects.patch];
  });
in
  symlinkJoin {
    inherit (unwrapped) name pname version meta;
    paths = [unwrapped];
    nativeBuildInputs = [python3];
    # The host/CI can only realize this output after the HTTP regression passes.
    # A separate derivation lets fixture changes reuse the Rust build.
    postBuild = ''
      # Tuwunel initializes HTTPS clients even for this loopback-only fixture.
      SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt \
        python3 ${./test-authenticated-media.py} "$out/bin/tuwunel"
    '';
    passthru = (unwrapped.passthru or {}) // {inherit unwrapped;};
  }
