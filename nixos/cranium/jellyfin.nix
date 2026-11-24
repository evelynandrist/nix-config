# Jellyfin: jellyfin.qwt.ch, through nginx on packardserver (port 30013, as
# on the TrueNAS). Transcodes on the GPU with NVENC (configuration.nix).
#
# Its state is in /var/lib/jellyfin on the NVMe. The media are on the pool,
# shown to Jellyfin at /Media, the path it knew them by in the container, so
# the libraries, and with them what was watched, stay as they are. It reads
# them through the group media (pool-access.nix). Sonarr and Radarr on
# packardserver write there through the Samba share (samba.nix).
#
# The port and the hardware acceleration are Jellyfin's own settings
# (network.xml, encoding.xml), so they come with the copied config.
#
# Jellyfin never starts without its state: an empty one shows the setup
# wizard, which is public through jellyfin.qwt.ch. It starts once the file
# `restored` (below) exists.
#
# At the cutover (not tried): with the TrueNAS app stopped, copy its state.
# The official image keeps data, config (config/) and logs (log/) in one
# folder, the same layout as here:
#   sudo rsync -a --delete /mnt/Thalamus/Apps/jellyfin/ /var/lib/jellyfin/
#   sudo chown -R jellyfin:jellyfin /var/lib/jellyfin
# Then check:
#   - config/network.xml: the HTTP port is 30013. In the container it may
#     have been 8096 behind a port mapping.
#   - config/encoding.xml: hardware acceleration nvenc; the transcode path
#     (TranscodingTempPath) is a path of the container (/cache/...) or
#     empty: make it empty, then Jellyfin uses its own cache folder.
# and start it:
#   sudo touch /var/lib/jellyfin/restored; sudo systemctl start jellyfin
# The TrueNAS's cache folder (Thalamus/Cache) is not copied: it fills again.
{ config, lib, pkgs, ... }:
let
  media = "/mnt/Neocortex/Media";
  restored = "${config.services.jellyfin.dataDir}/restored";
in {
  services.jellyfin.enable = true;

  systemd.services.jellyfin = {
    unitConfig = {
      RequiresMountsFor = [ media ];
      ConditionPathExists = restored;
    };
    serviceConfig.BindPaths = [ "${media}:/Media" ];
  };

  environment.persistence."/persist".directories = [ "/var/lib/jellyfin" ];

  networking.firewall.allowedTCPPorts = [ 30013 ];
}
