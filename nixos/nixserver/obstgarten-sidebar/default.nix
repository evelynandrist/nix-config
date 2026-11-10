# Our own tiny plugin: the sidebar for TAB (nether goal, one line per member:
# name, hearts, diamonds, voice chat note; nicknames on name tags).
# Compiled with plain javac against the API jars; everything it uses is provided by the server.
{
  lib,
  stdenv,
  fetchurl,
  jdk21,
}:
let
  # compile-time APIs only (not shipped in the jar)
  spigotApi = fetchurl {
    url = "https://hub.spigotmc.org/nexus/content/groups/public/org/spigotmc/spigot-api/1.20.1-R0.1-SNAPSHOT/spigot-api-1.20.1-R0.1-20230921.163938-66.jar";
    hash = "sha256-2Ko1Z4HjKJbn14SQgTl1ysfKjZkSatxBwoNsVsaLnD4=";
  };
  placeholderApi = fetchurl {
    url = "https://repo.extendedclip.com/releases/me/clip/placeholderapi/2.11.6/placeholderapi-2.11.6.jar";
    hash = "sha256-sgywnbHNefdrkXLlEU395vNMVYBp4717crFPcYvF3/0=";
  };
  voicechatApi = fetchurl {
    url = "https://maven.maxhenkel.de/repository/public/de/maxhenkel/voicechat/voicechat-api/2.6.0/voicechat-api-2.6.0.jar";
    hash = "sha256-Tn96nI4xinzmrqErrAMJddFNt6KY/dFRHWHWbG5jTEM=";
  };
  # the plugin jar itself (it carries its API); the server downloads it
  # fresh like the other plugins, see updatePlugins in ../minecraft.nix
  packetEvents = fetchurl {
    url = "https://cdn.modrinth.com/data/HYKaKraK/versions/m78nFxYg/packetevents-spigot-2.14.0.jar";
    hash = "sha256-BgCHxY7CaOrn3Q6x8XrDvqHqrdoWk0FBQf9k5QYJG9c=";
  };
  # Adventure (text components), for the chat messages; at runtime Paper's own
  adventure = map fetchurl [
    {
      url = "https://repo1.maven.org/maven2/net/kyori/adventure-api/4.17.0/adventure-api-4.17.0.jar";
      hash = "sha256-FcjC6xpp2LG8kU9VQ1PajufPB0wFyAdNqYmK7lxw0Ng=";
    }
    {
      url = "https://repo1.maven.org/maven2/net/kyori/adventure-key/4.17.0/adventure-key-4.17.0.jar";
      hash = "sha256-jlz1cGEtbM7flDrBcWpEneLdWpAge33m9zwCNpNbdm4=";
    }
    {
      url = "https://repo1.maven.org/maven2/net/kyori/examination-api/1.3.0/examination-api-1.3.0.jar";
      hash = "sha256-ySN//ssFQo9u/4YhYkascM4LR7BMCOp8o1Ag/eV/hJI=";
    }
  ];
in
stdenv.mkDerivation {
  pname = "obstgarten-sidebar";
  version = "1.2.0";

  src = ./.;

  nativeBuildInputs = [ jdk21 ];

  buildPhase = ''
    runHook preBuild
    mkdir classes
    javac --release 21 -encoding UTF-8 -Xlint:-options \
      -cp ${lib.concatStringsSep ":" ([ spigotApi placeholderApi voicechatApi packetEvents ] ++ adventure)} \
      -d classes ObstgartenSidebar.java
    cp plugin.yml classes/
    # fixed timestamps for a reproducible jar
    find classes -exec touch -d @315532800 {} +
    (cd classes && jar --create --file ../ObstgartenSidebar.jar --date 1980-01-01T00:00:02Z .)
    runHook postBuild
  '';

  installPhase = ''
    install -m 644 ObstgartenSidebar.jar $out
  '';
}
