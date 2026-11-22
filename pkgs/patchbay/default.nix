{
  lib,
  stdenv,
  fetchurl,
  source,
  jdk25,
  python3,
  nodejs,
  cctools,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  runtimeShell,
  coreutils,
  findutils,
  gnugrep,
  gnused,
  procps,
  util-linux,
}:
let
  # The window's bundled fonts (SIL OFL), git-ignored in the repository; the sources and SHA-256 of
  # loader/src/loader/app/resources/dev/bitwigre/bml/fonts/FONTS.md, pinned to the commits that last
  # changed each file.
  fonts =
    let
      outfit = "https://raw.githubusercontent.com/Outfitio/Outfit-Fonts";
      mono = "https://raw.githubusercontent.com/JetBrains/JetBrainsMono";
    in
    {
      "Outfit-Regular.ttf" = fetchurl {
        url = "${outfit}/902773808eb372f70fb34e8946dd1ffe604efc79/fonts/ttf/Outfit-Regular.ttf";
        sha256 = "3b64ac4f6ab6a8eebddd4b0bc03c811c43602e11e176382ab0ee6be615ab861b";
      };
      "Outfit-SemiBold.ttf" = fetchurl {
        url = "${outfit}/902773808eb372f70fb34e8946dd1ffe604efc79/fonts/ttf/Outfit-SemiBold.ttf";
        sha256 = "bf2e1d2a6ec2a67952e8b36edd2b2bb9f340c0cdd10b0ad5145b4dbbc1339608";
      };
      "OFL-Outfit.txt" = fetchurl {
        url = "${outfit}/070d0e3c2aabbf78957511a7c2ed00009b1e72d6/OFL.txt";
        sha256 = "c676351bf8576b9aba743cd5eaa8c0e7ee0d51f805d720447b4df4ddb6a2e416";
      };
      "JetBrainsMono-Regular.ttf" = fetchurl {
        url = "${mono}/02bb50b082dad9ef8a0f33ac393839202b760223/fonts/ttf/JetBrainsMono-Regular.ttf";
        sha256 = "e6fd0d7e91550b3ed2b735d4312474362c4716edc4fc0577a0f61ed782d5aed1";
      };
      "OFL-JetBrainsMono.txt" = fetchurl {
        url = "${mono}/61cf0cedc2d9d29efcab968e97707d6899133e68/OFL.txt";
        sha256 = "a76abf002c49097d146e86740a3105a5d00450b1592e820a1109a8c5680cd697";
      };
    };

  # tool_jar_sha256 of the official releases BML-0.36.0-dev.9 and dev.14 (Windows, Oracle JDK
  # 25.0.4.1; the same in both). This build must give the same jars; when upstream changes a tool's
  # source (loader/src/loader/tools/src), take its hash from the new release's RELEASE-MANIFEST.json.
  releaseToolJars = {
    "bitwig-access-widener.jar" = "1a396dd3a6ed7fac4d23b60044155efbec813769b588d418254285bcadaa27c6";
    "bitwig-add-method-patcher.jar" =
      "7034320f49df25f0dfc62c4f17c0e3bda6cabfa96189c6bf1d866a5a5a0c8249";
    "bitwig-deep-verifier.jar" = "b42cbc7267838eeaf9f98d27a7de825f3f509ca3fd30432dbe0e11e619c37551";
    "bitwig-field-adder.jar" = "2c721eeccaf71da5cba8fe118796e34a1de100b16082fb50530624cfc5546d5d";
    "bitwig-helper-remapper.jar" = "d0c0c755ee5c45b3e250028d04fdae30dbcf36a205578dda4bb46e8016b1f262";
    "bitwig-invoke-replacer.jar" = "6957de68b561db41381b77a0ae766fd1cfa75ec99f8e8bc79ec4cc02a60c55f0";
    "bitwig-mod-preparer.jar" = "0c4d0a4adae4fc30c3679ab8c1e48973757c668e4d5ea4b2c2ef42826d12c9b7";
    "bitwig-typed-local-patcher.jar" =
      "7ee6921d6d3a18aecdc836d6ea2ec5a052b116c6accedb81b32586b1f16d861a";
  };
  # The same releases' modkit/bml-modkit.jar (modkit/src/tool).
  releaseModkitJar = "67377ec1ca657b07fa2d9ebdef447a00b5d7c4f58fb7358e5b44ca50e7520258";
  # api_jar_sha256 of BML-0.36.0-dev.14 (loader/src/loader/api/src); modkit builds the same jar.
  releaseApiJar = "276d9c6d0d7e7a88a147eb998beb65576bee16a5b2098becd1f16b4e8db88ebc";

  # What the build and its checks read; generated files and the git-ignored fonts are left out.
  wanted = [
    "LICENSE"
    "THIRD_PARTY_NOTICES.md"
    "loader/build.py"
    "loader/src"
    "modkit/build.py"
    "modkit/src"
    "tools/workspace.py"
    "frameworks/notifications-framework/src"
    "frameworks/notifications-framework/test"
    "frameworks/plugin-panels-framework/builder"
    "frameworks/plugin-panels-framework/test-layouts"
  ];
  generated = [
    ".jar"
    ".class"
    ".so"
    ".dylib"
    ".dll"
    ".pyc"
    ".ttf"
  ];

  loaderVersion =
    let
      java = builtins.readFile (source + "/loader/src/loader/app/src/dev/bitwigre/bml/JavaPreparer.java");
      found = map (builtins.match ''.*LOADER_VERSION *= *"([^"]+)".*'') (lib.splitString "\n" java);
    in
    builtins.head (lib.findFirst (m: m != null) (throw "LOADER_VERSION not found") found);

  # sh tools the loader's scripts call; appended to PATH, so the system's own come first.
  runtimePath = lib.makeBinPath (
    [
      coreutils
      findutils
      gnugrep
      gnused
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      procps
      util-linux
    ]
  );
in
stdenv.mkDerivation {
  pname = "patchbay";
  version = loaderVersion;

  src = lib.cleanSourceWith {
    src = source;
    name = "patchbay-source";
    filter =
      path: type:
      let
        relative = lib.removePrefix (toString source + "/") (toString path);
        base = baseNameOf path;
      in
      lib.any (
        w: relative == w || lib.hasPrefix (w + "/") relative || lib.hasPrefix (relative + "/") w
      ) wanted
      && !(lib.any (s: lib.hasSuffix s base) generated)
      && !(lib.hasPrefix "OFL-" base)
      && base != "__pycache__";
  };

  # Upstream's loader build script is tracked with CRLF line endings.
  prePatch = ''
    sed -i 's/\r$//' loader/build.py
  '';
  patches = [ ./build-and-environment.patch ];

  nativeBuildInputs = [
    jdk25
    python3
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ copyDesktopItems ];

  nativeCheckInputs = [ nodejs ];

  desktopItems = lib.optionals stdenv.hostPlatform.isLinux [
    (makeDesktopItem {
      name = "patchbay";
      desktopName = "Patchbay";
      genericName = "Bitwig Studio mod loader";
      comment = "Choose the mods BML loads into Bitwig Studio, and start Bitwig with them";
      exec = "patchbay";
      terminal = false;
      categories = [
        "AudioVideo"
        "Audio"
      ];
    })
  ];

  env = {
    BML_JDK_HOME = jdk25.home;
    # modkit/build.py reads <workspace>/workspace.json when there is one; keep it out of the sandbox's parent.
    BML_WORKSPACE = "/var/empty";
  };

  # The loader's scripts are run as shipped (#!/usr/bin/env sh, /bin/bash for BML.command), and the
  # agent is linked stripped: the root is copied out of the store as it is.
  dontPatchShebangs = true;
  dontStrip = true;

  postPatch = ''
    fonts=loader/src/loader/app/resources/dev/bitwigre/bml/fonts
    ${lib.concatStrings (lib.mapAttrsToList (name: file: "cp ${file} \"$fonts/${name}\"\n") fonts)}
  '';

  buildPhase = ''
    runHook preBuild
    ${lib.optionalString stdenv.hostPlatform.isDarwin ''
      # clang links the universal agent per architecture and joins the two with lipo
      mkdir -p "$TMPDIR/lipo-bin"
      ln -s ${lib.getExe' cctools "lipo"} "$TMPDIR/lipo-bin/lipo"
      export PATH="$TMPDIR/lipo-bin:$PATH"
    ''}
    python3 loader/build.py --host --stage "$PWD/build/bml"
    python3 modkit/build.py
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    # the tool jars are byte for byte those of the release
    ${lib.concatStrings (
      lib.mapAttrsToList (jar: hash: ''
        echo "${hash}  build/bml/loader/tools/${jar}" | sha256sum -c -
      '') releaseToolJars
    )}
    echo "${releaseModkitJar}  modkit/out/bml-modkit.jar" | sha256sum -c -
    echo "${releaseApiJar}  build/bml/loader/api/bml-api.jar" | sha256sum -c -
    echo "${releaseApiJar}  modkit/out/bml-api.jar" | sha256sum -c -
    # notifications-framework's offline tests (no Bitwig jar needed)
    javac -nowarn -encoding UTF-8 -d "$TMPDIR/notifications-test" \
      -sourcepath frameworks/notifications-framework/src:loader/src/loader/api/src \
      frameworks/notifications-framework/test/*.java
    for t in StylersTest TextTest ToastTest WatchersTest; do
      java -cp "$TMPDIR/notifications-test" "$t"
    done
    # plugin-panels builder: the sample layouts read the same after export
    node frameworks/plugin-panels-framework/builder/test/roundtrip.js \
      frameworks/plugin-panels-framework/test-layouts/*.json
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share"
    cp -R build/bml "$out/share/bml"
    install -Dm644 modkit/out/bml-api.jar "$out/share/bml/modkit/bml-api.jar"
    install -Dm644 modkit/out/bml-modkit.jar "$out/share/bml/modkit/bml-modkit.jar"
    for notice in LICENSE THIRD_PARTY_NOTICES.md; do
      install -Dm644 "$notice" "$out/share/doc/patchbay/$notice"
    done

    install -Dm755 ${./bml-root.sh} "$out/libexec/patchbay/bml-root"
    substituteInPlace "$out/libexec/patchbay/bml-root" \
      --replace-fail "@shell@" "${runtimeShell}" \
      --replace-fail "@share@" "$out/share/bml"
    makeWrapper "$out/libexec/patchbay/bml-root" "$out/bin/patchbay" \
      --add-flags bml-ui.sh \
      --set-default BML_JAVA ${jdk25}/bin/java \
      --suffix PATH : ${runtimePath}
    makeWrapper "$out/libexec/patchbay/bml-root" "$out/bin/bml-launch-bitwig" \
      --add-flags launch-bitwig.sh \
      --set-default BML_JAVA ${jdk25}/bin/java \
      --suffix PATH : ${runtimePath}
    makeWrapper ${jdk25}/bin/java "$out/bin/bml-modkit" \
      --add-flags "-jar $out/share/bml/modkit/bml-modkit.jar"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    root="$out/share/bml"
    grep -q '"host_build": true' "$root/RELEASE-MANIFEST.json"
    grep -q '"control_jar_fonts": "bundled"' "$root/RELEASE-MANIFEST.json"
    ${
      if stdenv.hostPlatform.isDarwin then
        ''
          test ! -e "$root/loader/jvmti/bin/bitwig-jvmti-tracer.so"
          "$TMPDIR/lipo-bin/lipo" -info "$root/loader/jvmti/bin/bitwig-jvmti-tracer.dylib" | tee "$TMPDIR/lipo.txt"
          grep -q x86_64 "$TMPDIR/lipo.txt"
          grep -q arm64 "$TMPDIR/lipo.txt"
        ''
      else
        ''
          test -f "$root/loader/jvmti/bin/bitwig-jvmti-tracer.so"
          test ! -e "$root/loader/jvmti/bin/bitwig-jvmti-tracer.dylib"
          test ! -e "$root/BML.command"
        ''
    }
    test -x "$root/bml-ui.sh" && test -x "$root/launch-bitwig.sh"

    # the window's data side, headless, on a scratch copy of the root
    cp -R "$root" "$TMPDIR/self-test-root"
    chmod -R u+w "$TMPDIR/self-test-root"
    (cd "$TMPDIR" && HOME="$TMPDIR" XDG_CONFIG_HOME="$TMPDIR/config" \
      ${jdk25}/bin/java -Djava.awt.headless=true -Dbml.root="$TMPDIR/self-test-root" \
        -jar "$TMPDIR/self-test-root/loader/app/bml-control.jar" --self-test) | tee "$TMPDIR/self-test.txt"
    grep -q '^SELF_TEST_OK' "$TMPDIR/self-test.txt"

    "$out/bin/bml-modkit" 2>&1 | tee "$TMPDIR/modkit.txt" || true
    grep -qi usage "$TMPDIR/modkit.txt"

    # the writable root: made on first run, synced again when the package changes, user data kept
    # (loader/platform.sh, run as a script, prints nothing)
    export HOME="$TMPDIR/home" BML_ROOT="$TMPDIR/home/bml"
    mkdir -p "$BML_ROOT/mods"
    test -z "$("$out/libexec/patchbay/bml-root" loader/platform.sh)"
    test "$(cat "$BML_ROOT/.nix-store-path")" = "$root"
    printf '#!/bin/sh\necho "PROBE $*"\n' > "$BML_ROOT/probe.sh"
    chmod +x "$BML_ROOT/probe.sh"
    test "$("$out/libexec/patchbay/bml-root" probe.sh a b)" = "PROBE a b"
    test ! -e "$BML_ROOT/.nix-store-lock"
    test -w "$BML_ROOT/loader/app/bml-control.jar"
    test -x "$BML_ROOT/bml-ui.sh"
    cmp "$root/loader/app/bml-control.jar" "$BML_ROOT/loader/app/bml-control.jar"
    mkdir -p "$BML_ROOT/mods/my-mod" "$BML_ROOT/config" "$BML_ROOT/loader/mod-runtime" "$BML_ROOT/old"
    echo mine > "$BML_ROOT/mods/my-mod/mod.json"
    echo mine > "$BML_ROOT/config/bml.properties"
    echo mine > "$BML_ROOT/loader/mod-runtime/build-info.txt"
    echo changed > "$BML_ROOT/README.md"
    echo mine > "$BML_ROOT/loader/diagnostics/trace-targets.tsv"
    mkdir -p "$BML_ROOT/loader/jvmti/reports/trace-1"
    echo mine > "$BML_ROOT/loader/jvmti/reports/trace-1/trace.tsv"
    echo loader/jvmti/reports/trace-1/trace.tsv >> "$BML_ROOT/.nix-store-files"
    echo stale > "$BML_ROOT/old/file"
    echo old/file >> "$BML_ROOT/.nix-store-files"
    echo mods/my-mod/mod.json >> "$BML_ROOT/.nix-store-files"
    echo /nix/store/00000000000000000000000000000000-patchbay-old/share/bml > "$BML_ROOT/.nix-store-path"
    test "$("$out/libexec/patchbay/bml-root" probe.sh)" = "PROBE "
    test "$(cat "$BML_ROOT/.nix-store-path")" = "$root"
    cmp "$root/README.md" "$BML_ROOT/README.md"
    test ! -e "$BML_ROOT/old/file"
    test "$(cat "$BML_ROOT/mods/my-mod/mod.json")" = mine
    test "$(cat "$BML_ROOT/config/bml.properties")" = mine
    test "$(cat "$BML_ROOT/loader/mod-runtime/build-info.txt")" = mine
    test "$(cat "$BML_ROOT/loader/diagnostics/trace-targets.tsv")" = mine
    test "$(cat "$BML_ROOT/loader/jvmti/reports/trace-1/trace.tsv")" = mine
    test -x "$BML_ROOT/probe.sh"
    test -z "$(find "$BML_ROOT" -maxdepth 1 -name '.nix-store-files.*')"

    # first syncs at once into one new root: one copies, the others wait, all succeed
    export BML_ROOT="$TMPDIR/home/parallel"
    pids=
    for i in 1 2 3 4 5 6 7 8; do
      "$out/libexec/patchbay/bml-root" loader/platform.sh > "$TMPDIR/parallel-$i.txt" 2>&1 &
      pids="$pids $!"
    done
    for pid in $pids; do wait "$pid"; done
    cat "$TMPDIR"/parallel-*.txt
    test "$(cat "$BML_ROOT/.nix-store-path")" = "$root"
    (cd "$root" && find . ! -type d | LC_ALL=C sort) > "$TMPDIR/store-files.txt"
    (cd "$BML_ROOT" && find . ! -type d ! -name '.nix-store-*' | LC_ALL=C sort) | diff "$TMPDIR/store-files.txt" -
    diff -r "$root" "$BML_ROOT" -x '.nix-store-*'
    test ! -e "$BML_ROOT/.nix-store-lock"
    # a lock left by a process that is gone is taken over
    rm "$BML_ROOT/.nix-store-path"
    mkdir "$BML_ROOT/.nix-store-lock"
    sh -c 'echo $$' > "$BML_ROOT/.nix-store-lock/pid"
    test -z "$("$out/libexec/patchbay/bml-root" loader/platform.sh)"
    test "$(cat "$BML_ROOT/.nix-store-path")" = "$root"

    # refused: a relative BML_ROOT, and a folder that holds something else than BML
    rc=0; BML_ROOT=relative "$out/libexec/patchbay/bml-root" loader/platform.sh 2> "$TMPDIR/err.txt" || rc=$?
    test "$rc" = 2 && grep -q 'absolute' "$TMPDIR/err.txt"
    mkdir -p "$TMPDIR/home/other"
    echo mine > "$TMPDIR/home/other/notes.txt"
    rc=0; BML_ROOT="$TMPDIR/home/other" "$out/libexec/patchbay/bml-root" loader/platform.sh 2> "$TMPDIR/err.txt" || rc=$?
    test "$rc" = 2 && grep -q 'not BML' "$TMPDIR/err.txt"
    test "$(ls -A "$TMPDIR/home/other")" = notes.txt
    export BML_ROOT="$TMPDIR/home/bml"

    # the launcher through the wrapper, platform.sh and BML_BITWIG_EXECUTABLE, without a Bitwig
    rc=0
    BML_BITWIG_EXECUTABLE=/nonexistent/bitwig-studio "$out/bin/bml-launch-bitwig" > "$TMPDIR/launch.txt" 2>&1 || rc=$?
    cat "$TMPDIR/launch.txt"
    test "$rc" = 2
    grep -q '/nonexistent/bitwig-studio' "$TMPDIR/launch.txt"
    runHook postInstallCheck
  '';

  meta = {
    description = "Patchbay Mod Loader (BML): loads opt-in mods into Bitwig Studio";
    homepage = "https://github.com/shaboogen-dev/Patchbay";
    license = lib.licenses.mit;
    mainProgram = "patchbay";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
