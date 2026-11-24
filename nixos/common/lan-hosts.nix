# Names of the machines on the home LAN.
#
# Not imported by default: only hosts that live on the LAN import this file
# (nixserver is outside and uses public names only).
#
# The same names exist as public Cloudflare records (<name>.internal.qwt.ch,
# pointing at these private addresses). They are repeated in /etc/hosts so
# the servers find each other without Cloudflare or the internet, and nginx
# and the mounts come up after a power cut.
#
# Naming rule: x.qwt.ch is public, x.internal.qwt.ch is LAN and VPN only.
{ lib, ... }:
let
  domain = "internal.qwt.ch";
  machines = {
    cranium = "192.168.1.56";
    dellserver = "192.168.1.57";
    anycubic = "192.168.1.120";
    nixbook = "192.168.1.131";
    packardserver = "192.168.1.170";
  };
  # Old names that still point at a machine. The NAS ran TrueNAS under the
  # name truenas, which things outside this repo may still use.
  aliases = {
    cranium = [ "truenas" ];
  };
in {
  networking.hosts = lib.mapAttrs' (name: address:
    lib.nameValuePair address (lib.concatMap (n: [ "${n}.${domain}" n ])
      ([ name ] ++ aliases.${name} or [ ]))
  ) machines;

  # short names for everything else under the domain (sonarr, radarr, ...)
  networking.search = [ domain ];
}
