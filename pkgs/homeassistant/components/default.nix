{pkgs}: let
  mkGithubComponent = pkgs.callPackage ./mk-component.nix {};
in {
  # Package set for Home Assistant custom integrations.
  # Add new custom integrations/modules here to avoid flake overlay churn.
  bilresaScrollwheelBlueprint =
    pkgs.callPackage ./bilresa-scrollwheel-blueprint.nix {};
  components = {
    icloud3 = pkgs.callPackage ./icloud3.nix {inherit mkGithubComponent;};
    torqueObd = pkgs.callPackage ./torque-obd.nix {inherit mkGithubComponent;};
    ukBinCollection = pkgs.callPackage ./uk-bin-collection.nix {};
    matterBindingHelper = pkgs.callPackage ./matter-binding-helper.nix {};
    matterTimeSync = pkgs.callPackage ./matter-time-sync.nix {inherit mkGithubComponent;};
    # exampleIntegration = pkgs.callPackage ./example-integration.nix {};
  };
}
