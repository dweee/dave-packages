{
  lib,
  cacert,
  rustPlatform,
  cmake,
  git,
  go,
  nasm,
  perl,
  pkg-config,
  python3,
}:
# Vendored fork of redlib-org/redlib @ a4d36e95 with named MAIN FEEDS
# (REDLIB_DEFAULT_FEEDS + cookie-backed feeds UI). See
# docs/superpowers/specs/2026-08-12-redlib-named-feeds-design.md
rustPlatform.buildRustPackage {
  pname = "redlib";
  version = "0.36.0-unstable-2026-04-24-feeds";

  src = ../../vendor/redlib;

  cargoHash = "sha256-eO3c7rlFna3DuO31etJ6S4c7NmcvgvIWZ1KVkNIuUqQ=";

  # cmake is only for boring-sys2; do not run cmake against the Rust crate.
  dontUseCmakeConfigure = true;

  nativeBuildInputs = [
    rustPlatform.bindgenHook
    cmake
    git
    go
    nasm
    perl
    pkg-config
    python3
  ];

  postInstall = ''
    install --mode=444 -D contrib/redlib.service $out/lib/systemd/system/redlib.service
    substituteInPlace $out/lib/systemd/system/redlib.service \
      --replace-fail "/usr/bin/redlib" "$out/bin/redlib"
  '';

  checkFlags = [
    "--skip=test_fetching_subreddit_quarantined"
    "--skip=test_fetching_nsfw_subreddit"
    "--skip=test_fetching_ws"
    "--skip=test_obfuscated_share_link"
    "--skip=test_share_link_strip_json"
    "--skip=test_localization_popular"
    "--skip=test_private_sub"
    "--skip=test_banned_sub"
    "--skip=test_gated_sub"
    "--skip=test_default_subscriptions"
    "--skip=test_rate_limit_check"
    "--skip=test_fetching_subreddit"
    "--skip=test_gated_and_quarantined"
    "--skip=test_fetching_user"
    "--skip=test_oauth_client"
    "--skip=test_oauth_client_refresh"
    "--skip=test_oauth_token_exists"
    "--skip=test_oauth_headers_len"
    "--skip=oauth::test_generic_web_backend"
    "--skip=oauth::test_mobile_spoof_backend"
    "--skip=oauth::tests::test_generic_web_backend"
    "--skip=oauth::tests::test_mobile_spoof_backend"
    # Preferences gained `feeds` (bincode layout change); re-export settings after upgrade.
    "--skip=utils::tests::test_known_good_configs_deserialization"
    "--skip=utils::tests::test_known_good_configs_full_round_trip"
  ];

  env = {
    SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
  };

  meta = {
    description = "Private front-end for Reddit (vendored; named MAIN FEEDS)";
    homepage = "https://github.com/redlib-org/redlib";
    license = lib.licenses.agpl3Only;
    mainProgram = "redlib";
  };
}
