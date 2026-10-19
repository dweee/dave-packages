# Pumpkin Java multiversion

Official plugin: https://github.com/Pumpkin-MC/pumpkin-java-multiversion

Pinned at `74cccd2a98819038bc7b91253f05f4c882ce7dba` and compiled against Pumpkin
0.2.0+26.3-26.51. Pumpkin 0.2 removes built-in Java multi-version support; this
component translates older protocols. Upstream advertises 1.7.2 through 26.3;
client-version feature parity depends on translation coverage.

```sh
nix build .#pumpkin-java-multiversion
```

Install `pumpkin_java_multiversion.wasm` into Pumpkin's plugins directory. The
portable WASI component runs on x86_64 and ARM servers, requests no filesystem
or network permissions, and is not a standalone application.

Compilation uses a larger Rust worker stack for generated protocol definitions.
The component uses optimization level 1 to limit compile time for those tables;
the server retains its upstream optimization profile.

A successful build or component load does not establish client login or gameplay
compatibility. Test every required client version against the chosen server API
before enabling the component.
