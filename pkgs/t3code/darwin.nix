{ pkgs, client }:
let
  electron =
    pkgs."electron_${pkgs.lib.versions.major client.release.electronVersion}";
in pkgs.runCommand "t3code-darwin-${client.version}" {
  inherit (client) version meta;
  nativeBuildInputs = [ pkgs.makeWrapper pkgs.python3 ];
  passthru = { inherit (client) sourceUnwrapped resourceMonitor release; };
} ''
  mkdir -p "$out/Applications" "$out/bin"
  app="$out/Applications/T3 Code.app"
  # A script-only .app execs the shared Electron.app and loses its macOS
  # identity. Give T3 its own native executable and bundle instead.
  cp -R ${electron}/Applications/Electron.app "$app"
  chmod -R u+w "$app"
  mv "$app/Contents/MacOS/Electron" "$app/Contents/MacOS/T3 Code"
  rm -rf "$app/Contents/Resources/default_app.asar" "$app/Contents/_CodeSignature"
  cp ${client}/Applications/"T3 Code (Alpha).app"/Contents/Resources/t3code.icns \
    "$app/Contents/Resources/t3code.icns"
  export app
  python3 - <<'PY'
  import os, plistlib
  from pathlib import Path
  path = Path(os.environ['app']) / 'Contents/Info.plist'
  with path.open('rb') as f:
      info = plistlib.load(f)
  info.update(
      CFBundleName='T3 Code', CFBundleDisplayName='T3 Code',
      CFBundleExecutable='T3 Code', CFBundleIdentifier='com.t3tools.t3code',
      CFBundleIconFile='t3code.icns',
      CFBundleShortVersionString='${client.version}', CFBundleVersion='${client.version}',
      CFBundleURLTypes=[dict(CFBundleURLName='T3 Code', CFBundleURLSchemes=['t3code', 't3code-dev'])],
  )
  info.pop('ElectronAsarIntegrity', None)
  with path.open('wb') as f:
      plistlib.dump(info, f)
  PY
  # Keep only the native shell in the bundle. copyApps dereferences external
  # symlinks, which relocates apps/ without its parent pnpm dependency store.
  mkdir -p "$app/Contents/Resources/app"
  cat > "$app/Contents/Resources/app/package.json" <<'JSON'
  {"name":"t3code","productName":"T3 Code","version":"${client.version}","main":"boot.cjs"}
  JSON
  cat > "$app/Contents/Resources/app/boot.cjs" <<'JS'
  // DesktopEnvironment resolves the backend and client assets from getAppPath().
  // Keep that root in the immutable store, even after Home Manager copies this
  // native bundle. Relative pnpm links then retain their complete parent tree.
  require('electron').app.setAppPath('${client.sourceUnwrapped}/libexec/t3code');
  process.env.T3CODE_DISABLE_AUTO_UPDATE = '1';
  process.env.T3CODE_RESOURCE_MONITOR_PATH ??= '${
    pkgs.lib.getExe client.resourceMonitor
  }';
  require('${client.sourceUnwrapped}/libexec/t3code/apps/desktop/dist-electron/boot.cjs');
  JS
  # Re-seal the new bundle after changing its executable name and metadata.
  /usr/bin/codesign --force --deep --sign - "$app"
  /usr/bin/codesign --verify --deep "$app"
  makeWrapper "$app/Contents/MacOS/T3 Code" "$out/bin/t3code"
  ln -s ${client}/bin/t3 "$out/bin/t3"
  ln -s ${client}/share "$out/share"
''
