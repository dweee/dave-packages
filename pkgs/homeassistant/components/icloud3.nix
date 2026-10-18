{
  lib,
  mkGithubComponent,
  home-assistant,
}:
mkGithubComponent {
  owner = "gcobb321";
  repo = "icloud3";
  domain = "icloud3";
  version = "3.7.5";
  hash = "sha256-zAEMgcrz5NB+lHCz6zY0OxwbW1LebRdNCrcYoc+93Zc=";

  dependencies = with home-assistant.python3Packages; [
    srp
    fido2
  ];

  meta = with lib; {
    homepage = "https://github.com/gcobb321/icloud3";
    license = licenses.mit;
    description = "iCloud3 v3 - An advanced iDevice tracker that uses Apple iCloud account and HA Mobile App data for presence detection and location based automations.";
    maintainers = with maintainers; [dmadisetti];
  };
}
