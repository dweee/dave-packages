{
  lib,
  buildHomeAssistantComponent,
  buildNpmPackage,
  fetchFromGitHub,
  fetchNpmDeps,
}: let
  owner = "cedricziel";
  repo = "ha-matter-binding-helper";
  domain = "matter_binding_helper";
  # Bump: nix shell nixpkgs#nix-prefetch-github -c nix-prefetch-github cedricziel ha-matter-binding-helper --rev main
  rev = "v0.35.11";
  version = "0.35.11";
  hash = "sha256-mBBbA5y81IqDGiApl6pa9duMnjDIalB74xV9jzZgsR0=";

  src = fetchFromGitHub {
    inherit owner repo rev hash;
  };

  # Upstream ships no built panel JS (gitignored); HACS uses a release zip.
  # package-lock resolves @matter-survey/device-definitions via git+ssh — unusable in the sandbox.
  patchGithubSshToHttps = ''
    substituteInPlace package.json \
      --replace-fail \
        '"@matter-survey/device-definitions": "github:matter-survey/device-definitions"' \
        '"@matter-survey/device-definitions": "git+https://github.com/matter-survey/device-definitions.git#4fcf3c04ef3867cff0f31ce118858e4fe4293857"'
    if [[ -f package-lock.json ]]; then
      substituteInPlace package-lock.json \
        --replace-fail 'git+ssh://git@github.com/' 'git+https://github.com/'
    fi
  '';

  frontend = buildNpmPackage {
    pname = "matter-binding-helper-frontend";
    inherit version src;

    sourceRoot = "${src.name}/frontend";

    npmDeps = fetchNpmDeps {
      inherit src;
      sourceRoot = "${src.name}/frontend";
      name = "matter-binding-helper-frontend-npm-deps";
      # After changing package-lock / HTTPS patch: patch lock locally then
      # nix shell nixpkgs#prefetch-npm-deps -c prefetch-npm-deps package-lock.json
      hash = "sha256-n9FQurl5e9D6EGD/1ItbYLcldbk7f1aARyuWr68RoIM=";
      postPatch = patchGithubSshToHttps;
    };

    postPatch =
      patchGithubSshToHttps
      + ''
        # Nix store / build sources are read-only; write panel bundle into frontend/dist.
        substituteInPlace rollup.config.js \
          --replace-fail \
            'file: "../custom_components/matter_binding_helper/frontend/matter-binding-panel.js"' \
            'file: "dist/matter-binding-panel.js"'
        substituteInPlace rollup.config.js \
          --replace-fail \
            'outDir: "../custom_components/matter_binding_helper/frontend"' \
            'outDir: "dist"'
      '';

    makeCacheWritable = true;
    npmBuildScript = "build";

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist/. $out/
      runHook postInstall
    '';

    meta = {
      description = "Built Lit panel for ha-matter-binding-helper";
      license = lib.licenses.mit;
    };
  };
in
  buildHomeAssistantComponent {
    inherit owner domain version src;

    doCheck = false;

    # v0.35.1+ already uses entry.runtime_data / async_entries for HA Matter;
    # the old ha2026-runtime-data.patch is no longer needed.

    postInstall = ''
      mkdir -p $out/custom_components/matter_binding_helper/frontend
      cp -r ${frontend}/. $out/custom_components/matter_binding_helper/frontend/
    '';

    passthru = {inherit frontend;};

    meta = with lib; {
      homepage = "https://github.com/cedricziel/ha-matter-binding-helper";
      description = "UI for viewing and managing Matter bindings via the Matter server";
      license = licenses.mit;
    };
  }
