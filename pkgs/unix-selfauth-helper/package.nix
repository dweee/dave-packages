{
  lib,
  stdenv,
  fetchurl,
  pam,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "unix-selfauth-helper";
  version = "1.1";
  src = fetchurl {
    url = "https://github.com/Zirias/unix-selfauth-helper/releases/download/v${finalAttrs.version}/unix-selfauth-helper-${finalAttrs.version}.tar.xz";
    hash = "sha256-qSwSacWVBCXfTu6cuj2WUJgHporHlz9DDzp8JTij/yk=";
  };
  strictDeps = true;
  buildInputs = [ pam ];
  dontConfigure = true;
  buildPhase = ''
    runHook preBuild
    $CC -O2 -Wall -Wextra unix-selfauth-helper.c -lcrypt -o unix-selfauth-helper
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    # Privilege is supplied by the OS wrapper, never by the store output.
    install -Dm555 unix-selfauth-helper "$out/libexec/unix-selfauth-helper"
    mkdir -p "$out/share/man/man8"
    substitute unix-selfauth-helper.8.in "$out/share/man/man8/unix-selfauth-helper.8" \
      --replace-fail '%%PREFIX%%' "$out"
    runHook postInstall
  '';
  meta = {
    description = "FreeBSD PAM helper for checking the invoking user's own password";
    homepage = "https://github.com/Zirias/unix-selfauth-helper";
    license = lib.licenses.bsd2;
    platforms = lib.platforms.freebsd;
  };
})
