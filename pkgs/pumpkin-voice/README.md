# PumpkinVoice for braco

PumpkinVoice 1.2.0 is rebuilt against the exact Pumpkin 0.2.0+26.3-26.51
source and WIT definitions. The root `pumpkin-nixpkgs` input pins the server
independently of fleet nixpkgs, keeping cached upstream x86 and ARM binaries.
The plugin is built on x86 with the root Rust overlay and runs as a portable
WASI component on braco’s ARM host.

Java clients need Simple Voice Chat installed. Vanilla and Bedrock clients can
still join without it; voice chat is optional. UDP 24454 must be reachable.
Plugin configuration and player state live below `plugins/data/pumpkin_voice`
in Pumpkin's persisted data directory; pre-start copies the old layout once.

The historical ChatColor and PumpkinEssentials projects are native
Rust plugins. Their published sources target an older Pumpkin API; the Essentials
release is a native `.so`, not a portable WASM component. They must be ported and
rebuilt for our server and ARM before they can be enabled. Do not install an x86
release `.so` on braco or treat a successful file download as a compatibility test.

## Current rollout

The component, optional Java and Bedrock Bare Bones packs, generated monke icon,
server links and Gatus dashboard are declared in `machines/braco/minecraft.nix`
and `minecraft-status.nix`. The initial scoped live rollout uses runtime systemd
drop-ins, with GC roots for their Nix closures. It does not switch the full host
or change its boot generation. The next ordinary braco deployment adopts these
declarations and removes the temporary overrides through an activation script.
The live rollout therefore needs that deployment to survive a reboot.

Gatus lives at https://status.leg.monke.fail. Its SQLite history is persisted in
`/persist/var/lib/private/gatus`. Health checks exercise real Java status packets
and Bedrock UDP status plus TCP NetherNet discovery; they do not claim to test voice audio or client login.

The Java pack prompt was kept empty on Pumpkin 2026-07-25: its resource-pack
packet encoder writes the prompt-present flag but omits the text component. A
nonempty prompt disconnects Minecraft clients. The workaround was tested with
an independent `minecraft-protocol` 1.21.11 client decoding the resource-pack and
server-links packets. Pumpkin 0.2 fixes this encoder; the empty prompt remains
a valid optional-pack configuration.

## VEssentials trial

VEssentials 1.2.6 (marketplace ID `IFGGQmCS`, published 2026-10-04) was tested
in an isolated instance of the same Pumpkin 2026-07-25 build. It failed before
loading or registering commands:

```
component imports instance `pumpkin:plugin/world@0.1.0`, but a matching
implementation was not found in the linker
```

The marketplace history lists API updates from July 31 onwards, but exposes only
the current download and no source link. The downloaded signed component's
SHA-256 was `756ebe94437ec5499e2e653fb9c6237ebd8fe5e921a1cdc6cdf32afb68100d51`.
It was not installed on braco; homes and AFK functionality could not be exercised.
Rebuilding it requires its source, or a server/API update with a compatible
component. Matching the WIT version string alone is insufficient.

The icon source is `machines/braco/assets/monke-original.png`, generated with the
built-in image tool, and the 64px asset is `monke.png`. Generation prompt:
"Friendly chunky pixel-art brown monkey face, tan muzzle, large round ears,
cheeky grin, front-facing, dark forest-green background, readable at 64px,
crisp pixel grid, no text, border or gradients."

## Pumpkin 0.2 upgrade validation

Both plugins were rebuilt and loaded in an isolated Pumpkin 0.2 server before
rollout. Its Java status, Bedrock UDP pong and HTTP `/v1/join` discovery responded.
The official Java multiversion plugin builds and loads, but an independent
1.21.11 client stalls in configuration, so it remains disabled. Java clients
should use 26.3. Bedrock now targets 26.51 and needs TCP and UDP 19132 for NetherNet. Oracle’s
braco-pumpkin-smp NSG and the guest firewall both allow those ports.

VEssentials 1.2.6 was retried on this server and still fails initialization:
`Plugin is built against a different API version: type-checking export func handle-event`.
It remains uninstalled. Health probes do not establish a real authenticated player
session or exercise voice audio.

The pre-upgrade stopped-world archive and previous runtime override are saved
in `/persist/backups/pumpkin-0.2-upgrade-20261018` on braco. Public Java, Bedrock
UDP status and TCP NetherNet discovery passed after the live upgrade.
