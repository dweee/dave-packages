{
  lib,
  src,
  version,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "keyguard-instance-jni";
  inherit src version;

  sourceRoot = "${src.name}/util/instance/rust";

  cargoHash = "sha256-mEkkioRnecUFSQmewYD7YHWQTurgyl5+4Re6N3h9ek0=";

  cargoBuildFlags = [
    "--package"
    "keyguard-instance-jni"
  ];

  # These create private dirs/sockets, and validate_ancestors() requires every
  # ancestor to be owned by root or the build user. In the sandbox / is owned
  # by nobody (65534), so any path is refused (tests/processes.rs already uses
  # $TMPDIR and still fails). Skip only those; the rest of the suite runs.
  checkFlags = map (t: "--skip=${t}") [
    # tests/processes.rs
    "activation_before_first_receiver_is_retained_and_coalesced"
    "close_wakes_receiver_and_preserves_permanent_ownership_file"
    "identity_and_data_directory_scope_ownership"
    "invalid_active_socket_path_is_reported_instead_of_retried_to_timeout"
    "malformed_active_metadata_is_explicit_failure"
    "process_crash_releases_ownership_and_replaces_stale_endpoint"
    "simultaneous_processes_elect_exactly_one_primary"
    "stopped_or_unreachable_primary_never_allows_duplicate_ownership"
    # src/unix.rs + src/coordinator.rs
    "coordinator::tests::exhausted_recovery_retains_lease_and_explicit_stop_wakes_receiver"
    "coordinator::tests::listener_failure_recovers_without_releasing_ownership"
    "coordinator::tests::real_descriptor_exhaustion_recovers_after_descriptors_are_released"
    "coordinator::tests::repeated_worker_failures_share_a_budget_until_activation"
    "coordinator::tests::stop_interrupts_recovery_and_prevents_republication"
    "platform::tests::disconnect_before_ack_preserves_retryable_failure"
    "platform::tests::endpoint_collision_preserves_owner_and_drop_removes_owned_directory"
    "platform::tests::invalid_token_does_not_activate_and_listener_stays_healthy"
    "platform::tests::lease_is_exclusive_and_does_not_replace_or_remove_its_file"
    "platform::tests::ownership_file_validation_rejects_unlinked_handles"
    "platform::tests::private_metadata_is_bounded_and_atomic_replacement_remains_private"
    "platform::tests::private_metadata_rejects_hardlinks"
    "platform::tests::private_metadata_rejects_shared_permissions_even_after_unlink"
    "platform::tests::private_metadata_unlinked_after_open_is_retryable"
    "platform::tests::private_paths_reject_symlinks_hardlinks_and_shared_permissions"
    "platform::tests::raw_client_socket_suppresses_sigpipe_in_a_native_host"
    "platform::tests::recursive_creation_revalidates_intermediate_directories"
    "platform::tests::socket_creation_failure_removes_owned_endpoint_directory"
    "platform::tests::stop_wakes_idle_worker_and_partial_clients_without_waiting_for_timeout"
  ];

  meta = {
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
