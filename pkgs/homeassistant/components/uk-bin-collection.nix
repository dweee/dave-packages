{
  lib,
  buildHomeAssistantComponent,
  home-assistant,
}: let
  ukBinCollectionLib = home-assistant.python3Packages.callPackage ./uk-bin-collection-lib.nix {
    inherit lib home-assistant;
  };
in
  buildHomeAssistantComponent {
    owner = "robbrad";
    domain = "uk_bin_collection";
    inherit (ukBinCollectionLib) version src;

    # The repo root has a Makefile whose default target runs `poetry install`.
    # This component package only needs the custom install phase from
    # `buildHomeAssistantComponent`, so skip the generic build step entirely.
    dontBuild = true;

    # skip_get_url is a store_true CLI flag. Emitting --skip_get_url=True is
    # invalid, so the integration excluded the key entirely — councils that
    # require skip_get_url then paid for a second get_data() with timeout=120
    # and 5 retries, which exceeds the coordinator's 60s wait_for.
    postPatch = ''
      python3 ${./uk-bin-collection-postpatch.py}
    '';

    dependencies = [
      ukBinCollectionLib
    ];

    doCheck = false;

    meta = with lib; {
      homepage = "https://github.com/robbrad/UKBinCollectionData";
      license = licenses.mit;
      description = "Home Assistant integration and Python library for UK council bin collection data.";
    };
  }
