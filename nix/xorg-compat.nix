# nixpkgs maps pkgs.xorg.* through warnAlias (deprecated 2026-01-29). Out-of-tree
# flakes still callPackage those attrs: polygon/audio.nix JUCE/VST recipes and
# jacopone/code-cursor-nix extraPkgs. Re-export the same names from the top level
# without touching prev.xorg (that access is what prints the warning).
# Drop when those flakes use libx11 / xrandr / … directly.
final: _prev: {
  xorg = let
    inherit (final) lib;
    same = [
      "appres"
      "bdftopcf"
      "bitmap"
      "editres"
      "fonttosfnt"
      "gccmakedep"
      "iceauth"
      "ico"
      "imake"
      "libdmx"
      "libfontenc"
      "libpciaccess"
      "libxcb"
      "libxcvt"
      "libxkbfile"
      "libxshmfence"
      "listres"
      "lndir"
      "luit"
      "makedepend"
      "mkfontscale"
      "oclock"
      "pixman"
      "sessreg"
      "setxkbmap"
      "smproxy"
      "transset"
      "viewres"
      "wrapWithXFileSearchPathHook"
      "x11perf"
      "xauth"
      "xbacklight"
      "xbitmaps"
      "xcalc"
      "xclock"
      "xcmsdb"
      "xcompmgr"
      "xconsole"
      "xcursorgen"
      "xdm"
      "xdpyinfo"
      "xdriinfo"
      "xev"
      "xeyes"
      "xfd"
      "xfontsel"
      "xfs"
      "xfsinfo"
      "xgamma"
      "xgc"
      "xhost"
      "xinit"
      "xinput"
      "xkbcomp"
      "xkbevd"
      "xkbprint"
      "xkbutils"
      "xkill"
      "xload"
      "xlsatoms"
      "xlsclients"
      "xlsfonts"
      "xmag"
      "xmessage"
      "xmodmap"
      "xmore"
      "xorgproto"
      "xpr"
      "xprop"
      "xrandr"
      "xrdb"
      "xrefresh"
      "xset"
      "xsetroot"
      "xsm"
      "xstdcmap"
      "xtrans"
      "xvfb"
      "xvinfo"
      "xwd"
      "xwininfo"
      "xwud"
    ];
    renamed = {
      encodings = "font-encodings";
      fontadobe100dpi = "font-adobe-100dpi";
      fontadobe75dpi = "font-adobe-75dpi";
      fontadobeutopia100dpi = "font-adobe-utopia-100dpi";
      fontadobeutopia75dpi = "font-adobe-utopia-75dpi";
      fontadobeutopiatype1 = "font-adobe-utopia-type1";
      fontalias = "font-alias";
      fontarabicmisc = "font-arabic-misc";
      fontbh100dpi = "font-bh-100dpi";
      fontbh75dpi = "font-bh-75dpi";
      fontbhlucidatypewriter100dpi = "font-bh-lucidatypewriter-100dpi";
      fontbhlucidatypewriter75dpi = "font-bh-lucidatypewriter-75dpi";
      fontbhttf = "font-bh-ttf";
      fontbhtype1 = "font-bh-type1";
      fontbitstream100dpi = "font-bitstream-100dpi";
      fontbitstream75dpi = "font-bitstream-75dpi";
      fontbitstreamtype1 = "font-bitstream-type1";
      fontcronyxcyrillic = "font-cronyx-cyrillic";
      fontcursormisc = "font-cursor-misc";
      fontdaewoomisc = "font-daewoo-misc";
      fontdecmisc = "font-dec-misc";
      fontibmtype1 = "font-ibm-type1";
      fontisasmisc = "font-isas-misc";
      fontjismisc = "font-jis-misc";
      fontmicromisc = "font-micro-misc";
      fontmisccyrillic = "font-misc-cyrillic";
      fontmiscethiopic = "font-misc-ethiopic";
      fontmiscmeltho = "font-misc-meltho";
      fontmiscmisc = "font-misc-misc";
      fontmuttmisc = "font-mutt-misc";
      fontschumachermisc = "font-schumacher-misc";
      fontscreencyrillic = "font-screen-cyrillic";
      fontsonymisc = "font-sony-misc";
      fontsunmisc = "font-sun-misc";
      fontutil = "font-util";
      fontwinitzkicyrillic = "font-winitzki-cyrillic";
      fontxfree86type1 = "font-xfree86-type1";
      libAppleWM = "libapplewm";
      libFS = "libfs";
      libICE = "libice";
      libpthreadstubs = "libpthread-stubs";
      libSM = "libsm";
      libWindowsWM = "libwindowswm";
      libX11 = "libx11";
      libXau = "libxau";
      libXaw = "libxaw";
      libXcomposite = "libxcomposite";
      libXcursor = "libxcursor";
      libXdamage = "libxdamage";
      libXdmcp = "libxdmcp";
      libXext = "libxext";
      libXfixes = "libxfixes";
      libXfont = "libxfont_1";
      libXfont2 = "libxfont_2";
      libXft = "libxft";
      libXi = "libxi";
      libXinerama = "libxinerama";
      libXmu = "libxmu";
      libXp = "libxp";
      libXpm = "libxpm";
      libXpresent = "libxpresent";
      libXrandr = "libxrandr";
      libXrender = "libxrender";
      libXres = "libxres";
      libXScrnSaver = "libxscrnsaver";
      libXt = "libxt";
      libXtst = "libxtst";
      libXv = "libxv";
      libXvMC = "libxvmc";
      libXxf86dga = "libxxf86dga";
      libXxf86misc = "libxxf86misc";
      libXxf86vm = "libxxf86vm";
      mkfontdir = "mkfontscale";
      twm = "tab-window-manager";
      utilmacros = "util-macros";
      xcbproto = "xcb-proto";
      xcbutil = "libxcb-util";
      xcbutilcursor = "libxcb-cursor";
      xcbutilerrors = "libxcb-errors";
      xcbutilimage = "libxcb-image";
      xcbutilkeysyms = "libxcb-keysyms";
      xcbutilrenderutil = "libxcb-render-util";
      xcbutilwm = "libxcb-wm";
      xcursorthemes = "xcursor-themes";
      xf86inputevdev = "xf86-input-evdev";
      xf86inputjoystick = "xf86-input-joystick";
      xf86inputkeyboard = "xf86-input-keyboard";
      xf86inputlibinput = "xf86-input-libinput";
      xf86inputmouse = "xf86-input-mouse";
      xf86inputsynaptics = "xf86-input-synaptics";
      xf86inputvmmouse = "xf86-input-vmmouse";
      xf86inputvoid = "xf86-input-void";
      xf86videoamdgpu = "xf86-video-amdgpu";
      xf86videoapm = "xf86-video-apm";
      xf86videoark = "xf86-video-ark";
      xf86videoast = "xf86-video-ast";
      xf86videoati = "xf86-video-ati";
      xf86videochips = "xf86-video-chips";
      xf86videocirrus = "xf86-video-cirrus";
      xf86videodummy = "xf86-video-dummy";
      xf86videofbdev = "xf86-video-fbdev";
      xf86videogeode = "xf86-video-geode";
      xf86videoi128 = "xf86-video-i128";
      xf86videoi740 = "xf86-video-i740";
      xf86videointel = "xf86-video-intel";
      xf86videomga = "xf86-video-mga";
      xf86videoneomagic = "xf86-video-neomagic";
      xf86videonouveau = "xf86-video-nouveau";
      xf86videonv = "xf86-video-nv";
      xf86videoomap = "xf86-video-omap";
      xf86videoopenchrome = "xf86-video-openchrome";
      xf86videoqxl = "xf86-video-qxl";
      xf86videor128 = "xf86-video-r128";
      xf86videos3virge = "xf86-video-s3virge";
      xf86videosavage = "xf86-video-savage";
      xf86videosiliconmotion = "xf86-video-siliconmotion";
      xf86videosis = "xf86-video-sis";
      xf86videosisusb = "xf86-video-sisusb";
      xf86videosuncg6 = "xf86-video-suncg6";
      xf86videosunffb = "xf86-video-sunffb";
      xf86videosunleo = "xf86-video-sunleo";
      xf86videotdfx = "xf86-video-tdfx";
      xf86videotrident = "xf86-video-trident";
      xf86videov4l = "xf86-video-v4l";
      xf86videovboxvideo = "xf86-video-vbox";
      xf86videovesa = "xf86-video-vesa";
      xf86videovmware = "xf86-video-vmware";
      xf86videovoodoo = "xf86-video-voodoo";
      xkeyboardconfig = "xkeyboard-config";
      xkeyboardconfig_custom = "xkeyboard-config_custom";
      xorgcffiles = "xorg-cf-files";
      xorgdocs = "xorg-docs";
      xorgserver = "xorg-server";
      xorgsgmldoctools = "xorg-sgml-doctools";
    };
  in
    lib.genAttrs same (name: final.${name})
    // lib.mapAttrs (_: newName: final.${newName}) renamed;
}
