# Thin wrapper over buildHomeAssistantComponent for components fetched
# straight from a GitHub repo.
{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
}: {
  owner,
  repo,
  domain,
  version,
  rev ? "v${version}",
  hash,
  dependencies ? [],
  doCheck ? true,
  meta ? {},
  postPatch ? null,
}:
buildHomeAssistantComponent (
  {
    inherit owner domain version dependencies doCheck meta;
    src = fetchFromGitHub {
      inherit owner repo rev hash;
    };
  }
  // lib.optionalAttrs (postPatch != null) {inherit postPatch;}
)
