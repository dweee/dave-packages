{
  lib,
  mkGithubComponent,
  home-assistant,
}:
mkGithubComponent {
  owner = "Loweack";
  repo = "Matter-Time-Sync";
  domain = "matter_time_sync";
  # Bumped by scripts/nix-update-flake-packages.sh (--version=branch + --override-filename).
  rev = "baa58c518898a82e3af5058ae25aafc3a143f8c6";
  version = "2.2.2-unstable-2026-06-24";
  hash = "sha256-ade77f7J6Uw6nEVLhJKmC8PtvYxStm9d6FVU4szql34=";

  # Manifest lists aiohttp; satisfy buildHomeAssistantComponent's manifestCheckPhase.
  dependencies = [home-assistant.python3Packages.aiohttp];

  doCheck = false;

  meta = with lib; {
    homepage = "https://github.com/Loweack/Matter-Time-Sync";
    description = "Synchronize time and timezone on Matter devices (e.g. IKEA ALPSTUGA)";
    license = licenses.mit;
  };
}
