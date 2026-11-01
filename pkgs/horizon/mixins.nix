# horizon-mixins, the tool that applies native mods (mixin bundles) to the
# game's Rust source before it is compiled. Pinned to the commit the
# launcher's native-mod builds use (launcher/src/native_mods.rs MIXINS_REV).
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pin,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "horizon-mixins";
  inherit (pin) version cargoHash;

  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "horizon-rust";
    repo = "horizon-mixins";
    inherit (pin) rev hash;
  };

  cargoBuildFlags = [ "--package=horizon-mixins-cli" ];
  # The fixtures build whole workspaces and need the network.
  doCheck = false;

  meta = {
    description = "Applies mixin bundles to Horizon's Rust source (Horizon's native mods)";
    homepage = "https://github.com/horizon-rust/horizon-mixins";
    license = lib.licenses.mit;
    mainProgram = "horizon-mixins";
  };
})
