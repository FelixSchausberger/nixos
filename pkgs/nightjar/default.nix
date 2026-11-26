# Nightjar desktop client (Moonlight protocol) used as the kiosk game library.
#
# Upstream publishes a Linux tarball whose Rust binary statically links a
# patched SDL 3.4.20 and ships a decode-only FFmpeg, dav1d and the PyroWave
# GPU decoder beside it. Rebuilding that pipeline in Nix would mean vendoring
# the SDL patch and the PyroWave SDK, so the hash-pinned release artifact is
# patched for NixOS instead. The tarball carries its own licence and source
# offer for the bundled libraries.
#
# SDL references its display, audio and Vulkan backends by soname, so every
# one of them is a link input and lands in the binary's RPATH. Two names in
# the binary have no provider anywhere (libGLES_CM.so.1 is SDL's legacy GLES1
# probe, libsteam_api.so its Steam Deck probe); the loader only needs them
# for the backends that are actually selected, and neither is used here.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  alsa-lib,
  dbus,
  libdrm,
  libdecor,
  libglvnd,
  libopus,
  libpulseaudio,
  libva,
  libx11,
  libxcb,
  libxcursor,
  libxext,
  libxfixes,
  libxi,
  libxkbcommon,
  libxrandr,
  libxscrnsaver,
  libxtst,
  pipewire,
  systemd,
  vulkan-loader,
  wayland,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "nightjar";
  version = "6.4.4";

  src = fetchurl {
    url = "https://github.com/RamazanKara/nightjar/releases/download/v${finalAttrs.version}/nightjar-desktop-${finalAttrs.version}-linux-x86_64.tar.gz";
    hash = "sha256-xVM99fGoT6QCq3z8K5VrkrrUEZhulpmWyk5x7KS32eU=";
  };

  nativeBuildInputs = [autoPatchelfHook];

  buildInputs = [
    alsa-lib
    dbus
    libdrm
    libdecor
    libglvnd
    libopus
    libpulseaudio
    libva
    libx11
    libxcb
    libxcursor
    libxext
    libxfixes
    libxi
    libxkbcommon
    libxrandr
    libxscrnsaver
    libxtst
    pipewire
    stdenv.cc.cc.lib
    systemd
    vulkan-loader
    wayland
  ];

  autoPatchelfIgnoreMissingDeps = [
    "libGLES_CM.so.1"
    "libsteam_api.so"
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/nightjar $out/bin
    cp -r . $out/lib/nightjar/
    mv $out/lib/nightjar/share $out/share
    ln -s ../lib/nightjar/nightjar $out/bin/nightjar

    runHook postInstall
  '';

  meta = {
    description = "Game-streaming client with a controller-first library (Moonlight protocol)";
    homepage = "https://github.com/RamazanKara/nightjar";
    license = lib.licenses.gpl3Plus;
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    mainProgram = "nightjar";
    platforms = ["x86_64-linux"];
  };
})
