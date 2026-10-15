{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  fclones,
  python3,
  gzip,
}:
stdenvNoCC.mkDerivation (_finalAttrs: {
  pname = "apfs-dedupe";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "curlewlabs-com";
    repo = "apfs-dedupe";
    rev = "6a757ba5044879e4e1b6d4b4f58293245a47c33d";
    hash = "sha256-O2eOW7G4SlDwkEKZ0FhFqUmm9WvPcrkcg5eOWyv7eVE=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/libexec/apfs-dedupe
    cp -a apfs-dedupe.sh lib $out/libexec/apfs-dedupe/
    chmod +x $out/libexec/apfs-dedupe/apfs-dedupe.sh
    makeWrapper $out/libexec/apfs-dedupe/apfs-dedupe.sh $out/bin/apfs-dedupe \
      --prefix PATH : ${
        lib.makeBinPath [
          fclones
          python3
          gzip
        ]
      }
    runHook postInstall
  '';

  meta = {
    description = "Crash-safe APFS clone deduplication using fclones for detection";
    homepage = "https://github.com/curlewlabs-com/apfs-dedupe";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
    mainProgram = "apfs-dedupe";
  };
})
