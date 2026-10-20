{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  darwin,
  cairo,
  freetype,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "lsp-plugins";
  version = "1.2.35";

  src = fetchurl {
    url = "https://github.com/lsp-plugins/lsp-plugins/releases/download/${finalAttrs.version}/lsp-plugins-src-${finalAttrs.version}.tar.gz";
    hash = "sha256-LJXse7IZ1WHqPbNgUbbHMhM7zXZCb7g2sd2FDcS1u2w=";
  };

  patches = [ ./lsp-cocoa-signed-geometry.patch ];

  nativeBuildInputs = [
    pkg-config
    darwin.autoSignDarwinBinariesHook
  ];
  buildInputs = [
    cairo
    freetype
  ];

  postPatch = ''
    substituteInPlace modules/lsp-plugin-fw/src/Makefile \
      --replace-fail 'MACOS_PLUGIN_LIBDIR    := /Library/Audio/Plug-Ins' 'MACOS_PLUGIN_LIBDIR    := $(LIBDIR)' \
      --replace-fail 'codesign --force --deep --sign - "$(DESTDIR)$(VST3_LIBDIR)"' ""
  '';

  makeFlags = [ "PREFIX=${placeholder "out"}" ];

  configurePhase = ''
    runHook preConfigure
    make $makeFlags config FEATURES="lv2 vst3 clap ui"
    runHook postConfigure
  '';

  env.NIX_CFLAGS_COMPILE = "-DLSP_NO_EXPERIMENTAL";
  enableParallelBuilding = true;

  meta = {
    description = "Linux Studio Plugins native macOS LV2, VST3 and CLAP plugins";
    homepage = "https://lsp-plug.in";
    license = lib.licenses.lgpl3Plus;
    platforms = lib.platforms.darwin;
  };
})
