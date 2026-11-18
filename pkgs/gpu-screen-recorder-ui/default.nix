{
  dbus,
  gpu-screen-recorder-ui,
  lib,
}:
# gsr-ui tracks the cursor on KDE Wayland by walking every DRM card's planes
# every 100 ms, so a discrete GPU can never runtime-suspend. The patch adds a
# KWin tracker (asks KWin for activeOutputName on demand) and makes the DRM
# fallback skip cards with no connected connector (sysfs, no ioctl).
gpu-screen-recorder-ui.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./kwin-cursor-tracker.patch ];
  postPatch = (old.postPatch or "") + ''
    substituteInPlace src/CursorTracker/CursorTrackerKwin.cpp \
      --replace-fail '"dbus-send"' '"${lib.getExe' dbus "dbus-send"}"'
  '';
})
