{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
}:
buildNpmPackage rec {
  pname = "mermaid-filter";
  version = "1.4.7";

  src = fetchFromGitHub {
    owner = "raghur";
    repo = "mermaid-filter";
    rev = "v${version}";
    hash = "sha256-GG2RWr5nVe6PCcTEJLmPyKL2j7ggSyNnHZAffNvPukg=";
  };

  npmDepsHash = "sha256-Hj4h8xTch2Z3ByUhxzPhbCTSXNOXuTXC6XUrBkRvQ/U=";

  # This package is a simple Node CLI, no build step required
  dontNpmBuild = true;

  nativeBuildInputs = [makeWrapper];

  # Avoid puppeteer attempting to download a browser during the build
  env.PUPPETEER_SKIP_DOWNLOAD = "true";

  # Wrap the CLI to set a reasonable default browser if available at runtime
  postInstall = ''
    wrapProgram $out/bin/mermaid-filter \
      --set-default PUPPETEER_SKIP_DOWNLOAD true \
      --run 'if [ -z "$PUPPETEER_EXECUTABLE_PATH" ]; then \
        if command -v mdfind >/dev/null 2>&1; then \
          for bid in \
            com.google.Chrome \
            com.google.Chrome.canary \
            com.microsoft.Edge \
            org.chromium.Chromium \
            com.brave.Browser \
            com.vivaldi.Vivaldi \
            company.thebrowser.Browser \
            com.operasoftware.Opera \
            ru.yandex.desktop.yandex-browser; do \
            app=$(mdfind "kMDItemCFBundleIdentifier == '$bid'" | head -n1); \
            if [ -n "$app" ] && [ -d "$app" ]; then \
              name=$(basename "$app" .app); \
              cand="$app/Contents/MacOS/$name"; \
              if [ -x "$cand" ]; then export PUPPETEER_EXECUTABLE_PATH="$cand"; break; fi; \
            fi; \
          done; \
        fi; \
        if [ -z "$PUPPETEER_EXECUTABLE_PATH" ]; then \
          for c in \
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
            "/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary" \
            "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
            "/Applications/Chromium.app/Contents/MacOS/Chromium" \
            "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
            "/Applications/Vivaldi.app/Contents/MacOS/Vivaldi" \
            "/Applications/Arc.app/Contents/MacOS/Arc" \
            "/Applications/Opera.app/Contents/MacOS/Opera"; do \
            if [ -x "$c" ]; then export PUPPETEER_EXECUTABLE_PATH="$c"; break; fi; \
          done; \
        fi; \
        if [ -z "$PUPPETEER_EXECUTABLE_PATH" ]; then \
          for c in \
            "$HOME/Applications/Home Manager Apps/Brave Browser.app/Contents/MacOS/Brave Browser" \
            "$HOME/Applications/Home Manager Apps/Google Chrome.app/Contents/MacOS/Google Chrome" \
            "$HOME/Applications/Home Manager Apps/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
            "$HOME/Applications/Home Manager Apps/Chromium.app/Contents/MacOS/Chromium"; do \
            if [ -x "$c" ]; then export PUPPETEER_EXECUTABLE_PATH="$c"; break; fi; \
          done; \
        fi; \
        if [ -z "$PUPPETEER_EXECUTABLE_PATH" ]; then \
          for c in chromium chromium-browser google-chrome google-chrome-stable; do \
            if command -v "$c" >/dev/null 2>&1; then export PUPPETEER_EXECUTABLE_PATH="$(command -v "$c")"; break; fi; \
          done; \
        fi; \
      fi'
  '';

  meta = with lib; {
    description = "Pandoc filter to render Mermaid diagrams in markdown using mermaid-cli";
    longDescription = ''
      A Pandoc filter that adds support for Mermaid diagrams in markdown fences.
      It shells out to mermaid-cli (mmdc) under the hood. See usage docs on npm/GitHub.
    '';
    homepage = "https://github.com/raghur/mermaid-filter";
    license = licenses.bsd2; # BSD-2-Clause
    maintainers = [];
    platforms = platforms.unix;
    mainProgram = "mermaid-filter";
  };
}
