# Shell that turns a Horizon release folder in $out/libexec/horizon into
# commands in $out/bin. Shared by the source builds and the prebuilt ones.
{
  lib,
  stdenv,
  coreutils,
  jdk25_headless,
}:

{
  headless,
  # The game program: the server folder names its build horizon-engine.
  game ? if headless then "horizon-engine" else "horizon-client",
  runtimeLibraries ? [ ],
}:
''
  folder="$out/libexec/horizon"
  mkdir -p "$out/bin"
  install -Dm755 ${./prepare-wrapper.sh} "$folder/prepare-wrapper.sh"
  patchShebangs "$folder/prepare-wrapper.sh"
  ${lib.optionalString (stdenv.hostPlatform.isLinux && runtimeLibraries != [ ]) ''
    patchelf --add-rpath ${lib.makeLibraryPath runtimeLibraries} "$folder/${game}"
  ''}
  # horizon-prepare writes beside its --root, so it prepares in a writable
  # copy of the folder's sources; horizon-server must not update itself.
  makeWrapper "$folder/prepare-wrapper.sh" "$out/bin/horizon-prepare" \
    --set HORIZON_PREPARE_FOLDER "$folder" \
    --set-default JAVA_HOME ${jdk25_headless.home} \
    --prefix PATH : ${
      lib.makeBinPath [
        jdk25_headless
        coreutils
      ]
    }
  makeWrapper "$folder/horizon-server" "$out/bin/horizon-server" \
    --set-default HORIZON_NO_UPDATE_CHECK 1
  ${lib.optionalString (!headless) ''
    makeWrapper "$folder/horizon-client" "$out/bin/horizon-client"
    if [ -e "$folder/horizon-ctl" ]; then
      makeWrapper "$folder/horizon-ctl" "$out/bin/horizon-ctl"
    fi
  ''}
''
