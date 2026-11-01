# Daily briefing on the Home Assistant dashboard.
#
#   obsidian-sync.service   ob (headless Obsidian Sync), pull-only, keeps the
#                           vault in ${vaultDir}
#   briefing@<kind>.timer   runs `briefing <kind>`: HA calendars + journal +
#                           mail -> ollama -> ${stateDir}/<kind>.json
#   sensor.briefing_<kind>  command_line sensor reading that file, shown with a
#                           markdown card (text is in the `text` attribute)
#   briefing@commute.timer  no model: when to leave from each HA zone for the
#                           next appointments with a place (transport.opendata.ch)
#
# One-time setup after the first switch (the Obsidian login is interactive):
#   sudo ob-vault login
#   sudo ob-vault sync-setup --vault "<vault name>" --path ${vaultDir} --device-name packardserver
#   sudo ob-vault sync-config --path ${vaultDir} --mode pull-only
#   sudo systemctl start obsidian-sync
#
# A new kind (weekly, ...) is an entry in `kinds` plus one in `schedules`.
# A new source is a collector in pkgs/briefing/briefing.py, enabled per kind
# under `sources`.
{ config, lib, pkgs, ... }:
let
  obsidianHome = "/persist/data/obsidian";
  vaultDir = "/persist/data/obsidian-vault";
  stateDir = "/persist/data/briefing";

  obEnv = "HOME=${obsidianHome} XDG_CONFIG_HOME=${obsidianHome}/config";

  schedules = {
    daily = "*-*-* 05:30:00";
    # cheap, and cached: connections are refetched hourly, every 10 min in
    # the last 3 hours before an appointment
    commute = "*:0/10";
  };

  briefingConfig = pkgs.writeText "briefing.json" (builtins.toJSON {
    vault = vaultDir;
    state_dir = stateDir;
    home_assistant.url = "http://127.0.0.1:8123";
    imap = {
      host = "mail.andrist.dev";
      user = "evelyn@andrist.dev";
    };
    ollama = {
      url = "http://192.168.1.131:11434";
      model = "qwen3.5:9b";
      # same as the HA ollama integration (context window option in its UI)
      # and keep_alive -1 like HA, so the two don't make ollama reload the model
      num_ctx = 8192;
      keep_alive = -1;
    };
    system_prompt = ''
      You write Evelyn's private morning briefing, addressed as "you", in
      English markdown. Use only the source material; never invent anything.
    '';
    kinds.daily = {
      sources = {
        calendar = {
          days = 2; # today + tomorrow
          include = [ "Rimon" "Personal" ];
          # routine meetings, not worth a mention
          ignore = [ "^daily\\b" "^standup\\b" "^regression test\\b" ];
        };
        journal = {
          entries = 2;
          lookback_days = 4;
          weekly_heading = "What am I looking forward to next week?";
        };
        mail.hours = 24;
      };
      prompt = ''
        Like a friend who has read all of this, in a few short paragraphs:
        what matters today and tomorrow, and what should I do about it? The
        agenda is shown below your text, so don't list it.
      '';
    };
    commute = {
      include = [ "Rimon" "Personal" ];
      # starting points are the HA zones (Settings -> Areas & zones); the
      # one your phone is in is highlighted
      arrive_early = 10;
      horizon_hours = 36;
      max_appointments = 3;
    };
  });

  ob-vault = pkgs.writeShellScriptBin "ob-vault" ''
    exec ${pkgs.util-linux}/bin/runuser -u obsidian -- \
      env ${obEnv} ${lib.getExe pkgs.obsidian-headless} "$@"
  '';
in {
  users.users.obsidian = {
    isSystemUser = true;
    group = "obsidian";
    home = obsidianHome;
  };
  users.groups.obsidian = { };

  users.users.briefing = {
    isSystemUser = true;
    group = "briefing";
    # read the vault
    extraGroups = [ "obsidian" ];
  };
  users.groups.briefing = { };

  # home (with ob's auth token) stays private; the vault is readable by the
  # obsidian group, the briefings by hass
  systemd.tmpfiles.rules = [
    "d '${obsidianHome}' 0700 obsidian obsidian - -"
    "d '${vaultDir}'     2750 obsidian obsidian - -"
    "d '${stateDir}'     2750 briefing hass - -"
  ];

  environment.systemPackages = [ ob-vault ];

  systemd.services.obsidian-sync = {
    description = "Obsidian Sync (headless, pull-only)";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    # not set up yet, see the top of this file
    unitConfig.ConditionPathExists = "${obsidianHome}/config/obsidian-headless/auth_token";
    environment = {
      HOME = obsidianHome;
      XDG_CONFIG_HOME = "${obsidianHome}/config";
    };
    serviceConfig = {
      User = "obsidian";
      Group = "obsidian";
      ExecStart = "${lib.getExe pkgs.obsidian-headless} sync --continuous --path ${vaultDir}";
      UMask = "0027";
      Restart = "always";
      RestartSec = 30;
      ProtectSystem = "strict";
      ReadWritePaths = [ obsidianHome vaultDir ];
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  sops.secrets."briefing/ha_token" = { };

  systemd.services."briefing@" = {
    description = "Generate the %i briefing";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "home-assistant.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "briefing";
      Group = "briefing";
      ExecStart = "${lib.getExe pkgs.briefing} --config ${briefingConfig} %i";
      LoadCredential = [
        "ha_token:${config.sops.secrets."briefing/ha_token".path}"
        "imap_password:${config.sops.secrets."email/logins/evelyn".path}"
      ];
      UMask = "0027";
      ProtectSystem = "strict";
      ReadWritePaths = [ stateDir ];
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  systemd.timers = lib.mapAttrs' (kind: onCalendar:
    lib.nameValuePair "briefing@${kind}" {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = onCalendar;
        Persistent = true;
      };
    }) schedules;

  services.home-assistant.config = {
    command_line = lib.mapAttrsToList (kind: _: {
      sensor = {
        name = "Briefing ${kind}";
        unique_id = "briefing_${kind}";
        command = "${pkgs.coreutils}/bin/cat ${stateDir}/${kind}.json";
        # briefings: when generated; commute: when to leave
        value_template = "{{ value_json.state }}";
        device_class = "timestamp";
        json_attributes = [ "text" "errors" ];
        scan_interval = 120;
      };
    }) schedules;
    # the text attribute is too large and pointless for the history database
    recorder.exclude.entity_globs = [ "sensor.briefing_*" ];
  };
}
