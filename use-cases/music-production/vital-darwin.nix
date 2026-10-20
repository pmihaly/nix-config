{
  lib,
  stdenvNoCC,
  fetchurl,
  libarchive,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "vital";
  version = "1.5.5";

  src = fetchurl {
    url = "https://builds.vital.audio/VitalAudio/vital/${
      builtins.replaceStrings [ "." ] [ "_" ] finalAttrs.version
    }/VitalInstaller.pkg";
    hash = "sha256-170wecrNClWQqjrowrPZWaXrAuE0O4ICZ/WMVV/gqjQ=";
  };

  nativeBuildInputs = [ libarchive ];

  unpackPhase = ''
    runHook preUnpack
    bsdtar -xf "$src"
    mkdir payload
    bsdtar -xf VitalComponent.pkg/Payload -C payload
    runHook postUnpack
  '';

  dontBuild = true;
  dontConfigure = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications" "$out/lib"
    cp -R payload/Applications/Vital.app "$out/Applications/"
    cp -R payload/Library/Audio/Plug-Ins/. "$out/lib/"
    runHook postInstall
  '';

  meta = {
    description = "Spectral warping wavetable synth for macOS";
    homepage = "https://vital.audio/";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    license = lib.licenses.unfree;
    platforms = lib.platforms.darwin;
  };
})
