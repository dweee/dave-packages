{ linkwarden }:
linkwarden.overrideAttrs (old: {
  postInstall = (old.postInstall or "") + ''
    # Next serves compiled assets without webpack's incremental build cache.
    rm -rf "$out/share/linkwarden/apps/web/.next/cache/webpack"
    test -f "$out/share/linkwarden/apps/web/.next/BUILD_ID"
    test -d "$out/share/linkwarden/apps/web/.next/static"
  '';
})
