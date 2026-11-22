{
  lib,
  runCommand,
  writeShellScript,
  writeShellScriptBin,
  pkgs,
  python3,
  source,
}:
let
  package = writeShellScriptBin "pared" ''
    printf '%s\n' "$*" >> calls
    exit "''${PARED_TEST_EXIT:-0}"
  '';
  cleanup = writeShellScript "pared-cleanup-test" (
    import (source + "/nix/cleanup.nix") {
      inherit lib pkgs package;
      policyFile = "policy.json";
      stateDirectory = "state with spaces";
      profilePath = "profile.mobileconfig";
    }
  );
in
runCommand "pared-activation-regression" { nativeBuildInputs = [ python3 ]; } ''
  python3 ${./activation-test.py} ${cleanup}
  touch "$out"
''
