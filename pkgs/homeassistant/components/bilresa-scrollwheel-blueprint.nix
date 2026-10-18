{
  fetchurl,
  python3,
  runCommand,
}: let
  src = fetchurl {
    name = "ha-blueprint-ikea-bilresa-scrollwheel_en.yaml";
    url = "https://gist.githubusercontent.com/SvKRO/52f246362a19f0297fd18969b383181b/raw/416bfe06c97ed0708ddb507f1038a703ca5e0208/ha-blueprint-ikea-bilresa-scrollwheel_en.yaml";
    # Revision and hash refreshed together by update-manual-flake-pins.py.
    hash = "sha256-Aoc9yE1La3NkcyDc7WUlE0QINjvNHdW4iiwZNg/SuTM=";
  };
in
  runCommand "ha-blueprint-ikea-bilresa-scrollwheel_en.yaml" {
    inherit src;
    nativeBuildInputs = [python3];
  } ''
    python3 ${./patch-bilresa-scrollwheel-blueprint.py} "$src" "$out"
  ''
