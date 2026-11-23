# MQTT broker, as on the TrueNAS: port 1883, websockets on 8081. Used by
# Home Assistant on packardserver and by the CO2 sensor, which has this
# host's address built in.
#
# The logins are declared here; the password hashes are sops secrets, one
# per user, copied from the TrueNAS's password file (each line is
# `user:hash`; the secret is the hash alone). mosquitto 2.1 reads the 2.0
# hashes, so nobody needs a new password.
#
# PLACEHOLDER: the user names. Use the ones in the TrueNAS's password file
# (/mnt/Thalamus/Apps/eclipse-mosquitto/config/), and the ACL if that config
# had one (everyone may use every topic here).
#
# At the cutover (not tried): the retained messages are in mosquitto.db in
# the app's data folder; copying it is optional (the sensor sends again):
#   sudo cp /mnt/Thalamus/Apps/eclipse-mosquitto/data/mosquitto.db /var/lib/mosquitto/
#   sudo chown mosquitto:mosquitto /var/lib/mosquitto/mosquitto.db
{ config, lib, ... }:
let
  userNames = [ "homeassistant" "co2sensor" ];
  secret = name: "mosquitto/${name}_hash";
  users = lib.genAttrs userNames (name: {
    hashedPasswordFile = config.sops.secrets.${secret name}.path;
    acl = [ "readwrite #" ];
  });
in {
  sops.secrets = lib.genAttrs (map secret userNames) (_: { });

  services.mosquitto = {
    enable = true;
    listeners = [
      { port = 1883; inherit users; }
      {
        port = 8081;
        settings.protocol = "websockets";
        inherit users;
      }
    ];
  };

  environment.persistence."/persist".directories = [ "/var/lib/mosquitto" ];

  networking.firewall.allowedTCPPorts = [ 1883 8081 ];
}
