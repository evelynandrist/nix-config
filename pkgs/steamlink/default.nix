{ 
  stdenv,
  lib,
  fetchurl,
  writeScriptBin,

  alsa-oss,
  atk,
  cacert,
  cairo,
  dbus,
  fakeroot,
  ffmpeg,
  freetype,
  gdk-pixbuf,
  gtk3,
  icu73,
  libGL,
  libopus,
  libSM,
  libva,
  libvdpau,
  libxcb,
  libXcomposite,
  openssl,
  ostree,
  pango,
  pulseaudio,
  SDL2,
  sqlite,
  systemd,
  xorg,
  zlib,

  autoPatchelfHook,
  pkg-config,
}:
stdenv.mkDerivation rec {
  pname = "steamlink";
  version = "1.3.9.258";

  # src = fetchurl {
  #   url = "https://repo.steampowered.com/steamlink/${version}/steamlink-${version}.tgz";
  #   hash = "sha256-/fvU9cAGi7mP+m6PgMRaDDxLwriJlWU0JW87GoDcvwM=";
  # };

  nativeBuildInputs = [
    autoPatchelfHook
    pkg-config
  ];

  buildInputs =	[
    atk
    cacert
    cairo
    dbus.lib
    fakeroot
    ffmpeg
    freetype
    gdk-pixbuf
    gtk3
    icu73
    libGL
    libopus
    libSM
    libva
    libvdpau
    libxcb
    libXcomposite
    openssl
    ostree
    pango
    sqlite
    systemd
    xorg.xcbutilimage
    xorg.xcbutilrenderutil
    xorg.xcbutilwm
    zlib
  ];

  sourceRoot = ".";

  installPhase = let
    flathub-gpg = ./flathub.gpg;
    # libSDL2 = ./libSDL2-2.0.so.0;
    # libdecor = ./libdecor-0.so.0;
    ostree_commit = "c38dc06ca1e65683b9a0c2809fa8ba9214a84a8cacc3c32209a5175fd090af79";
  in ''
    runHook preInstall
    # install -m755 -D package/bin/steamlink $out/bin/steamlink
    # mkdir -p $out/lib/
    # cp -r package/lib/* $out/lib/
    mkdir -p ostree
    ostree init --repo ./ostree
    ostree remote add --gpg-import=${flathub-gpg} --repo ./ostree flathub https://dl.flathub.org/repo/ || true
    fakeroot ostree pull --repo ./ostree flathub app/com.valvesoftware.SteamLink/x86_64/stable@${ostree_commit}
    ostree export --repo ./ostree flathub:${ostree_commit} --subpath files > steamlink.tar
    
    tar -xf steamlink.tar
    mkdir -p $out/bin $out/lib
    cp -r lib/* $out/lib/.
    cp bin/steamlink $out/bin/steamlink_bin
    
    cat <<EOF > $out/bin/steamlink
    #!${stdenv.shell}
    exec ${pulseaudio}/bin/padsp $out/bin/steamlink_bin "\$@"
    EOF

    chmod +x $out/bin/steamlink
    
    runHook postInstall
    '';

  meta = with lib; {
    homepage = "https://store.steampowered.com/steamlink/about/";
    description = "Stream games from another computer with Steam";
    platforms = platforms.linux;
  };

  dontUnpack = true;
  __noChroot = true;
}
