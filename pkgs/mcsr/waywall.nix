{
  waywall,
  fetchFromGitHub,
}:
waywall.overrideAttrs (_old: {
  version = "wall-unstable-2026-10-12";
  src = fetchFromGitHub {
    owner = "tesselslate";
    repo = "waywall";
    rev = "300868207819618025d71ce98b03972868adafd5";
    hash = "sha256-mBm4C0t809NWI0/HR53eQGuGSGj7Jrgv9sDh36kxvqM=";
  };
})
