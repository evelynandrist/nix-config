# MQTT broker, as on the TrueNAS: port 1883, websockets on 8081. Used by
# Home Assistant on packardserver and by the CO2 sensor, which has this
# host's address built in.
#
# The logins are the TrueNAS broker's password file, unchanged, as one sops
# secret (mosquitto/password_file): the user names stay out of this public
# repo and nobody needs a new password (mosquitto 2.1 reads the 2.0 hashes).
# Every login may use every topic.
#
# As on the TrueNAS (seen 2026-11-24): the app's own config include is the
# one line `password_file`, with no `allow_anonymous` (so no anonymous
# logins, the default of mosquitto 2) and no `acl_file`. The file is
# /mnt/Thalamus/Apps/eclipse-mosquitto/config/passwords there.
#
# At the cutover (not tried): the retained messages are in mosquitto.db in
# the app's data folder; copying it is optional (the sensor sends again):
#   sudo systemctl stop mosquitto
#   sudo cp /mnt/Thalamus/Apps/eclipse-mosquitto/data/mosquitto.db /var/lib/mosquitto/
#   sudo chown mosquitto:mosquitto /var/lib/mosquitto/mosquitto.db
#   sudo systemctl start mosquitto
{ config, lib, pkgs, ... }:
let
  listener = extra: {
    # the module's own password plugin wants every user declared here
    omitPasswordAuth = true;
    authPlugins = [{
      plugin = "${lib.getLib config.services.mosquitto.package}/lib/mosquitto_password_file.so";
      options.password_file = config.sops.secrets."mosquitto/password_file".path;
    }];
    acl = [ "pattern readwrite #" ];
  } // extra;
in {
  sops.secrets."mosquitto/password_file" = {
    owner = "mosquitto";
    restartUnits = [ "mosquitto.service" ];
  };

  services.mosquitto = {
    enable = true;
    listeners = [
      (listener { port = 1883; })
      (listener {
        port = 8081;
        settings.protocol = "websockets";
      })
    ];
  };

  # With owner and mode: impermanence creates a missing directory in
  # /persist as root:root 0755, and the module does not fix that, so
  # mosquitto could not write there after the install (2026-11-24).
  # Applies only when the directory is created.
  environment.persistence."/persist".directories = [{
    directory = "/var/lib/mosquitto";
    user = "mosquitto";
    group = "mosquitto";
    mode = "0700";
  }];

  networking.firewall.allowedTCPPorts = [ 1883 8081 ];
}
