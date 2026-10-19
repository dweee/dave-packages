{ inputs, system }:
let
  inherit (inputs.nixpkgs) lib;
  upstream = inputs.t3-code.packages.${system};
  isLinux = lib.hasSuffix "-linux" system;
  # node-pty's install script keeps the upstream prebuilt pty.node whenever
  # prebuilds/<platform>-<arch> exists, so `pnpm rebuild` never compiles it.
  # That binary has no RUNPATH for libstdc++.so.6 on NixOS, and the server
  # dies with NodePtyModuleLoadError. Build it with Nix's toolchain instead
  # and drop the prebuilts so the loader cannot fall back to them.
  nodePtyGlob = "node_modules/.pnpm/node-pty@*/node_modules/node-pty";
  # Backport https://github.com/pingdotgg/t3code/pull/18700 (f50aad2422).
  # Both launchers must share the patched server and disk-backed Cursor SDK.
  sourceUnwrapped = upstream.t3code-nightly-source.sourceUnwrapped.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./cursor-max-mode.patch ];
    preBuild =
      (old.preBuild or "")
      + lib.optionalString isLinux ''
        for pty in ${nodePtyGlob}; do
          rm -rf "$pty/prebuilds"
          (cd "$pty" && node-gyp rebuild)
          # Keep only the module; node-gyp also leaves objects, Makefiles and
          # a node-addon-api stamp tree beside the package.
          find "$pty/build" -mindepth 1 \
            ! -path "$pty/build/Release" ! -path "$pty/build/Release/pty.node" -delete
          rm -rf "$pty"/node-addon-api@*
        done
      '';
    postInstall =
      (old.postInstall or "")
      + lib.optionalString isLinux ''
        for pty in "$out"/libexec/t3code/${nodePtyGlob}; do
          node -e 'require(process.argv[1])' "$pty"
        done
      '';
    doCheck = true;
    checkPhase = ''
      runHook preCheck
      pnpm --dir packages/provider-cursor exec vp test run src/server/sdk.test.ts
      runHook postCheck
    '';
    passthru = (old.passthru or { }) // {
      cursorMaxModePatched = true;
    };
  });
in
{
  t3code-nightly = upstream.t3code-nightly-source.override { inherit sourceUnwrapped; };
  t3code-server-nightly = upstream.t3code-server-nightly-source.override { inherit sourceUnwrapped; };
}
