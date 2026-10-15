{
  lib,
  buildGoModule,
  fetchFromGitHub,
  ...
}:
buildGoModule rec {
  pname = "infrared";
  version = "2.0.0-alpha.r2";

  src = fetchFromGitHub {
    owner = "haveachin";
    repo = "infrared";
    rev = "v${version}";
    hash = "sha256-dbAwOpRSDzcHtOO34FxKWLyNEEJUIvsSuysdUcu5Y9w=";
  };

  vendorHash = "sha256-CxMYSRG9yPY6zJyvmpVGz3VkL1trAd1Qg/RLRl3scAY=";

  meta = with lib; {
    description = "An ultra lightweight minecraft reverse proxy and idle placeholder";
    homepage = "https://github.com/haveachin/infrared";
    license = licenses.asl20;
  };
}
