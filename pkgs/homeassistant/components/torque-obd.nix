{
  lib,
  mkGithubComponent,
}:
mkGithubComponent {
  owner = "JOHLC";
  repo = "Home-Assistant-Torque-OBDII";
  domain = "torque_obd";
  # Pin: newer of refs/heads/main vs refs/heads/2025.12 (GitHub committer date). Bump via scripts/update-torque-obd.sh.
  rev = "3847a83653de7dca32d43ee70ac966e32c18e396";
  version = "0-unstable-2026-07-31";
  hash = "sha256-+ELQipPjuK0UM/ZwOdw5jEysBq3xWS7OrZUOGUJWjmk=";

  meta = with lib; {
    homepage = "https://github.com/JOHLC/Home-Assistant-Torque-OBDII";
    description = "Home Assistant custom integration for Torque Pro OBD-II telemetry";
    license = licenses.asl20;
  };
}
