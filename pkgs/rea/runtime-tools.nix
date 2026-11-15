# Keep engine selection in the package so CLI aliases, direct dispatcher and MCP
# clients work without an ambient user profile. Callers can override each default.
{
  lib,
  stdenv,
  swift,
  apple-sdk,
  fetchurl,
  fetchFromGitHub,
  wabt,
  openssl,
  sigrok-cli,
  python3,
  mitmproxy,
  unicorn,
  jdk21,
  apktool,
  android-tools,
  ilspycmd,
  binutils,
  rizin,
  gdb,
  binwalk,
  unblob,
  wireshark-cli,
  util-linux,
}:
let
  # REA requires the metadata bridge classes in this fat JAR, not the JADX CLI.
  # Matches upstream REA's android/JadxRelease.ts; the release asset is hashed.
  jadxMcpJar = fetchurl {
    url = "https://github.com/1013503897/jadx-headless-mcp/releases/download/v0.7.1/jadx-headless-mcp-0.7.1-all.jar";
    sha256 = "6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75";
    meta = {
      license = lib.licenses.asl20;
      sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
    };
  };
  # REA 6.7 enforces these versions; nixpkgs has WABT 1.0.41 and
  # an incompatible sigrok-cli 0.8 development snapshot.
  wabtForRea = wabt.overrideAttrs (old: {
    version = "1.0.42";
    # Only the CLI tools are needed. Use system OpenSSL for SHA256 and avoid
    # fetching libwasm/test-only Git submodules.
    buildInputs = (old.buildInputs or [ ]) ++ [ openssl ];
    cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DBUILD_LIBWASM=OFF" ];
    src = fetchFromGitHub {
      owner = "WebAssembly";
      repo = "wabt";
      tag = "1.0.42";
      hash = "sha256-z0y8pCLTpgPc8vkmfuF/bEdjcdcNxSGKlq3RtNzQJlc=";
    };
  });
  sigrokForRea = sigrok-cli.overrideAttrs {
    version = "0.7.2";
    src = fetchFromGitHub {
      owner = "sigrokproject";
      repo = "sigrok-cli";
      tag = "sigrok-cli-0.7.2";
      hash = "sha256-KwycQcJzQmhw5/GXh2FkqJh59TDjITwrUJuaTrmlkd8=";
    };
  };
  unicornForRea = unicorn.overrideAttrs {
    version = "2.1.2";
    src = fetchFromGitHub {
      owner = "unicorn-engine";
      repo = "unicorn";
      tag = "2.1.2";
      hash = "sha256-qA84xBztyWmt/rUExhhZMkQzvDPx0UE9MAIPG/Su3iE=";
    };
  };
  pwntoolsPython =
    (python3.override {
      packageOverrides = self: super: {
        pyelftools = super.pyelftools.overridePythonAttrs {
          version = "0.33";
          src = fetchFromGitHub {
            owner = "eliben";
            repo = "pyelftools";
            tag = "v0.33";
            hash = "sha256-NqF5A6PRl4uncwNS9j44fIV7ovlljiucvV2Msv0LK/w=";
          };
        };
        unicorn = (super.unicorn.override { unicorn = unicornForRea; }).overridePythonAttrs (old: {
          build-system = old.build-system ++ [ self.versioningit ];
          # GitHub archives have no .git metadata; use the pinned release tag.
          postPatch = (old.postPatch or "") + ''
                        substituteInPlace pyproject.toml \
                          --replace-fail '[tool.versioningit]' '[tool.versioningit]
            default-version = "2.1.2"'
          '';
        });
      };
    }).withPackages
      (p: [ p.pwntools ]);
  mitmproxyForRea = mitmproxy.overridePythonAttrs (old: {
    # nixpkgs' 12.3 test-only TLS patch does not apply to this older release.
    patches = [ ];
    version = "12.2.3";
    dependencies = old.dependencies ++ [ python3.pkgs.zstandard ];
    src = fetchFromGitHub {
      owner = "mitmproxy";
      repo = "mitmproxy";
      tag = "v12.2.3";
      hash = "sha256-YgM8GjWmWKxOZcahR3+9XO2Xyfu9v8rNgxKn/2oL35Y=";
    };
  });
  apktoolSupported = lib.elem stdenv.hostPlatform.system [
    "x86_64-linux"
    "aarch64-darwin"
  ];
  defaults = {
    REA_WABT_BIN_DIRECTORY = "${wabtForRea}/bin";
    JAVA_HOME = jdk21.home;
    REA_JADX_MCP_JAR = toString jadxMcpJar;
    REA_ADB_PATH = "${android-tools}/bin/adb";
    REA_ILSPY_CMD_PATH = lib.getExe ilspycmd;
    REA_OBJDUMP_COMMAND = "${binutils}/bin/objdump";
    REA_RIZIN_COMMAND = lib.getExe rizin;
  }
  // lib.optionalAttrs stdenv.hostPlatform.isDarwin {
    # Owned subprocesses (including JADX) compile REA's Darwin token reader.
    # xcrun cannot discover a compiler in an isolated Nix environment.
    REA_DARWIN_SWIFTC_PATH = "${swift}/bin/swiftc";
    SDKROOT = apple-sdk.sdkroot;
  }
  // lib.optionalAttrs apktoolSupported { REA_APKTOOL_COMMAND = lib.getExe apktool; }
  // lib.optionalAttrs stdenv.hostPlatform.isLinux {
    REA_MITMDUMP_COMMAND = "${mitmproxyForRea}/bin/mitmdump";
    REA_SIGROK_COMMAND = lib.getExe sigrokForRea;
    REA_GDB_COMMAND = lib.getExe gdb;
    REA_BINWALK_COMMAND = lib.getExe binwalk;
    REA_UNBLOB_COMMAND = lib.getExe unblob;
    REA_TSHARK_COMMAND = "${wireshark-cli}/bin/tshark";
    REA_CAPINFOS_COMMAND = "${wireshark-cli}/bin/capinfos";
    # PATH is insufficient: these providers default to /usr/bin/prlimit.
    REA_EVM_PRLIMIT_COMMAND = "${util-linux}/bin/prlimit";
    REA_FIRMWARE_PRLIMIT_COMMAND = "${util-linux}/bin/prlimit";
    REA_JAVASCRIPT_PRLIMIT_COMMAND = "${util-linux}/bin/prlimit";
    REA_SIGROK_PRLIMIT_COMMAND = "${util-linux}/bin/prlimit";
    REA_TSHARK_PRLIMIT_COMMAND = "${util-linux}/bin/prlimit";
  }
  // lib.optionalAttrs (stdenv.hostPlatform.system == "x86_64-linux") {
    REA_PWNTOOLS_PYTHON = "${pwntoolsPython}/bin/python3";
  };
in
{
  inherit
    defaults
    jadxMcpJar
    wabtForRea
    sigrokForRea
    pwntoolsPython
    mitmproxyForRea
    ;
  paths = [
    jdk21
    wabtForRea
    android-tools
    ilspycmd
    binutils
    rizin
  ]
  ++ lib.optional apktoolSupported apktool
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    gdb
    sigrokForRea
    binwalk
    unblob
    wireshark-cli
  ];
  wrapperArgs = lib.concatStringsSep " \\\n      " (
    lib.mapAttrsToList (name: value: "--set-default ${name} ${lib.escapeShellArg value}") defaults
  );
}
