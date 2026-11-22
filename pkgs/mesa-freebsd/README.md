# FreeBSD Wayland packaging

`nix/freebsd-desktop.nix` is a separate overlay, also exported as
`overlays.freebsd-desktop`. NixBSD imports that file from an exact public catalog
revision and evaluates it against its own nixpkgs. The catalog's default
Linux/Darwin overlay and package matrix are unchanged.

The initial target is x86_64 FreeBSD 15, cross-compiled from x86_64 Linux against
NixBSD's nixpkgs `7d4b60cc165478e9d2c87236a1740e09de951ded`.

- Foot and fcft use FreeBSD's separate C11 threads package; Foot also needs
  epoll-shim and evdev-proto. No systemd units are installed for Foot.
- Swayidle disables logind; Swaylock uses PAM. The OS must configure the
  self-authentication helper before an unprivileged locker can check passwords.
- The helper is the upstream `unix-selfauth-helper` 1.1 release, with the hash
  recorded by FreeBSD ports. Its store file has no setuid privilege. NixBSD
  explicitly supplies the privileged wrapper and the Swaylock PAM rule.
- Lerc 4.1.1 and libei 1.6.0 already contain their respective BSD fixes; the
  stale backports are removed, preserving libei's native peer-credential checks.
- Lua 5.4's FreeBSD make target retains the cross compiler and uses the declared
  readline dependency instead of assuming `/usr/include/edit` and bare `cc`.
- Mesa 26.1.5 supplies softpipe EGL/GLES/OpenGL without LLVM, Vulkan, OpenCL or
  hardware GPU drivers. Its zlib/zstd dependencies are explicit. Parentheses
  around compound literals preserve FreeBSD's fortified memcpy checks.
- AML uses kqueue. NeatVNC needs the C11 threads headers; its optional FFmpeg
  H.264 path is disabled. WayVNC uses evdev-proto and FreeBSD's fortified libc
  strlcpy rather than redefining that function.

These are real cross-builds, not an `allowUnsupportedSystem` override. Sway,
Foot, Swayidle, Swaylock, Mesa, WayVNC and the authentication helper build for
the target above. This alone does not establish native runtime, physical GPU,
keyboard, suspend, or other-architecture support. NixBSD owns the separate
booted-VM test and records its result.

After NixBSD pins this catalog revision, build from its checkout with:

```sh
nix build --builders '' --no-link \
  .#packages.x86_64-linux.base.pkgs.sway \
  .#packages.x86_64-linux.base.pkgs.foot \
  .#packages.x86_64-linux.base.pkgs.mesa \
  .#packages.x86_64-linux.base.pkgs.wayvnc \
  .#packages.x86_64-linux.base.pkgs.swayidle \
  .#packages.x86_64-linux.base.pkgs.swaylock \
  .#packages.x86_64-linux.base.pkgs.unix-selfauth-helper
```

Reference implementations: [FreeBSD Foot port](https://cgit.freebsd.org/ports/tree/x11/foot),
[Swaylock PAM integration](https://cgit.freebsd.org/ports/tree/x11/swaylock/files/patch-pam_swaylock),
[self-authentication helper](https://github.com/Zirias/unix-selfauth-helper).
