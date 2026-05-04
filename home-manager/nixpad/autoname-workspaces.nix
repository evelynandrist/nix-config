{ config, lib, pkgs, ... }: {
  home.packages = with pkgs; [ hyprland-autoname-workspaces ];
  home.file."autoname-workspaces" = {
    target = ".config/hyprland-autoname-workspaces/config.toml";
    text = ''
version = "1.2.0"

[class]
jetbrains-studio = ""
signal = ""
streamlink-twitch-gui = ""
whatsapp-nativefier-d52542 = ""
libreoffice-calc = ""
nemo = ""
sun-awt-x11-xframepeer = ""
"(?i)waydroid.*" = "droid"
"dmenu-pass generator" = ""
"(?i)brave-browser" = "<span>󰖟</span>"
fontforge = ""
swappy = ""
discord = "󰙯"
org-ksnip-ksnip = ""
shopping = ""
taskwarrior-tui = ""
rapid-photo-downloader = ""
element = ""
qalculate-gtk = ""
xplr = ""
personal = ""
wire = "󰁀"
spotify = ""
kak = ""
dmenu-browser = ""
krita = ""
kicad = ""
vlc = ""
songrec = ""
dmenu-clipboard = ""
qutepreview = ""
paperwork = ""
burp-startburp = ""
snappergui = ""
code-oss = ""
whatsapp-desktop = ""
darktable = ""
gcr-prompter = ""
wayvnc = "󰀄"
virt-manager = ""
org-qutebrowser-qutebrowser = ""
work = ""
libreoffice-startcenter = ""
wlfreerdp = "󰀄"
libreoffice-impress = ""
neomutt = ""
zen = "<span>󰖟</span>"
calibre-gui = ""
plexamp = ""
molotov = ""
".*transmission.*" = ""
mpv = ""
pavucontrol = ""
dmenu-emoji = "󰂛"
remote-viewer = ""
"(?i)alacritty" = ""
"(?i)firefox" = "<span color='orange'> </span>"
chrome-faolnafnngnfdaknnbpnkhgohbobgegn-default = ""
obsidian = ""
"(?i)kitty" = ""
wireshark-gtk = ""
duolingo = ""
slack = ""
telegramdesktop = ""
vncviewer = ""
bleachbit = ""
"gimp-2.10" = ""
dmenu-pass = ""
scli = ""
emacs = ""
org-pwmt-zathura = ""
steam = ""
cssh = ""
vimiv = ""
chromium = ""
zoom = ""
nm-connection-editor = ""
org-telegram-desktop = ""
udiskie = ""
libreoffice-writer = ""
default = ""
sandboxed-tor-browser = ""
gsimplecalc = ""

[class_active]
"(?i)brave-browser" = "<span> {class}</span>"
default = "{icon}"

[initial_class]

[initial_class_active]

[workspaces_name]

[title_in_class."(?i)foot"]
"emerge: (.+?/.+?)-.*" = "{match1}"

[title_in_class.kitty]
nvim = ""

[title_in_class."(brave-browser|firefox|chrom.*|zen)"]
"(?i)twitch" = ""
"(?i)youtube" = ""
"(?i)github" = ""

[title_in_class_active]

[title_in_initial_class]

[title_in_initial_class_active]

[initial_title_in_class]

[initial_title_in_class_active]

[initial_title_in_initial_class]

[initial_title_in_initial_class_active]

[exclude]
"" = "^$"

[format]
dedup = true
dedup_inactive_fullscreen = false
delim = " "
workspace = "<b><span>{id}:</span></b>{delim}{clients}"
workspace_empty = "<b><span color='grey'>{id}:</span></b>{delim}{clients}"
client = "{icon}{delim}"
client_fullscreen = "[{icon}]{delim}"
client_active = "<span>{icon}</span>"
client_dup = "{icon}{counter_sup}{delim}"
client_dup_active = "*{icon}*{delim}{icon}{counter_unfocused_sup}"
client_dup_fullscreen = "[{icon}]{delim}{icon}{counter_unfocused_sup}"
    '';
  };
}
