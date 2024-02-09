{ pkgs }:
{
  url,
  width,
  height,
  ffmpegThreads
}:
pkgs.stdenvNoCC.mkDerivation {
  name = "fetched-wallpaper";
  buildInputs = with pkgs; [ curl toybox ffmpeg cacert ];
  unpackPhase = "true";
  buildPhase = ''
    path=$(curl --silent "${url}" | grep 'https://moewalls.com/download.php?' | sed "s/^.*https:\/\/moewalls\.com\/download\.php?video=\(.*\.mp4\).*$/\1/")

    curl -L -o video.mp4 https://static.moewalls.com/videos/download$path

    original_height="$(ffprobe -v error -show_entries stream=height -of csv=p=0 video.mp4)"
    crop_width="$(($original_height*(${width}*1000/${height})/1000))"

    ffmpeg -i video.mp4 -vf "fps=fps=30,crop=$crop_width:$original_height,scale=${width}:${height}" -c:v libx265 -c:a copy -preset slow -tune fastdecode -threads 14 wallpaper.mp4

    ffmpeg -i wallpaper.mp4 -vf "select=eq(n\,0)" -q:v 3 wallpaper.jpg
  '';
  installPhase = "mkdir -p $out && cp wallpaper.mp4 $out && cp wallpaper.jpg $out";
  __noChroot = true;
}
