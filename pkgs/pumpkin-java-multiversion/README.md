# Pumpkin Java multiversion

Official plugin: https://github.com/Pumpkin-MC/pumpkin-java-multiversion

Pinned at 74cccd2a98819038bc7b91253f05f4c882ce7dba and compiled against the
same Pumpkin 0.2.0+26.3-26.51 source as braco. Pumpkin 0.2 removes built-in
Java multi-version support; this component translates older Java protocols.
Upstream advertises 1.7.2 through 26.3. Client-version feature parity is subject
to upstream translation coverage; a successful load is not full gameplay QA.

Build: `nix build ./pkgs/pumpkin-java-multiversion`. On NixOS, use the root
nixpkgs and Rust overlay, pass `pumpkin-nixpkgs.legacyPackages.x86_64-linux.pumpkin`
as the package’s `pumpkin` argument and install `pumpkin_java_multiversion.wasm`
into Pumpkin’s plugins directory. The WASI
component runs on x86 or ARM Pumpkin hosts; it is not a standalone Darwin app.

The component requests no filesystem or network permissions. Compilation needs
a larger Rust worker stack for Pumpkin’s generated protocol/data definitions.
The release component uses optimization level 1 to avoid excessive O3 compile
time for those generated tables; the Pumpkin server uses the cached upstream
Nix package’s normal optimization profile.

## Trial result

The component builds and loads on Pumpkin 0.2. An independent 1.21.11 client
reaches the configuration phase and decodes the optional resource pack, but does
not finish login. The component is therefore not enabled on braco. Use Java 26.3
for this server release until older-client configuration compatibility is fixed.
