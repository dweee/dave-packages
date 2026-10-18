{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_24,
  autoPatchelfHook,
  makeWrapper,
  makeBinaryWrapper,
  procps,
  util-linux,
}:
buildNpmPackage {
  pname = "rea";
  version = "6.7.0";

  src = fetchFromGitHub {
    owner = "morluto";
    repo = "rea";
    rev = "b0b485abff802b79d238dd24a9fa4abd0713d3ee";
    hash = "sha256-g0efGaxoVA5+pYOFHYv1eK8hln9937qz7PbFgSird5s=";
  };

  nodejs = nodejs_24;
  npmDepsHash = "sha256-/0IpFMbYquALq8kkrQMAZH9jWz61BPrJdvbtG/waG54=";
  patches = [ ./nixos-host.patch ];
  postPatch = ''
    # Frida's install script downloads a native runtime outside the npm lock.
    # Keep this package reproducible; active Frida instrumentation is optional.
    substituteInPlace package.json package-lock.json \
      --replace-fail '"frida": "17.23.2"' ' '
  '';

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [ makeBinaryWrapper ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];
  npmFlags = [
    "--ignore-scripts"
    "--no-audit"
    "--no-fund"
  ];
  npmInstallFlags = lib.optionals stdenv.hostPlatform.isLinux [ "--libc=glibc" ];
  env.HUSKY = "0";

  # Run the same compilation and skill generation without Turbo's task cache.
  buildPhase = ''
    runHook preBuild
    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      # Several optional packages omit npm's libc selector. NixOS uses the GNU
      # variants; do not retain their unusable musl alternatives.
      find node_modules -depth -type d -name '*-musl' -exec rm -rf {} +
      autoPatchelf node_modules
    ''}
    npm run compile
    node scripts/generate-skill-metadata.mjs
    node scripts/generate-skill-metadata.mjs --check
    runHook postBuild
  '';

  # Darwin requires a native executable as a shebang interpreter.
  postInstall = ''
    # lib/node_modules is interpreted as an npm-owned global installation by
    # REA's updater. Nix owns this package and its upgrade path instead.
    mv "$out/lib/node_modules/rea-agents" "$out/lib/rea-agents"
    rmdir "$out/lib/node_modules"
    rm "$out/bin/rea" "$out/bin/rea-agents"
    mkdir -p "$out/libexec" "$out/share/rea/skills"
    ${
      if stdenv.hostPlatform.isDarwin then "makeBinaryWrapper" else "makeWrapper"
    } ${nodejs_24}/bin/node "$out/libexec/rea-node" \
      --prefix PATH : ${
        lib.makeBinPath (
          [ nodejs_24 ]
          ++ lib.optionals stdenv.hostPlatform.isLinux [
            procps
            util-linux
          ]
        )
      }
    # All entry points, including direct registrations of the dispatcher, must
    # preserve the process-supervision prerequisites in child environments.
    sed -i '1c\#!'"$out/libexec/rea-node" "$out/lib/rea-agents/scripts/rea.mjs"
    chmod +x "$out/lib/rea-agents/scripts/rea.mjs"
    ln -s "$out/lib/rea-agents/scripts/rea.mjs" "$out/bin/rea"
    ln -s "$out/lib/rea-agents/scripts/rea.mjs" "$out/bin/rea-agents"
    rm -rf "$out/lib/rea-agents/node_modules/frida"
    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      find "$out/lib/rea-agents/node_modules" -depth -type d -name '*-musl' -exec rm -rf {} +
    ''}
    ln -s "$out/lib/rea-agents/skills/reverse-engineer-anything" \
      "$out/share/rea/skills/reverse-engineer-anything"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    ${nodejs_24}/bin/node ${./smoke-test.mjs} "$out"
    runHook postInstallCheck
  '';

  meta = {
    description = "CLI and stdio MCP server for evidence-based reverse engineering";
    homepage = "https://github.com/morluto/rea";
    license = lib.licenses.mit;
    mainProgram = "rea";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
