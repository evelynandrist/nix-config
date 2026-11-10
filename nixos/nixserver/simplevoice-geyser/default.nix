# SimpleVoice-Geyser (Spigot jar), built from a pinned upstream commit plus
# pairing.patch, our additions until they are merged upstream: password-less
# login (one-time code + QR map, remembered browsers), a web client that
# survives phones going to the background (no doubled microphone, reconnects
# with backoff and on return, liveness ping), and group invites that wait in
# the Bedrock menu / a clickable chat line (/svg invite, accept, decline).
#
# After changing src or the patch, refresh the Gradle dependency lock (run
# from the repo root, the script writes ./deps.json next to this file):
#   nix build --impure -o /tmp/svg-deps --expr \
#     '((builtins.getFlake (toString ./.)).nixosConfigurations.nixserver.pkgs.callPackage
#        ./nixos/nixserver/simplevoice-geyser { }).mitmCache.updateScript' && /tmp/svg-deps
{
  lib,
  stdenv,
  fetchFromGitHub,
  gradle_9,
  jdk21,
}:
let
  gradle = gradle_9;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "simplevoice-geyser";
  version = "0.1.4-unstable-2026-11-08-pairing";

  src = fetchFromGitHub {
    owner = "TheodoreMeyer";
    repo = "SimpleVoice-Geyser";
    rev = "2460d1475290d3fef46e6eac4982ee05dc11f909"; # master after v0.1.4
    hash = "sha256-uOnWYFrUobwWV/g403VXkUGnANr1C7+ucLtXPkliYsw=";
  };

  patches = [ ./pairing.patch ];

  # Only the Spigot jar is needed. The Fabric module (Loom) would download
  # Minecraft itself while configuring.
  # spigot-api only exists as a -SNAPSHOT; pin the exact build, because the
  # lockfile can't rebuild snapshot metadata for versions with dashes in them.
  postPatch = ''
    substituteInPlace settings.gradle \
      --replace-fail 'include("core", "spigot", "fabric")' 'include("core", "spigot")'
    substituteInPlace spigot/build.gradle \
      --replace-fail '"org.spigotmc:spigot-api:''${spigot_api_version}-R0.1-SNAPSHOT"' \
                     '"org.spigotmc:spigot-api:1.20.1-R0.1-20230921.163938-66"'
  '';

  nativeBuildInputs = [ gradle ];

  mitmCache = gradle.fetchDeps {
    pkg = finalAttrs.finalPackage;
    data = ./deps.json;
  };

  # the build asks for a Java 21 toolchain
  gradleFlags = [
    "-Porg.gradle.java.installations.paths=${jdk21}/lib/openjdk"
    "-Porg.gradle.java.installations.auto-detect=false"
    "-Porg.gradle.java.installations.auto-download=false"
  ];

  gradleBuildTask = ":spigot:shadowJar";

  doCheck = true;
  gradleCheckTask = ":core:test";

  installPhase = ''
    runHook preInstall
    install -m 644 spigot/build/libs/Svg-Spigot-*.jar $out
    runHook postInstall
  '';

  meta = {
    description = "Lets Bedrock and modless Java players join Simple Voice Chat from a browser";
    homepage = "https://github.com/TheodoreMeyer/SimpleVoice-Geyser";
    license = lib.licenses.mit;
  };
})
