{ config, lib, pkgs, ... }: {
  home.packages = with pkgs; [ hyprland-autoname-workspaces ];
  home.file."autoname-workspaces" = {
    target = ".config/hyprland-autoname-workspaces/config.toml";
    text = ''
version = "1.1.12"

[format]
dedup = true
dedup_inactive_fullscreen = false
delim = " "
client = "{icon}{delim}"
client_active = "<span>{icon}</span>"
workspace = "<b><span>{id}:</span></b>{delim}{clients}"
workspace_empty = "<b><span color='grey'>{id}:</span></b>{delim}{clients}"
client_dup = "{icon}{counter_sup}{delim}"
client_dup_fullscreen = "[{icon}]{delim}{icon}{counter_unfocused_sup}"
client_fullscreen = "[{icon}]{delim}"

[class_active]
DEFAULT="{icon}"
"(?i)brave-browser" = "<span> {class}</span>"

# [initial_class]
# "DEFAULT" = " {class}: {title}"
# "(?i)Kitty" = "term"

# [initial_class_active]
# "(?i)Kitty" = "*TERM*"

# regex captures support is supported
[title_in_class."(?i)foot"]
"emerge: (.+?/.+?)-.*" = "{match1}"

[title_in_class."kitty"]
"nvim" = ""

# [initial_title_in_class."kitty"]
# "zsh" = "Zsh"

[title_in_class."(brave-browser|firefox|chrom.*)"]
"(?i)youtube" = ""
"(?i)twitch" = ""
"(?i)github" = ""

[title_active."(brave-browser|firefox|chrom.*)"]
"(?i)youtube" = "<span color='red'>{icon}</span>"
"(?i)twitch" = "<span color='purple'>{icon}</span>"

# [title_in_initial_class."(?i)kitty"]
# "(?i)neomutt" = "neomutt"

# [initial_title_in_initial_class."(?i)kitty"]
# "(?i)neomutt" = "neomutt"

# [initial_title."(?i)kitty"]
# "zsh" = "Zsh"

# [initial_title_active."(?i)kitty"]
# "zsh" = "*Zsh*"

[class]
DEFAULT = ""
"(?i)firefox" = "<span color='orange'> </span>"
"(?i)brave-browser" = "<span>󰖟</span>"
"(?i)kitty" = ""
"(?i)alacritty" = ""
bleachbit = ""
burp-startburp = ""
calibre-gui = ""
"chrome-faolnafnngnfdaknnbpnkhgohbobgegn-default" = ""
chromium = ""
"Gimp-2.10" = ""
code-oss = ""
cssh = ""
darktable = ""
discord = "󰙯"
dmenu-clipboard = ""
dmenu-pass = ""
duolingo = ""
element = ""
emacs = ""
fontforge = ""
gcr-prompter = ""
gsimplecalc = ""
"jetbrains-studio" = ""
"kak" = ""
kicad = ""
"(?i)waydroid.*" = "droid"
obsidian = ""
"dmenu-emoji" = "󰂛"
"dmenu-browser" = ""
"dmenu-pass generator" = ""
"qalculate-gtk" = ""
krita = ""
libreoffice-calc = ""
libreoffice-impress = ""
libreoffice-startcenter = ""
libreoffice-writer = ""
molotov = ""
mpv = ""
neomutt = ""
nm-connection-editor = ""
org-ksnip-ksnip = ""
org-pwmt-zathura = ""
org-qutebrowser-qutebrowser = ""
org-telegram-desktop = ""
paperwork = ""
pavucontrol = ""
personal = ""
plexamp = ""
qutepreview = ""
rapid-photo-downloader = ""
remote-viewer = ""
sandboxed-tor-browser = ""
scli = ""
shopping = ""
Signal = ""
slack = ""
snappergui = ""
songrec = ""
spotify = ""
steam = ""
streamlink-twitch-gui = ""
sun-awt-x11-xframepeer = ""
swappy = ""
taskwarrior-tui = ""
telegramdesktop = ""
".*transmission.*" = ""
udiskie = ""
vimiv = ""
virt-manager = ""
vlc = ""
vncviewer = ""
wayvnc = "󰀄"
whatsapp-desktop = ""
whatsapp-nativefier-d52542 = ""
wire = "󰁀"
wireshark-gtk = ""
wlfreerdp = "󰀄"
work = ""
xplr = ""
nemo = ""
zoom = ""

[exclude]
"" = "^$" # prevent displaying clients with empty class
    '';
  };
}
