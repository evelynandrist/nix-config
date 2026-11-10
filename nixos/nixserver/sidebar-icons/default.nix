# Icons for the sidebar, as font characters both editions can show:
#   U+E100 diamond, U+E101 diamond chestplate, U+E102 heart, U+E103 speaker
# (used by ./obstgarten-sidebar, drawn by ./bedrock-pack and ./java-pack).
# Heart and speaker are icons too, not ❤/♪: Bedrock draws a line with such
# characters in its smaller Unicode font, so lines with and without them
# came out in different sizes.
# The textures are Mojang's own, from the samples they publish for pack
# makers. The text colour tints them (white = as is; the speaker is white
# and gets green).
#
# The two editions size glyphs differently:
# - Java scales each cell to the line height (../java-pack), so it gets the
#   full 16px textures.
# - Bedrock draws one pixel of the glyph page as one pixel of the font,
#   whatever the page size (16px icons were twice the text height, a 512px
#   page with 32px tiles three lines). So its icons are about text sized:
#   diamond and chestplate scaled down to 10px, the HUD heart at its own
#   9px, and a hand-drawn 9x7 speaker (the 16x12 one turns to mush when
#   scaled down). Still 16px cells on a 256px page, like Mojang's own
#   pages; the icon sits in the middle of its cell.
{
  runCommand,
  fetchurl,
  writeText,
  imagemagick,
}:
let
  samples = "https://raw.githubusercontent.com/Mojang/bedrock-samples/v1.26.60.5/resource_pack/textures";
  get = path: hash: fetchurl { url = "${samples}/${path}"; inherit hash; };
  diamond = get "items/diamond.png" "sha256-mW+AFIppCViNj4PUYt2+pTAkArpkT459LlvwtpEZuGI=";
  chestplate = get "items/diamond_chestplate.png" "sha256-G8cH66VYzXq1jyH9LV9UT41duE+IoNWiU/jqO9Hxp/Q=";
  heart = get "ui/heart.png" "sha256-lPr68lMdrdIQZacVvZQgyQ55e1i7he1mB9n03nRtYmI=";
  heartBackground = get "ui/heart_background.png" "sha256-UpWwgl1s3xAQjdukj/71VAhOe5NBJ0Nn2HZ5+6YiNng=";
  speaker = get "ui/sound_glyph.png" "sha256-BrHv7VzrMILHtkIYQaUtdaGPTiZ7/KiOr4ugM8+CRN4=";
  smallSpeaker = writeText "speaker.xpm" ''
    /* XPM */
    static char *speaker[] = {
    "9 7 2 1",
    ". c None",
    "# c #FFFFFF",
    "...#.....",
    "..##...#.",
    "####.#..#",
    "####.#..#",
    "####.#..#",
    "..##...#.",
    "...#.....",
    };
  '';
  # no timestamps in the PNGs, so the packs stay reproducible
  png = "-strip -define png:exclude-chunks=date,time PNG32";
  # centred on a transparent 16x16 tile
  pad = "-background none -gravity center -extent 16x16";
  # glyph_E1.png: 16x16 grid, cell n is U+E1nn
  page = tiles: ''
    magick -size 256x256 xc:none \
      ${tiles}/0.png -geometry +0+0 -composite \
      ${tiles}/1.png -geometry +16+0 -composite \
      ${tiles}/2.png -geometry +32+0 -composite \
      ${tiles}/3.png -geometry +48+0 -composite \
      ${png}:$out/glyph_E1.png
  '';
in
runCommand "obstgarten-sidebar-icons" { nativeBuildInputs = [ imagemagick ]; } ''
  mkdir -p $out java bedrock
  magick ${heartBackground} ${heart} -composite ${png}:heart.png

  # Java: one row, one 16px cell per character
  magick ${diamond} ${pad} ${png}:java/0.png
  magick ${chestplate} ${pad} ${png}:java/1.png
  magick heart.png -filter point -resize 16x16 ${pad} ${png}:java/2.png
  magick ${speaker} ${pad} ${png}:java/3.png
  magick java/0.png java/1.png java/2.png java/3.png -background none +append \
    ${png}:$out/java.png

  # Bedrock: about text sized, see above
  magick ${diamond} -filter box -resize 10x10 ${pad} ${png}:bedrock/0.png
  magick ${chestplate} -filter box -resize 10x10 ${pad} ${png}:bedrock/1.png
  magick heart.png ${pad} ${png}:bedrock/2.png
  magick ${smallSpeaker} ${pad} ${png}:bedrock/3.png
  ${page "bedrock"}
''
