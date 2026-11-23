{ python3, codex-desktop }:
codex-desktop.overrideAttrs (old: {
  disallowedReferences = (old.disallowedReferences or [ ]) ++ [ codex-desktop.upstreamDeb ];
  postInstall = (old.postInstall or "") + ''
    ${python3}/bin/python ${./normalize-build-info.py} "$out/opt/codex-desktop" \
      "${builtins.baseNameOf (toString codex-desktop.upstreamDeb)}"
  '';
})
