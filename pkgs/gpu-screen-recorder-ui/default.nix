{
  dbus,
  lib,
}:
# gsr-ui tracks the cursor on KDE Wayland by walking every DRM card's planes
# every 100 ms, so a discrete GPU can never runtime-suspend. The patch adds a
# KWin tracker (asks KWin for activeOutputName on demand) and makes the DRM
# fallback skip cards with no connected connector (sysfs, no ioctl).
#
# This returns an overrideAttrs function rather than a package, so the result
# keeps gpu-screen-recorder-ui's own `.override` (the NixOS module passes
# `wrapperDir` through it).
old: {
  patches = (old.patches or [ ]) ++ [ ./gsr-ui-kwin-cursor-tracker.patch ];
  postPatch = (old.postPatch or "") + ''
    substituteInPlace src/CursorTracker/CursorTrackerKwin.cpp \
      --replace-fail '"dbus-send"' '"${lib.getExe' dbus "dbus-send"}"'
  '';
}
