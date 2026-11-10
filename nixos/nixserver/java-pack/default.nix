# Server resource pack for Java players: only the sidebar icons
# (../sidebar-icons) as extra characters of the default font. Font
# definitions add up across packs, so the normal font stays untouched.
# Served by nginx on mc.qwt.ch; the URL contains the store hash, so a
# changed pack gets a new URL and clients don't keep an old copy.
{
  runCommand,
  writeText,
  zip,
  icons,
}:
let
  mcmeta = writeText "pack.mcmeta" (builtins.toJSON {
    pack = {
      description = "Obstgarten";
      # 26.2 = resource format 88
      pack_format = 88;
      min_format = 88;
      max_format = 999;
    };
  });
  font = writeText "default.json" (builtins.toJSON {
    providers = [
      {
        type = "bitmap";
        file = "minecraft:font/obstgarten.png";
        # a pixel taller than the letters, like the hearts in the HUD
        ascent = 8;
        height = 9;
        # U+E100 diamond, U+E101 chestplate, U+E102 heart, U+E103 speaker
        # (nix strings have no \u escape)
        chars = [ (builtins.fromJSON ''"\ue100\ue101\ue102\ue103"'') ];
      }
    ];
  });
in
runCommand "obstgarten-java-pack.zip" { nativeBuildInputs = [ zip ]; } ''
  mkdir -p pack/assets/minecraft/font pack/assets/minecraft/textures/font
  cp ${mcmeta} pack/pack.mcmeta
  cp ${font} pack/assets/minecraft/font/default.json
  cp ${icons}/java.png pack/assets/minecraft/textures/font/obstgarten.png
  find pack -exec touch -d @315532800 {} +
  (cd pack && zip -X -r -D ../pack.zip pack.mcmeta assets)
  cp pack.zip $out
''
