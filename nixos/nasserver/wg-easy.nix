# The VPN: wg-easy, the one container, on the TrueNAS's data, so no VPN
# client changes at the cutover. Plain WireGuard and where the VPN lives
# are a later question.
#
# Host network, as on the TrueNAS: clients reach the LAN with this host's
# address (wg-easy's own NAT rule), which ../common/hardening.nix relies on.
# The web UI is on 30058 over plain http (INSECURE), LAN only through the
# router.
#
# The image is pinned to the version the TrueNAS ran. The weekly flake bump
# does not update it: change the tag by hand, after reading wg-easy's
# release notes.
#
# At the cutover (not tried):
#   sudo rsync -a /mnt/Thalamus/Apps/wg_easy/ /persist/data/wg-easy/
# Then check in wg-easy's settings (web UI) that:
#   - the network interface of the NAT rule (eth0 by default) is this
#     host's: `ip -br link`;
#   - the WireGuard port is the one here, and the one the router forwards.
# Its env settings on the TrueNAS (`sudo docker inspect` of the container)
# should match the environment below.
{ config, lib, pkgs, ... }:
let
  wgPort = 51820;
  uiPort = 30058;
in {
  virtualisation.oci-containers.containers.wg-easy = {
    image = "ghcr.io/wg-easy/wg-easy:15.5.0";
    volumes = [ "/persist/data/wg-easy:/etc/wireguard" ];
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

  # With the host network the container cannot set these itself. The host
  # also loads the module, so the container needs no SYS_MODULE.
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.src_valid_mark" = 1;
  };
  boot.kernelModules = [ "wireguard" ];

  systemd.tmpfiles.rules = [ "d /persist/data/wg-easy 0700 root root -" ];

  # podman's images, so the VPN comes up after a reboot without the internet
  environment.persistence."/persist".directories = [ "/var/lib/containers" ];

  networking.firewall = {
    allowedUDPPorts = [ wgPort ];
    allowedTCPPorts = [ uiPort ];
  };
}
