{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  sqlite,
  versionCheckHook,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "tokscale";
  version = "4.20.1";

  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "junhoyeo";
    repo = "tokscale";
    tag = "v${finalAttrs.version}";
    hash = "sha256-0oDX180SDNlnKr2U3mBE4AOKat+DagennCpmxu4P0Tk=";
  };

  cargoHash = "sha256-Oh57ILq8GYWMXW5Ok/xhGnALHJx00bD+fmv7qoMU37w=";

  nativeBuildInputs = [pkg-config];
  buildInputs = [openssl sqlite];

  env.OPENSSL_NO_VENDOR = true;

  checkFlags = [
    # Assert systemd unit paths that are not set up on darwin builders
    "--skip=commands::autosubmit::tests::systemd_spec_honors_xdg_config_home"
    "--skip=commands::autosubmit::tests::systemd_spec_uses_autosubmit_run"
    # Resolve the host timezone, which the build sandbox does not provide
    "--skip=test_auto_pinning_never_overwrites_a_settings_file_it_could_not_read"
    "--skip=test_auto_pinning_recovers_from_a_bucket_timezone_that_names_no_zone"
    "--skip=test_first_run_pins_the_host_timezone_without_changing_its_own_output"
    "--skip=test_graph_single_day_filter_uses_local_timezone_boundaries"
    "--skip=test_submit_dry_run_preserves_local_date_ahead_of_utc"
    "--skip=test_unpinned_first_scan_still_buckets_by_the_host_timezone"
  ];

  nativeInstallCheckInputs = [versionCheckHook];
  doInstallCheck = true;

  meta = {
    description = "Token usage and cost tracker for Claude Code, Codex, OpenCode and other agent CLIs";
    homepage = "https://tokscale.ai";
    changelog = "https://github.com/junhoyeo/tokscale/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "tokscale";
  };
})
