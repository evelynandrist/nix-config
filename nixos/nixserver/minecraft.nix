{ config, lib, pkgs, ... }:
# Family survival server: Paper + Geyser/Floodgate, so Xbox, Switch and PC can
# play together. Bedrock consoles join through the friends tab of the
# ObstgartenGang Xbox account (MCXboxBroadcast).
#
# Console:  tmux -S /run/minecraft/obstgarten.sock attach   (detach: Ctrl-b d)
#           (the socket is mode 660 minecraft:minecraft; the main user is in that group)
# Map:      https://mc.qwt.ch
# Voice:    Simple Voice Chat (Java mod, UDP 24454) + https://voice.mc.qwt.ch
#           for everyone else (SimpleVoice-Geyser, login = one-time code / QR
#           map from /svg pair or the Bedrock emote menu; name + /svg pswd also works)
let
  name = "obstgarten";
  dataDir = "${config.services.minecraft-servers.dataDir}/${name}";
  tmuxSocket = config.services.minecraft-servers.managementSystem.tmux.socketPath name;

  # The Minecraft version only changes when this attribute is bumped by hand,
  # `nix flake update` just pulls newer Paper builds of the same version.
  # Before bumping, check that CoreProtect, BlueMap, LuckPerms and Chunky have
  # releases for the new version on Modrinth.
  paper = pkgs.paperServers.paper-26_2;
  mcVersion = lib.head (lib.splitString "-build" paper.version);

  # SimpleVoice-Geyser: Bedrock players and Java players without the mod join
  # Simple Voice Chat through a web page. Small project (one maintainer), so
  # built from a pinned commit instead of "newest", plus our password-less
  # login (one-time code + QR map), see ./simplevoice-geyser.
  # (source read for 0.1.4: only network access is the Modrinth update check,
  # which is switched off below).
  svgJar = pkgs.callPackage ./simplevoice-geyser { };

  # Our own: the sidebar for TAB (nether goal, one line per member), the
  # Bedrock pack Geyser pushes to Bedrock players (hides the sidebar numbers,
  # icons) and the server resource pack for Java players (icons).
  sidebarJar = pkgs.callPackage ./obstgarten-sidebar { };
  sidebarIcons = pkgs.callPackage ./sidebar-icons { };
  bedrockPack = pkgs.callPackage ./bedrock-pack { icons = sidebarIcons; };
  javaPack = pkgs.callPackage ./java-pack { icons = sidebarIcons; };
  # store hash in the URL: a new pack is a new URL (see ./java-pack). Only
  # the name (an attribute name can't refer to a store path); nginx's
  # `alias` below keeps the pack itself in the system.
  javaPackPath = "/pack/${builtins.unsafeDiscardStringContext (baseNameOf javaPack)}";
  # Geyser extension + optional UI looks (bedrock-themes/themes/*.mcpack),
  # each Bedrock player picks one with /theme <name>; nobody gets one by default
  bedrockThemes = pkgs.callPackage ./bedrock-themes { };
  svgPort = 8110; # web page, only on localhost behind nginx (BlueMap has 8100)
  svcPort = 24454; # Simple Voice Chat's own UDP port, for players with the mod

  # Bedrock clients update themselves, and Geyser only speaks the newest
  # protocols. So everything on the Bedrock side (Geyser, Floodgate, the Geyser
  # extensions and ViaVersion, which lets the newest Geyser join this older
  # Paper) is fetched fresh on every start, and the server restarts nightly.
  # Version-bound plugins take the newest release for ${mcVersion}.
  # A failed download keeps the jar from the previous start.
  updatePlugins = pkgs.writeShellApplication {
    name = "minecraft-${name}-update-plugins";
    runtimeInputs = with pkgs; [ coreutils curl jq unzip gnugrep ];
    text = ''
      mcVersion=${lib.escapeShellArg mcVersion}
      ext=plugins/Geyser-Spigot/extensions
      mkdir -p plugins "$ext"

      # fetch <destination> <url>
      fetch() {
        local dest="$1" url="$2" tmp
        if [ -z "$url" ]; then
          echo "WARNING: no download found for $dest, keeping the existing file" >&2
          return 0
        fi
        tmp="$(mktemp "$dest.part.XXXXXX")"
        if curl -fsSL --retry 3 --connect-timeout 10 --max-time 300 -o "$tmp" "$url" \
          && unzip -Z1 "$tmp" >/dev/null; then # complete zip/jar, not an error page
          mv -f "$tmp" "$dest"
          echo "updated $dest"
        else
          rm -f "$tmp"
          echo "WARNING: downloading $url failed, keeping the existing $dest" >&2
        fi
      }

      # modrinth <slug> [minecraft version] -> url of the newest release
      modrinth() {
        local query="loaders=%5B%22paper%22%5D"
        if [ -n "''${2:-}" ]; then
          query="$query&game_versions=%5B%22$2%22%5D"
        fi
        curl -fsS --retry 3 --max-time 30 "https://api.modrinth.com/v2/project/$1/version?$query" \
          | jq -r '[.[] | select(.version_type == "release")][0].files // []
                   | (map(select(.primary))[0] // .[0]).url // empty' \
          || true
      }

      geyser="https://download.geysermc.org/v2/projects"

      # Bedrock side: always the newest
      fetch plugins/Geyser-Spigot.jar   "$geyser/geyser/versions/latest/builds/latest/downloads/spigot"
      fetch plugins/floodgate-spigot.jar "$geyser/floodgate/versions/latest/builds/latest/downloads/spigot"
      fetch plugins/ViaVersion.jar      "$(modrinth viaversion)"
      fetch "$ext/MCXboxBroadcastExtension.jar" \
        "https://github.com/MCXboxBroadcast/Broadcaster/releases/latest/download/MCXboxBroadcastExtension.jar"
      # Emotes open the voice chat menu (SimpleVoice-Geyser) instead of swapping
      # hands. Bedrock gets its own offhand key with 26.70.
      rm -f "$ext/EmoteOffhand.jar"

      # Bound to the Minecraft version
      fetch plugins/LuckPerms.jar   "$(modrinth luckperms "$mcVersion")"
      fetch plugins/BlueMap.jar     "$(modrinth bluemap "$mcVersion")"
      fetch plugins/CoreProtect.jar "$(modrinth coreprotect "$mcVersion")"
      fetch plugins/Chunky.jar      "$(modrinth chunky "$mcVersion")"
      # items go into a grave at the death spot (keepInventory stays off)
      fetch plugins/GravesX.jar     "$(modrinth gravesx "$mcVersion")"
      # sidebar with the online players (see tabScoreboards)
      fetch plugins/TAB.jar         "$(modrinth tab-was-taken "$mcVersion")"
      fetch plugins/PlaceholderAPI.jar "$(modrinth placeholderapi "$mcVersion")"
      # lets ./obstgarten-sidebar put the nicknames on the name tags
      fetch plugins/packetevents.jar "$(modrinth packetevents "$mcVersion")"
      # proximity voice: Simple Voice Chat (server side of the Java mod) and
      # the web bridge for everyone without the mod (pinned, see svgJar)
      fetch plugins/voicechat.jar   "$(modrinth simple-voice-chat "$mcVersion")"
      install -m 644 ${svgJar} plugins/SimpleVoice-Geyser.jar
      # sidebar lines (see tabScoreboards); replaces the PlayerList and
      # Player expansions from PlaceholderAPI's store
      install -m 644 ${sidebarJar} plugins/ObstgartenSidebar.jar
      rm -f plugins/PlaceholderAPI/expansions/Expansion-playerlist.jar \
        plugins/PlaceholderAPI/expansions/Expansion-player.jar
      # Bedrock pack, sent by Geyser on join (force-resource-packs is on)
      mkdir -p plugins/Geyser-Spigot/packs
      install -m 644 ${bedrockPack} plugins/Geyser-Spigot/packs/obstgarten.mcpack
      # Optional looks per Bedrock player (/theme pink, /theme normal); the
      # choices stay in extensions/obstgartenthemes/choices.properties
      themesDir=plugins/Geyser-Spigot/extensions/obstgartenthemes/themes
      mkdir -p "$themesDir"
      install -m 644 ${bedrockThemes}/ObstgartenThemes.jar plugins/Geyser-Spigot/extensions/
      rm -f "$themesDir"/*.mcpack
      install -m 644 ${bedrockThemes}/themes/*.mcpack "$themesDir"/

      # EssentialsX: the dev builds support new Minecraft versions months
      # before a stable release does
      ess="https://ci.ender.zone/job/EssentialsX/lastSuccessfulBuild"
      essJars="$(curl -fsS --retry 3 --max-time 30 "$ess/api/json?tree=artifacts%5BrelativePath%5D" \
        | jq -r '.artifacts[].relativePath' || true)"
      for module in EssentialsX EssentialsXSpawn EssentialsXProtect; do
        jar="$(grep -E "^jars/$module-[0-9]" <<<"$essJars" | head -n1 || true)"
        fetch "plugins/$module.jar" "''${jar:+$ess/artifact/$jar}"
      done
    '';
  };

  maxPlayers = 10;

  # Sidebar (lines from ./obstgarten-sidebar). The nether stays closed until
  # everyone has a diamond chestplate (gamerule, see serverProperties), so the title and
  # first line say "Nether öffnet, wenn / alle [chestplate] haben". Then one
  # line per member (whitelist + ops; online first, offline grey): Essentials
  # nickname, hearts, diamonds collected x/8 or the chestplate, a speaker when in
  # voice chat. Once the gamerule is on, the title says "Nether ist offen!"
  # and goal and diamonds disappear.
  # A line that is only a placeholder and comes out empty is hidden by TAB,
  # so one board with maxPlayers lines fits any player count. Each player can
  # hide it with /sb (TAB remembers the choice).
  # Bedrock shows red numbers next to the lines; ./bedrock-pack hides them.
  tabScoreboards = pkgs.writeText "tab-scoreboards.json" (builtins.toJSON {
    players = {
      title = "%obstgarten_title%";
      lines = [ "%obstgarten_goal%" ]
        ++ map (i: "%obstgarten_line_${toString i}%") (lib.range 0 (maxPlayers - 1));
    };
  });

  # Single settings in config files the plugins generate themselves on their
  # first start. Takes effect from the second start on.
  patchConfigs = pkgs.writeShellApplication {
    name = "minecraft-${name}-patch-configs";
    runtimeInputs = with pkgs; [ gnused yq-go ];
    text = ''
      # set_key <file> <key> <value>, for `key: value` lines at any indentation,
      # so the key has to be unique within the file
      set_key() {
        if [ -f "$1" ]; then
          sed -i -E "s|^([[:space:]]*)$2:.*|\1$2: $3|" "$1"
        fi
      }

      # Bedrock server list / Xbox friends tab. MCXboxBroadcast reads these
      # straight from the config on start (no MOTD passthrough), so both are
      # set, otherwise it shows "Geyser" / "Another Geyser server."
      geyser=plugins/Geyser-Spigot/config.yml
      set_key "$geyser" primary-motd '"Obstgarten"'
      set_key "$geyser" secondary-motd '"Obstgarten"'
      set_key "$geyser" server-name '"Obstgarten"'

      # EssentialsXProtect: creepers still explode and hurt, but leave
      # buildings alone; endermen don't pick up blocks
      essentials=plugins/Essentials/config.yml
      set_key "$essentials" creeper-blockdamage true
      set_key "$essentials" enderman-pickup true
      # no starter kit (stone tools) on the first join, plain survival start
      set_key "$essentials" kit "'''"
      # Respawn at the bed (or charged anchor), else at the first /sethome
      # home, else at spawn. EssentialsXSpawn handles respawning, and with
      # respawn-at-home off it sent everyone to spawn and ignored the bed.
      set_key "$essentials" respawn-at-home true
      set_key "$essentials" respawn-at-home-bed true
      set_key "$essentials" respawn-at-anchor true
      # nicknames (set with /nick, the sidebar shows them too) without "~"
      set_key "$essentials" nickname-prefix "'''"

      # keep pregenerating after the nightly restart
      set_key plugins/Chunky/config.yml continue-on-restart true

      # Fog of war: chunks only show up on the map once a player has been
      # nearby (pregenerated chunks have an inhabited time of 0). 20 ticks = 1s
      for map in plugins/BlueMap/maps/*.conf; do
        set_key "$map" min-inhabited-time 20
      done

      # TAB: only the sidebar; everything else (tab list names, name tags,
      # header/footer, bossbar) stays vanilla. No ping column: Geyser
      # answers the server's pings itself (forward-player-ping off, it can
      # cause timeouts), so Bedrock players always showed 0 ms.
      tab=plugins/TAB/config.yml
      if [ -f "$tab" ]; then
        yq -i '
          .header-footer.enabled = false |
          .tablist-name-formatting.enabled = false |
          .scoreboard-teams.enabled = false |
          .playerlist-objective.enabled = false |
          .belowname-objective.enabled = false |
          .bossbar.enabled = false |
          .layout.enabled = false |
          .proxy-support.enabled = false |
          .scoreboard.enabled = true |
          .scoreboard.remember-toggle-choice = true |
          .scoreboard.scoreboards = load("${tabScoreboards}")
        ' "$tab"
      fi

      # SimpleVoice-Geyser: web page only on localhost (nginx in front, see
      # voice.mc.qwt.ch), no update check (pinned), and no default group with
      # its publicly known default password; groups are made in the menu.
      # Login by pairing: the code / QR map works once for 2 minutes, then
      # that browser stays logged in (devices.json, hashed). Passwords still
      # work for whoever set one.
      svg=plugins/SimpleVoice-Geyser/config.yml
      if [ -f "$svg" ]; then
        yq -i '
          .server.bind-address = "127.0.0.1" |
          .server.port = ${toString svgPort} |
          .server.group.default.enabled = false |
          .server.pairing.enabled = true |
          .server.pairing.public-url = "https://voice.mc.qwt.ch" |
          .updatechecker.enable = false |
          .client.join-message.text = [
            "Voice chat in the browser (phone, tablet, PC):",
            "Bedrock: emote -> Connect browser. Java: /svg pair",
            "Then scan the map in your hand, or enter the code on https://voice.mc.qwt.ch"
          ]
        ' "$svg"
      fi

      # Simple Voice Chat: players with the mod can't record conversations
      sed -i -E 's/^allow_recording=.*/allow_recording=false/' \
        plugins/voicechat/voicechat-server.properties 2>/dev/null || true
    '';
  };

  # Copied in fresh on every start (nix-minecraft `files`)
  blueMapCore = pkgs.writeText "core.conf" ''
    accept-download: true
    data: "bluemap"
    render-thread-count: 2
    scan-for-mod-resources: true
    metrics: false
    log: {
      file: "bluemap/logs/debug.log"
      append: false
    }
  '';

  homeIpDir = "/run/nginx-home-ip";

  backupDir = "/persist/backups";
  backupPasswordFile = "${backupDir}/minecraft-restic.password";
  # Types a command into the server console, but only while the server is
  # fully started. During a start (or a stop) the command would either hit
  # unloaded worlds or get lost; a fresh start has saving on anyway.
  serverCommand = pkgs.writeShellApplication {
    name = "minecraft-${name}-command";
    runtimeInputs = with pkgs; [ tmux systemd gnugrep ];
    text = ''
      if systemctl is-active --quiet minecraft-server-${name}.service \
        && grep -qF 'For help, type "help"' ${dataDir}/logs/latest.log 2>/dev/null; then
        tmux -S ${tmuxSocket} send-keys C-u "$1" Enter
      else
        echo "server not running or still starting, skipping '$1'"
        exit 1
      fi
    '';
  };
  sendCommand = cmd: "${lib.getExe serverCommand} ${lib.escapeShellArg cmd}";
in {
  # Prefer dropping page cache over swapping out the (pretouched) Java heap.
  # A swapped-out heap freezes the server for seconds whenever GC walks it.
  boot.kernel.sysctl."vm.swappiness" = 10;

  # For attaching to the console (see the top of this file)
  environment.systemPackages = [ pkgs.tmux ];

  services.minecraft-servers.servers.${name} = {
    enable = true;
    package = paper;
    openFirewall = true; # 25565/tcp, Java

    # 15G RAM total on nixserver. More heap only means longer GC pauses once
    # the server has enough, and free RAM still speeds up the world files via
    # the page cache.
    jvmOpts = lib.concatStringsSep " " [
      "-Xms8G" "-Xmx8G"
      # Aikar's flags (https://docs.papermc.io/paper/aikars-flags)
      "-XX:+UseG1GC" "-XX:+ParallelRefProcEnabled" "-XX:MaxGCPauseMillis=200"
      "-XX:+UnlockExperimentalVMOptions" "-XX:+DisableExplicitGC" "-XX:+AlwaysPreTouch"
      "-XX:G1NewSizePercent=30" "-XX:G1MaxNewSizePercent=40" "-XX:G1HeapRegionSize=8M"
      "-XX:G1ReservePercent=20" "-XX:G1HeapWastePercent=5" "-XX:G1MixedGCCountTarget=4"
      "-XX:InitiatingHeapOccupancyPercent=15" "-XX:G1MixedGCLiveThresholdPercent=90"
      "-XX:SurvivorRatio=32" "-XX:+PerfDisableSharedMem" "-XX:MaxTenuringThreshold=1"
      "-Dusing.aikars.flags=https://mcflags.emc.gs" "-Daikars.new.flags=true"
    ];

    serverProperties = {
      server-port = 25565;
      motd = "Obstgarten";
      difficulty = "easy";
      gamemode = "survival";
      max-players = maxPlayers;
      # chunks sent to clients (Bedrock clients cap this with their own setting)
      view-distance = 28;
      # chunks where mobs, crops and redstone actually run
      simulation-distance = 8;
      # otherwise only operators can build near spawn
      spawn-protection = 0;
      online-mode = true;
      # Managed in-game (`whitelist add <java name>`, `fwhitelist add <gamertag>`),
      # nix-minecraft leaves whitelist.json alone as long as `whitelist` is empty
      white-list = true;
      enforce-whitelist = true;
      # Bedrock players (Floodgate) have no Mojang chat-signing key, so with
      # this on their chat is disabled ("missing profile public key")
      enforce-secure-profile = false;
      # The vanilla anti-fly check ("kicked for floating too long") misfires
      # for Bedrock players, whose movement Geyser translates (scaffolding,
      # ladders, bubble columns, lag). Geyser recommends turning it off; this
      # doesn't let anyone fly without a cheat client.
      allow-flight = true;
      # The nether is closed until everyone has a diamond chestplate (the
      # sidebar shows the progress), so the newer players aren't left far
      # behind. Not allow-nether here, this version ignores it: the world
      # gamerule decides, right away, no restart. In the console:
      #   gamerule allow_entering_nether_using_portals false|true
      # Icons for the sidebar (./java-pack); Bedrock gets them from ./bedrock-pack
      resource-pack = "https://mc.qwt.ch${javaPackPath}";
      require-resource-pack = true;
    };

    # No operators: everyone plays plain survival, admin happens in the
    # console. With this empty nix-minecraft leaves ops.json alone, so ops
    # are managed in-game (`op` / `deop`) like the whitelist.

    # Player permissions live in LuckPerms (plugins/LuckPerms), not here. The
    # `default` group has, each set on its own (one node per command, extra
    # words would be read as contexts):
    #   lp group default permission set <node> true
    #   essentials.sethome  essentials.sethome.multiple (3 homes)  essentials.delhome
    #   essentials.tpa  essentials.tpahere  essentials.tpaccept  essentials.tpdeny
    #   essentials.tpacancel  essentials.warp  essentials.warp.list
    #   essentials.msg  essentials.list  tab.scoreboard.toggle (/sb)
    #   voicechat.speak  voicechat.listen  voicechat.groups (Simple Voice
    #   Chat gives these to nobody by default, also needed for the web page)
    #   svg.vc.group.join (SimpleVoice-Geyser 0.1.4 checks it but never declares
    #   it, so only ops could join groups; declared in our pairing.patch now)
    # Left out on purpose: essentials.home, .back, .spawn (no teleporting out
    # of caves; homes only count as the respawn point when the bed is gone).
    # GravesX's player commands (graves.gui, graves.teleport) are on by default.

    # Geyser's NetherNet (the current Bedrock connection method) extracts a
    # prebuilt WebRTC library (libdatachannel) that expects OpenSSL 3 and
    # libgcc_s in the usual system paths, which NixOS doesn't have
    environment.LD_LIBRARY_PATH = lib.makeLibraryPath [
      pkgs.openssl
      pkgs.stdenv.cc.cc.lib
    ];

    # The console (jline) runs `infocmp` to detect the terminal and logs a
    # harmless stack trace on startup when it's missing
    path = [ pkgs.ncurses ];

    extraStartPre = ''
      ${lib.getExe updatePlugins}
      ${lib.getExe patchConfigs}
    '';

    files."plugins/BlueMap/core.conf" = blueMapCore;
  };

  # NetherNet's WebRTC library lists the network interfaces (getifaddrs) to
  # gather connection candidates, which needs netlink sockets. nix-minecraft's
  # hardening only allows unix/inet/inet6, so add it to that list.
  systemd.services."minecraft-server-${name}".serviceConfig.RestrictAddressFamilies = [ "AF_NETLINK" ];

  # Geyser (Bedrock): RakNet and the NetherNet WebRTC connection over UDP,
  # Geyser's built-in NetherNet signaling over TCP
  networking.firewall.allowedUDPPorts = [ 19132 svcPort ];
  networking.firewall.allowedTCPPorts = [ 19132 ];

  # Pick up new Geyser/Floodgate builds every night
  systemd.services."minecraft-${name}-nightly-restart" = {
    description = "Restart the ${name} Minecraft server to update Geyser";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl try-restart minecraft-server-${name}.service";
    };
  };
  systemd.timers."minecraft-${name}-nightly-restart" = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "*-*-* 04:30:00 Europe/Zurich";
  };

  # BlueMap, on the same name players connect to. The Cloudflare record for
  # mc.qwt.ch must be "DNS only", Minecraft can't go through the proxy.
  # From home (the IP of the orchard.qwt.ch DDNS record) the map opens
  # directly, from anywhere else it asks for a login.
  # Add a login: `htpasswd -nB <name>` and append the line to
  # obstgarten/bluemap/htpasswd in secrets/secrets.yaml.
  sops.secrets."obstgarten/bluemap/htpasswd" = {
    owner = config.services.nginx.user;
    reloadUnits = [ "nginx.service" ];
  };

  services.nginx.virtualHosts."mc.qwt.ch" = {
    enableACME = true;
    forceSSL = true;
    basicAuthFile = config.sops.secrets."obstgarten/bluemap/htpasswd".path;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8100";
      recommendedProxySettings = true;
      # Glob, so nginx still starts while the file doesn't exist yet
      # (then everyone just gets the login)
      extraConfig = ''
        satisfy any;
        include ${homeIpDir}/*.conf;
        deny all;
      '';
    };
    # The Java resource pack: the game downloads it without a login
    locations."= ${javaPackPath}" = {
      alias = javaPack;
      extraConfig = "auth_basic off;";
    };
  };

  # Voice chat web page (SimpleVoice-Geyser). No basic auth: players log in
  # with a one-time code / QR link from the game (or name + voice password).
  # The plugin reads X-Real-IP (recommendedProxySettings) to rate-limit codes.
  # Cloudflare: voice.mc CNAME mc.qwt.ch, "DNS only" (audio goes straight here).
  services.nginx.virtualHosts."voice.mc.qwt.ch" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString svgPort}";
      proxyWebsockets = true; # the audio runs over a websocket
      recommendedProxySettings = true;
      # The server only sends while someone talks. With nginx's default 60s
      # it cut the websocket after a minute of silence (code 1006, the page
      # reconnected every minute).
      extraConfig = ''
        proxy_read_timeout 1h;
        proxy_send_timeout 1h;
      '';
    };
  };

  # nginx `allow` only takes addresses, so resolve the DDNS name regularly
  systemd.services.nginx-home-ip = {
    description = "Allow the home IP (orchard.qwt.ch) on mc.qwt.ch without login";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig.Type = "oneshot";
    path = with pkgs; [ getent gawk gnugrep coreutils systemd ];
    script = ''
      ip="$(getent ahostsv4 orchard.qwt.ch | awk 'NR == 1 { print $1 }')"
      if ! grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$' <<<"$ip"; then
        echo "could not resolve orchard.qwt.ch, keeping the previous address" >&2
        exit 0
      fi

      mkdir -p ${homeIpDir}
      new="allow $ip;"
      if [ "$(cat ${homeIpDir}/home.conf 2>/dev/null)" != "$new" ]; then
        echo "$new" > ${homeIpDir}/home.conf
        echo "home IP is now $ip"
        systemctl try-reload-or-restart nginx.service
      fi
    '';
  };
  systemd.timers.nginx-home-ip = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
    };
  };

  # Hourly local snapshots, for rolling back. restic only stores changed chunks
  # of the region files, so this grows slowly. Only two weeks are kept here:
  # every snapshot is copied to the TrueNAS each night and kept there for good
  # (backup.nix), which is also the material for timelapses.
  # Restore: sudo restic -r /persist/backups/minecraft \
  #   -p /persist/backups/minecraft-restic.password snapshots / restore
  services.restic.backups.minecraft = {
    repository = "${backupDir}/minecraft";
    passwordFile = backupPasswordFile;
    initialize = true;
    paths = [ dataDir ];
    exclude = [
      "${dataDir}/bluemap" # rendered map tiles, can be re-rendered
      "${dataDir}/cache"
      "${dataDir}/libraries"
      "${dataDir}/versions"
      "${dataDir}/logs"
      "${dataDir}/plugins/*.jar" # downloaded again on start
      "${dataDir}/plugins/Geyser-Spigot/extensions/*.jar"
      "${dataDir}/plugins/PlaceholderAPI/expansions/*.jar"
    ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
    # 48 hourly: a snapshot has to survive here until the nightly copy to the
    # TrueNAS has picked it up, this leaves room for two days without it.
    pruneOpts = [
      "--keep-hourly 48"
      "--keep-daily 14"
    ];
    # Flush the world to disk and pause saving while restic reads it
    backupPrepareCommand = ''
      #!${pkgs.runtimeShell}
      if [ ! -s ${backupPasswordFile} ]; then
        mkdir -p ${backupDir}
        (umask 077; ${pkgs.coreutils}/bin/head -c 32 /dev/urandom | ${pkgs.coreutils}/bin/base64 > ${backupPasswordFile})
      fi
      # A stopped (or restarting) server is backed up as it is on disk
      if ${sendCommand "save-off"}; then
        ${sendCommand "save-all flush"} || true
        ${pkgs.coreutils}/bin/sleep 20
      fi
    '';
    # If the server restarted in the meantime, it already saves again
    backupCleanupCommand = ''
      #!${pkgs.runtimeShell}
      ${sendCommand "save-on"} || true
    '';
  };
}
