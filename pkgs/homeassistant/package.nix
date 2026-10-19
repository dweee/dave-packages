{ pkgs }:
let
  components = (import ./components { inherit pkgs; }).components;
  customComponents = [
    components.icloud3
    pkgs.home-assistant-custom-components.octopus_energy
    components.torqueObd
    components.ukBinCollection
    components.matterBindingHelper
    components.matterTimeSync
  ];
  base = pkgs.home-assistant.overrideAttrs (_: {
    doInstallCheck = false;
  });
in
base.override {
  extraComponents = builtins.fromJSON (builtins.readFile ./components.json);
  extraPackages =
    ps:
    (with ps; [
      bellows
      numpy
      aiodhcpwatcher
      aiodiscover
      gtts
      psycopg2
      universal-silabs-flasher
      zha-quirks
      zigpy-cc
      zigpy-deconz
      zigpy-xbee
      zigpy-znp
      zigpy-zigate
      pydantic
    ])
    ++ pkgs.lib.concatMap (component: component.propagatedBuildInputs or [ ]) customComponents;
}
