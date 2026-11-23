{
  sources = import ./sources.nix;
  retro-wfc-payload = ./pkgs/retro-wfc-payload.nix;
  disc = ./pkgs/disc.nix;
  translate = ./pkgs/translate.nix;
  game = ./pkgs/game.nix;
  game-macos = ./pkgs/game-macos.nix;
  compat-vr = {
    native-prebuilt = ./compat-vr/native-prebuilt.nix;
    translator = ./compat-vr/translator.nix;
  };
}
