# Bind-mounted into the Nix sandbox when programs.wiicompiled.enableGame
# is on (see darwin-module.nix / module.nix). First switch after enabling
# still has the old nix.conf, so the game derivation must tolerate a missing
# dir and skip ccache.
#
# Separate from programs.ccache's /var/cache/ccache. Mode matches the wiki:
# builders in nixbld share it; world cannot.
{
  path = "/var/cache/ccache-wiicompiled";
  mode = "0770";
  owner = "root";
  group = "nixbld";
}
