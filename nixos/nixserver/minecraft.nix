{ config, lib, pkgs, ... }:
# Family survival server: Paper + Geyser/Floodgate, so Xbox, Switch and PC can
# play together. Bedrock consoles join through the friends tab of the
# ObstgartenGang Xbox account (MCXboxBroadcast).
#
# Console:  tmux -S /run/minecraft/obstgarten.sock attach   (detach: Ctrl-b d)
#           (the socket is mode 660 minecraft:minecraft; the main user is in that group)
# Map:      https://mc.qwt.ch
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
      fetch "$ext/EmoteOffhand.jar"     "$geyser/emoteoffhand/versions/latest/builds/latest/downloads/emoteoffhand"

      # Bound to the Minecraft version
      fetch plugins/LuckPerms.jar   "$(modrinth luckperms "$mcVersion")"
      fetch plugins/BlueMap.jar     "$(modrinth bluemap "$mcVersion")"
      fetch plugins/CoreProtect.jar "$(modrinth coreprotect "$mcVersion")"
      fetch plugins/Chunky.jar      "$(modrinth chunky "$mcVersion")"
      # items go into a grave at the death spot (keepInventory stays off)
      fetch plugins/GravesX.jar     "$(modrinth gravesx "$mcVersion")"

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

  # Single settings in config files the plugins generate themselves on their
  # first start. Takes effect from the second start on.
  patchConfigs = pkgs.writeShellApplication {
    name = "minecraft-${name}-patch-configs";
    runtimeInputs = with pkgs; [ gnused ];
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

      # keep pregenerating after the nightly restart
      set_key plugins/Chunky/config.yml continue-on-restart true

      # Fog of war: chunks only show up on the map once a player has been
      # nearby (pregenerated chunks have an inhabited time of 0). 20 ticks = 1s
      for map in plugins/BlueMap/maps/*.conf; do
        set_key "$map" min-inhabited-time 20
      done
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
      max-players = 10;
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
    };

    operators.eeeeeeeevelyn = {
      uuid = "ac788709-ece6-43f0-b8ff-403c942453c5";
      level = 4;
    };

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
  networking.firewall.allowedUDPPorts = [ 19132 ];
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

  # Hourly local snapshots. restic only stores changed chunks of the region
  # files, so this grows slowly. Add a second repository on the TrueNAS later.
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
    ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
    pruneOpts = [
      "--keep-hourly 24"
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
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
