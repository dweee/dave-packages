# PumpkinVoice

PumpkinVoice 1.2.0 is rebuilt against Pumpkin 0.2.0+26.3-26.51 and its exact WIT
interfaces. The `pumpkin-nixpkgs` input pins that server independently of the root
nixpkgs input. The result is a portable WASI component for x86_64 and ARM Pumpkin
hosts, rather than a standalone application.

```sh
nix build .#pumpkin-voice
```

Install the generated component into the server's plugins directory. Java
clients need Simple Voice Chat for voice functionality; vanilla and Bedrock
clients can join without it. Make UDP 24454 reachable for voice traffic.
Configuration and player state belong in `plugins/data/pumpkin_voice` under the
server's persistent data directory.

Native Rust plugins built against older Pumpkin APIs need a source port and
rebuild. An x86 `.so` cannot replace a WASI component on an ARM server, and a
matching WIT version string alone does not establish ABI compatibility.
