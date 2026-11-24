# The VPN: wg-easy, the one container, on the TrueNAS's data, so no VPN
# client changes at the cutover. Plain WireGuard and where the VPN lives
# are a later question.
#
# Host network, as on the TrueNAS: clients reach the LAN with this host's
# address (wg-easy's own NAT rule), which ../common/hardening.nix relies on.
# The web UI is on 30058 over plain http (INSECURE), LAN only through the
# router.
#
# It updates itself within its major version: the tag `15` always points
# at the newest 15.x (15.5.0, the TrueNAS's, on 2026-11-24), and podman's
# auto-update looks for a newer image every night (podman-auto-update.timer,
# around midnight), pulls it and restarts the container, and goes back to
# the old image if it does not come up. Version 16 is a change by hand,
# after reading the release notes.
#   journalctl -u podman-auto-update;  sudo podman auto-update --dry-run
#
# It never starts without its data: an empty wg-easy would make new server
# keys, and every client would need a new configuration. It starts once
# the file `restored` (below) exists.
#
# At the cutover (not tried), best done at the machine, not over the VPN:
#   sudo rsync -a --delete /mnt/Thalamus/Apps/wg_easy/ /persist/data/wg-easy/
#   sudo touch /persist/data/wg-easy/restored
#   sudo systemctl start podman-wg-easy
# Then check in wg-easy's settings (web UI) that:
#   - the network interface of the NAT rule (eth0 by default) is this
#     host's, enp60s0 (as on the TrueNAS);
#   - the WireGuard port is the one here, and the one the router forwards.
# Its env settings on the TrueNAS (`sudo docker inspect` of the container)
# should match the environment below.
{ config, lib, pkgs, ... }:
let
  wgPort = 51820;
  uiPort = 30058;
  data = "/persist/data/wg-easy";
in {
  virtualisation.oci-containers.containers.wg-easy = {
    image = "ghcr.io/wg-easy/wg-easy:15";
    labels."io.containers.autoupdate" = "registry";
    volumes = [ "${data}:/etc/wireguard" ];
    environment = {
      PORT = toString uiPort;
      INSECURE = "true";
    };
    extraOptions = [
      "--network=host"
      "--cap-add=NET_ADMIN"
      # needed under podman (wg-easy's docs)
      "--cap-add=NET_RAW"
    ];
  };

  systemd.services.podman-wg-easy.unitConfig.ConditionPathExists = "${data}/restored";

  # podman ships the timer, nothing turns it on
  systemd.timers.podman-auto-update.wantedBy = [ "timers.target" ];

  # With the host network the container cannot set these itself. The host
  # also loads the module, so the container needs no SYS_MODULE.
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.src_valid_mark" = 1;
  };
  boot.kernelModules = [ "wireguard" ];

  systemd.tmpfiles.rules = [ "d ${data} 0700 root root -" ];

  networking.firewall = {
    allowedUDPPorts = [ wgPort ];
    allowedTCPPorts = [ uiPort ];
  };
}
