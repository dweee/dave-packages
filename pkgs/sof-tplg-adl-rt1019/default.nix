# Source-built SOF IPC3 topologies for Alder Lake / Alder Lake-N Chromebooks
# with an RT1019 speaker amp on SSP1 and an RT5682(-VS) headset codec on SSP0
# (brya/nissa boards such as pujjo, marasov and craask variants).
#
# Why: sof-bin, and therefore nixpkgs' sof-firmware, still ships the v2.2
# (2022) build of sof-adl-rt1019-rt5682.tplg. It runs the speaker pipeline
# at s16le into an SSP configured for 24 valid bits in 32-bit slots, and the
# speakers play quiet, square-wave distortion. SOF fixed that pipeline/SSP
# mismatch on stable-v2.2 in 2023, but sof-bin never re-shipped this file.
#
# speakerSampleBits:
#   32 (default) applies ./rt1019-32bit-ssp.patch: s32le pipelines and 32 valid
#      SSP bits, like the MAX98360A boards. The output is byte-identical to
#      WeirdTreeThing/chromebook-linux-audio's blobs/adl/sof-adl-rt1019-rt5682.tplg
#      (sha256 cdaf9b82...), which fixes the speakers on pujjoteen.
#   24 builds stable-v2.2 unchanged (s24le pipelines, 24 valid bits).
#
# Install through hardware.firmware. The files are left uncompressed: the
# kernel tries the plain name before `.zst`, so they take precedence over
# sof-firmware's compressed copies without a buildEnv collision.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  m4,
  alsa-utils,
  speakerSampleBits ? 32,
}:
assert lib.assertOneOf "speakerSampleBits" speakerSampleBits [
  24
  32
];
let
  targets = [
    "sof-adl-rt1019-rt5682"
    "sof-adl-rt1019-rt5682-drceq"
  ];
in
stdenvNoCC.mkDerivation {
  pname = "sof-tplg-adl-rt1019";
  version = "2.2.13-unstable-2026-03-04${lib.optionalString (speakerSampleBits == 32) "-ssp32"}";

  # thesofproject/sof stable-v2.2: the branch that still builds the IPC3
  # (topology1) targets for Alder Lake.
  src = fetchFromGitHub {
    owner = "thesofproject";
    repo = "sof";
    rev = "c192676749ae8ba864787d3c61dd32fc0774488b";
    sparseCheckout = [
      "src/include/kernel"
      "tools/topology/topology1"
    ];
    hash = "sha256-F9owWDyNOgScKwA0ygpBKW3ZhDukGl9Ai/p+DwRitZo=";
  };

  patches = lib.optional (speakerSampleBits == 32) ./rt1019-32bit-ssp.patch;

  nativeBuildInputs = [
    m4
    alsa-utils
  ];

  # Mirror tools/topology/topology1/CMakeLists.txt without configuring the
  # whole SOF tools tree: the (patched) TPLGS entry supplies each target's
  # m4 input and defines, so the patch stays the single source of truth.
  buildPhase = ''
    runHook preBuild
    t1=tools/topology/topology1
    bash "$t1/get_abi.sh" "$PWD"
    mkdir -p production
    for target in ${lib.escapeShellArgs targets}; do
      entry=$(grep -o "\"[^\"]*\\\\;$target\\\\;[^\"]*\"" "$t1/CMakeLists.txt")
      entry=''${entry//\"/}
      IFS=';' read -r -a fields <<< "''${entry//\\;/;}"
      input=''${fields[0]}
      [ "''${fields[1]}" = "$target" ] || { echo "no TPLGS entry for $target" >&2; exit 1; }
      echo "building $target from $input.m4 with ''${fields[*]:2}"
      m4 --fatal-warnings "''${fields[@]:2}" \
        -I "$t1/m4" -I "$t1/common" -I "$t1/platform/common" -I "$t1" -I "$PWD" \
        "$t1/common/abi.m4" "$t1/$input.m4" > "production/$target.conf"
      alsatplg -c "production/$target.conf" -o "production/$target.tplg"
    done
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm444 -t "$out/lib/firmware/intel/sof-tplg" production/*.tplg
    runHook postInstall
  '';

  passthru.compressFirmware = false;

  meta = {
    description = "Source-built SOF topologies for ADL RT1019 + RT5682 Chromebooks";
    homepage = "https://github.com/thesofproject/sof/tree/stable-v2.2/tools/topology/topology1";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
