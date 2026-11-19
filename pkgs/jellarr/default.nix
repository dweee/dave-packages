{
  callPackage,
  fetchPnpmDeps,
  pnpm,
  src,
}:
# Jellarr with two compatibility fixes, until upstream carries them:
# - skip GET /Plugins/{id}/Configuration for plugins without ConfigurationFileName
#   (upstream 0.1.0 returns 404 for Air Times, Intro Skipper and similar plugins);
# - send `Authorization: MediaBrowser Token=…`, because Jellyfin 12 ignores
#   X-Emby-Token.
# pnpmDeps is refetched without pnpm 12's disposable v11/links virtual store,
# which upstream's hash includes.
(callPackage "${src}/nix/package.nix" { }).overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    ./skip-plugins-without-config-file.patch
    ./jellyfin12-authorization-header.patch
  ];
  pnpmDeps = fetchPnpmDeps {
    fetcherVersion = 4;
    inherit pnpm;
    preFixup = ''rm -rf "$storePath/v11/links"'';
    hash = "sha256-qNVnhHjTFPhJxJ8oZPBSfJs2OjNSlbmS31okZuSGWMU=";
    inherit (old) pname src version;
  };
})
