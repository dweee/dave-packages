{ pkgs }:
{
  inherit (pkgs) veracrypt ffmpeg-full;
  ffmpeg-full-rocm = (import pkgs.path {
    system = pkgs.stdenv.hostPlatform.system;
    config = { allowUnfree = true; rocmSupport = true; };
  }).ffmpeg-full;
  nvidia-580 = (pkgs.linuxPackagesFor pkgs.linux-cachyos-server).nvidiaPackages.legacy_580;
  keyguard = pkgs.callPackage ../pkgs/keyguard/package.nix {
    jetbrains = pkgs.jetbrains // { jdk-no-jcef-21 = pkgs.jetbrains-jdk-patched; };
  };
  stemlab = pkgs.callPackage ../pkgs/stemlab { };
}
