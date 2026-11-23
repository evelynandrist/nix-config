# MQTT broker, as on the TrueNAS: port 1883, websockets on 8081. Used by
# Home Assistant on packardserver and by the CO2 sensor, which has this
# host's address built in.
#
# The logins are the TrueNAS broker's password file, unchanged, as one sops
# secret (mosquitto/password_file): the user names stay out of this public
# repo and nobody needs a new password (mosquitto 2.1 reads the 2.0 hashes).
# Every login may use every topic.
#
# Assumes the TrueNAS broker had password logins and no ACL. Its
# mosquitto.conf (/mnt/Thalamus/Apps/eclipse-mosquitto/config/) says: with
# `allow_anonymous true`, the sensor may log in without a password and this
# would lock it out; with an `acl_file`, that has to come over too.
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

  environment.persistence."/persist".directories = [ "/var/lib/mosquitto" ];

  networking.firewall.allowedTCPPorts = [ 1883 8081 ];
}
