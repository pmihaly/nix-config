# Local copyparty overlay: the pinned sdist (./package.nix) patched with
# ./patches/video-tracks.patch (server-side ?th=json|mp4|vtt track
# conversion). The client-side plugin lives in ./video-tracks.js and is
# wired up by the NixOS module (modules/nixos/copyparty/default.nix),
# which serves it from a read-only [/plug] volume and injects it via
# --js-browser.
#
# In flake.nix this overlay is placed AFTER inputs.copyparty.overlays.
# default, so this `copyparty` shadows the upstream (unpatched) build.
# The upstream flake input is kept because it still provides
# `copyparty-unstable` / `copyparty-full`.
#
# Self-contained: it also (re)provides `partftpy` through a python3
# override, so this overlay works even if the upstream one is removed.
final: prev:
{
  python3 = prev.python3.override {
    packageOverrides = pyFinal: pyPrev: {
      partftpy = pyFinal.callPackage ./partftpy.nix { };
    };
  };

  # ffmpeg = headless build (no GUI codecs), same choice as upstream
  copyparty = final.python3.pkgs.callPackage ./package.nix {
    ffmpeg = final.ffmpeg-headless;
    patches = [ ./patches/video-tracks.patch ];
  };
}
