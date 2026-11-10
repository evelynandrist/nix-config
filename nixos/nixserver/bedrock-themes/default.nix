# Geyser extension: optional UI themes for Bedrock players, chosen per
# player with /theme <name> (themes/*.mcpack next to this file; sent on the
# next join). Compiled with plain javac against the Geyser API jars.
# The Geyser API is only published as -SNAPSHOT; pinned to one build here.
{
  stdenv,
  fetchurl,
  jdk21,
}:
let
  repo = "https://repo.opencollab.dev/main";
  classpath = [
    (fetchurl {
      url = "${repo}/org/geysermc/geyser/api/2.12.1-SNAPSHOT/api-2.12.1-20261106.170248-21.jar";
      hash = "sha256-9r7U+EsSxmawlj1I7Dae3KpiT7FszaDpaYnRsdPlHOQ=";
    })
    (fetchurl {
      url = "${repo}/org/geysermc/api/base-api/1.0.3/base-api-1.0.3.jar";
      hash = "sha256-gD1gWFCOmncEBpJ7Sve7hV51CqPXxf6JhkqslPnbmPg=";
    })
    (fetchurl {
      url = "${repo}/org/geysermc/event/events/1.1-SNAPSHOT/events-1.1-20230815.153219-4.jar";
      hash = "sha256-LTUw9A5kp1kObzEp6x7dK0FpeT05cmXBXZcJokjmAjE=";
    })
    (fetchurl {
      url = "${repo}/org/geysermc/cumulus/cumulus/1.1.2/cumulus-1.1.2.jar";
      hash = "sha256-LC2AangqkqRJUmkkD4hXOkUtyvo3fq0yESMdOzYRo7U=";
    })
    (fetchurl {
      url = "${repo}/org/cloudburstmc/math/api/2.0/api-2.0.jar";
      hash = "sha256-Q0jVMrEdAz8cbhEDf+PQRSI4eDM9nhQMTxG7Mwm3IIM=";
    })
    (fetchurl {
      url = "${repo}/org/cloudburstmc/math/immutable/2.0/immutable-2.0.jar";
      hash = "sha256-atpQvgrGb0AStg7JsMfv6H8gHKmJ/T15Y0OKa7aYHr8=";
    })
  ];
in
stdenv.mkDerivation {
  pname = "obstgarten-themes";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [ jdk21 ];

  buildPhase = ''
    runHook preBuild
    mkdir classes
    javac --release 21 -encoding UTF-8 -Xlint:-options \
      -cp ${builtins.concatStringsSep ":" classpath} \
      -d classes ObstgartenThemes.java
    cp extension.yml classes/
    find classes -exec touch -d @315532800 {} +
    (cd classes && jar --create --file ../ObstgartenThemes.jar --date 1980-01-01T00:00:02Z .)
    runHook postBuild
  '';

  # $out/ObstgartenThemes.jar and $out/themes/*.mcpack
  installPhase = ''
    mkdir -p $out/themes
    install -m 644 ObstgartenThemes.jar $out/
    install -m 644 themes/*.mcpack $out/themes/
  '';
}
