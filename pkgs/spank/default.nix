{
  lib,
  buildGoModule,
  fetchFromGitHub,
  go_1_26,
}:
buildGoModule.override {go = go_1_26;} rec {
  pname = "spank";
  version = "1.3.0-unstable-2026-08-23";

  src = fetchFromGitHub {
    owner = "taigrr";
    repo = "spank";
    rev = "a5f95a002fb29dfc3f705b74565d656239976a54";
    hash = "sha256-ODylZ9hGk/xGH2BCrQ3sOQW3GNKLCHPUmYc0Ca4xRxw=";
  };

  vendorHash = "sha256-7kF9yM952tWcrRRqxAxpfo5430VHloCVCIIwLxw5Mqk=";

  ldflags = ["-s" "-w"];

  doCheck = false;

  meta = {
    description = "Yells 'ow!' when you slap the laptop";
    homepage = "https://github.com/taigrr/spank";
    license = lib.licenses.mit;
    platforms = ["aarch64-darwin"];
    mainProgram = "spank";
  };
}
