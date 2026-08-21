# xcode-build-server — Build Server Protocol implementation bridging Xcode and
# sourcekit-lsp.
#
# sourcekit-lsp cannot work out compiler flags for an Xcode workspace on its own:
# it needs the per-file arguments that only xcodebuild knows. `xcode-build-server
# config -workspace ... -scheme ...` writes a buildServer.json next to the
# project, which sourcekit-lsp then reads to answer completion and go-to-definition.
# Without it, every `import SwiftUI` in an Xcode project is an unresolved module.
#
# Not in nixpkgs. Pure Python with no dependencies beyond the interpreter, so
# this is a source copy plus a wrapper rather than a real build.
{ lib
, stdenvNoCC
, fetchFromGitHub
, python3
, makeWrapper
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "xcode-build-server";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "SolaWing";
    repo = "xcode-build-server";
    tag = "v${finalAttrs.version}";
    hash = "sha256-AUGDoMeW/FSMJLG7uR580cMpytYQBFV2PXE3LBNaiFQ=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/xcode-build-server
    cp -r . $out/libexec/xcode-build-server

    # The entry point is a Python script that imports its siblings by relative
    # path, so it has to keep running from inside libexec.
    makeWrapper ${python3}/bin/python3 $out/bin/xcode-build-server \
      --add-flags $out/libexec/xcode-build-server/xcode-build-server

    runHook postInstall
  '';

  meta = {
    description = "Build server protocol implementation for integrating Xcode with sourcekit-lsp";
    homepage = "https://github.com/SolaWing/xcode-build-server";
    license = lib.licenses.mit;
    mainProgram = "xcode-build-server";
    platforms = lib.platforms.darwin;
    maintainers = [ ];
  };
})
