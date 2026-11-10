# Small Bedrock resource pack that Geyser pushes to every Bedrock player
# (plugins/Geyser-Spigot/packs, forced like Geyser's own pack):
# hides the red score numbers in the sidebar (Bedrock can't hide them
# otherwise, and TAB uses them to sort the lines), draws the sidebar a bit
# smaller, and draws the sidebar icons (../sidebar-icons, glyph page E1).
# Bump `version` on every change, or clients keep their cached copy.
{
  runCommand,
  writeText,
  zip,
  icons,
}:
let
  version = [ 1 2 1 ];

  manifest = writeText "manifest.json" (builtins.toJSON {
    format_version = 2;
    header = {
      name = "Obstgarten";
      description = "Obstgarten server tweaks";
      uuid = "30d5c353-a4e3-4dd7-8b65-9b083c095a39";
      inherit version;
      min_engine_version = [ 1 21 120 ];
    };
    # UI and font only, no block textures: declaring pbr keeps Vibrant Visuals available
    # (Bedrock turns it off while a pack without this is active).
    capabilities = [ "pbr" ];
    modules = [
      {
        type = "resources";
        uuid = "b04320dc-3994-43b2-af95-fe762d66aeea";
        inherit version;
      }
    ];
  });

  # ui/scoreboards.json overrides the sidebar from vanilla ui/scoreboards.json
  # (Mojang's bedrock-samples; elements with the same name merge, a
  # "controls" list replaces the vanilla one):
  # - no score column: the "scores" stack (one red number per line, which TAB
  #   only uses for sorting) and the 10px gap before it are left out, and
  #   the score label is ignored in case anything else creates it
  # - title and lines at 0.8 of the font size (labels 8 instead of 10 high,
  #   list offset and title background to match), so the sidebar takes less
  #   of a phone or Switch screen. Everything else is copied unchanged.
  scoreboards = ./scoreboards.json;
in
runCommand "obstgarten-bedrock-pack.mcpack" { nativeBuildInputs = [ zip ]; } ''
  mkdir -p pack/ui pack/font
  cp ${manifest} pack/manifest.json
  cp ${scoreboards} pack/ui/scoreboards.json
  cp ${icons}/glyph_E1.png pack/font/glyph_E1.png
  find pack -exec touch -d @315532800 {} +
  (cd pack && zip -X -r -D ../pack.zip manifest.json ui font)
  cp pack.zip $out
''
