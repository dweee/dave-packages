{ inputs, system }:
let
  upstream = inputs.t3-code.packages.${system};
  # Backport https://github.com/pingdotgg/t3code/pull/18700 (f50aad2422).
  # Both launchers must share the patched server and disk-backed Cursor SDK.
  sourceUnwrapped = upstream.t3code-nightly-source.sourceUnwrapped.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./cursor-max-mode.patch ];
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
