# Drop this overlay (and overlays/mopidy/*.patch) when nixpkgs #543550
# (mopidy 3.4.2 → 4.0.2) is in flake.lock. mopidy-spotify 5.0 needs mopidy >= 4;
# nixpkgs is still 5.0.0a3, whose tests die on pytest 9.
#
# After the drop: keep mopidy-tidal out of extensionPackages until upstream
# ships a Mopidy 4 release (Pydantic models; nixpkgs marks it broken).
# Iris is still 3.70.0 — built against 4.0.2, not runtime-checked here.
_final: prev: let
  inherit (prev) lib;
  py = prev.mopidyPackages.python.pkgs;
  mopidyPackages = prev.mopidyPackages.overrideScope (self: super: {
    mopidy = super.mopidy.overridePythonAttrs (_old: {
      version = "4.0.2";
      src = prev.fetchFromGitHub {
        owner = "mopidy";
        repo = "mopidy";
        tag = "v4.0.2";
        hash = "sha256-fSvUD+vDua3DCKx/CszjKEUuspD0FwROOksRD6K++L0=";
      };
      patches = [
        ./mopidy/fix-unexpanded-xdg-paths.patch
        ./mopidy/fix-gst-structure-none-checks.patch
      ];
      build-system = with py; [
        setuptools
        setuptools-scm
      ];
      dependencies =
        (with py; [
          cyclopts
          gst-python
          httpx
          platformdirs
          pydantic
          pygobject3
          pykka
          rich
          tornado
        ])
        ++ lib.optionals (!prev.stdenv.hostPlatform.isDarwin) [py.dbus-python];
      # hydraPlatforms is empty; gst fixture tests need a real pipeline.
      doCheck = false;
    });

    mopidy-spotify = super.mopidy-spotify.overridePythonAttrs (_old: {
      version = "5.0.0";
      src = prev.fetchFromGitHub {
        owner = "mopidy";
        repo = "mopidy-spotify";
        tag = "v5.0.0";
        hash = "sha256-0h1BkC3cY1klxVQ+QsyhY/ZJgbb+LlnDuQRYQbqpHJQ=";
      };
      patches = [
        (prev.fetchpatch {
          name = "mopidy-spotify-pytest-9-parametrize.patch";
          url = "https://github.com/mopidy/mopidy-spotify/commit/5fbc4104d78ef15f81ef080c427551f9d4369873.patch";
          hash = "sha256-JPy9l8uKWUggpfszpwfMiuNN8abnIlno+zOCB4r5s0s=";
        })
      ];
      build-system = with py; [
        setuptools
        setuptools-scm
      ];
      dependencies = [
        self.mopidy
        py.pykka
        py.requests
      ];
    });

    mopidy-local = super.mopidy-local.overridePythonAttrs (_old: {
      version = "4.0.1";
      src = prev.fetchPypi {
        pname = "mopidy_local";
        version = "4.0.1";
        hash = "sha256-C+zGi81jfzmo6J9izaSJ/rdjVCeQZcNnPR+/agvrVwg=";
      };
      build-system = with py; [
        setuptools
        setuptools-scm
      ];
      dependencies = [
        self.mopidy
        py.uritools
      ];
    });

    mopidy-mpd = super.mopidy-mpd.overridePythonAttrs (_old: {
      version = "4.0.1";
      src = prev.fetchPypi {
        pname = "mopidy_mpd";
        version = "4.0.1";
        hash = "sha256-iWMEJHJROeU3YU+ollWieAGQWOIYSI+RFWQb3AGE3Nw=";
      };
      build-system = with py; [
        setuptools
        setuptools-scm
      ];
      dependencies = [self.mopidy];
    });

    mopidy-mpris = super.mopidy-mpris.overridePythonAttrs (_old: {
      version = "4.0.0";
      src = prev.fetchPypi {
        pname = "mopidy_mpris";
        version = "4.0.0";
        hash = "sha256-6cQlXxqno96SMQqlheAY3SkttVpEoVJmPjGndcJ4qQA=";
      };
      build-system = with py; [
        setuptools
        setuptools-scm
      ];
      dependencies = [
        self.mopidy
        py.pydbus
      ];
    });

    mopidy-notify = super.mopidy-notify.overridePythonAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace mopidy_notify/frontend.py \
            --replace-fail 'from mopidy.core.listener import CoreListener' 'from mopidy.core import CoreListener'
        '';
      dependencies = [
        self.mopidy
        py.pydbus
        py.requests
      ];
    });

    mopidy-podcast = super.mopidy-podcast.overridePythonAttrs (_old: {
      version = "4.0.0";
      src = prev.fetchPypi {
        pname = "mopidy_podcast";
        version = "4.0.0";
        hash = "sha256-EnFMEhJeVjhrwOApgeU92WzYZGraBFTAntmUsc423+o=";
      };
      build-system = with py; [
        setuptools
        setuptools-scm
      ];
      dependencies = [
        self.mopidy
        py.cachetools
        py.uritools
      ];
    });

    mopidy-scrobbler = super.mopidy-scrobbler.overridePythonAttrs (_old: {
      version = "3.1.0";
      src = prev.fetchPypi {
        pname = "mopidy_scrobbler";
        version = "3.1.0";
        hash = "sha256-kYBah5eUZGwFTPlyN+ILjKcZVpW4e1+VFSu2OSlN9Sw=";
      };
      build-system = with py; [
        setuptools
        setuptools-scm
      ];
      dependencies = [self.mopidy py.pylast];
    });

    mopidy-somafm = super.mopidy-somafm.overridePythonAttrs (_old: {
      version = "2.1.0";
      src = prev.fetchPypi {
        pname = "mopidy_somafm";
        version = "2.1.0";
        hash = "sha256-d7yr3jbZ28Sj5I06i34xvxZtXnynW5f6+Iem5lQ6EZ4=";
      };
      build-system = with py; [
        setuptools
        setuptools-scm
      ];
      dependencies = [self.mopidy];
    });

    mopidy-soundcloud = super.mopidy-soundcloud.overridePythonAttrs (_old: {
      version = "4.0.0";
      src = prev.fetchFromGitHub {
        owner = "mopidy";
        repo = "mopidy-soundcloud";
        tag = "v4.0.0";
        hash = "sha256-3t04O9jtFe4VNl9im1sC/FY4/tTD+yQIfd+vh02VD3E=";
      };
      build-system = with py; [
        setuptools
        setuptools-scm
      ];
      dependencies = [
        self.mopidy
        py.beautifulsoup4
        py.requests
      ];
    });

    mopidy-listenbrainz = super.mopidy-listenbrainz.overridePythonAttrs (_old: {
      version = "0.4.1";
      src = prev.fetchFromGitHub {
        owner = "suaviloquence";
        repo = "mopidy-listenbrainz";
        tag = "v0.4.1";
        hash = "sha256-e3VrOILOqBvX3j8jEsseFY6ihZiXIm0ela66VRwvlgg=";
      };
      dependencies = [
        self.mopidy
        py.musicbrainzngs
        py.pykka
      ];
    });

    mopidy-youtube = super.mopidy-youtube.overridePythonAttrs (old: {
      version = "4.0.2";
      src = prev.fetchPypi {
        pname = "mopidy_youtube";
        version = "4.0.2";
        hash = "sha256-KgD6cE10efNPyP0XWkpSl386Vgw+ad7Ogqo96ZGJs7w=";
      };
      patches = (old.patches or []) ++ [./mopidy/fix-youtube-mopidy-4.patch];
      dependencies = [
        self.mopidy
        py.beautifulsoup4
        py.cachetools
        py.pykka
        py.requests
        py.setuptools_80
        py.ytmusicapi
        py.yt-dlp
      ];
    });

    mopidy-jellyfin = super.mopidy-jellyfin.overridePythonAttrs (_old: {
      dependencies = [
        self.mopidy
        py.requests
        py.unidecode
        py.websocket-client
      ];
    });

    mopidy-tunein = super.mopidy-tunein.overridePythonAttrs (_old: {
      dependencies = [
        self.mopidy
        py.requests
        py.setuptools_80
      ];
    });

    mopidy-tidal = super.mopidy-tidal.overridePythonAttrs (old: {
      meta = old.meta // {broken = true;};
    });
  });
in {
  inherit mopidyPackages;
  inherit
    (mopidyPackages)
    mopidy
    mopidy-bandcamp
    mopidy-iris
    mopidy-jellyfin
    mopidy-listenbrainz
    mopidy-local
    mopidy-mpd
    mopidy-mpris
    mopidy-notify
    mopidy-podcast
    mopidy-scrobbler
    mopidy-somafm
    mopidy-soundcloud
    mopidy-spotify
    mopidy-tidal
    mopidy-tunein
    mopidy-youtube
    ;
}
