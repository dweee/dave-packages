{ lib, stdenv, atuin }:
atuin.overrideAttrs (old:
  lib.optionalAttrs stdenv.hostPlatform.isDarwin {
    # PTY fixtures must run the tested executable, independently of /etc/bashrc.
    checkFlags = (old.checkFlags or [ ]) ++ [ "--test-threads=1" ];
    postPatch = (old.postPatch or "") + ''
      substituteInPlace crates/atuin/tests/common/mod.rs \
        --replace-fail '("HOME".into(), home.display().to_string()),' \
          '("HOME".into(), home.display().to_string()), ("NOSYSBASHRC".into(), "1".into()),'
    '';
  })
