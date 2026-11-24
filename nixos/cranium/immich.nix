# Immich: photos.qwt.ch, through nginx on packardserver (port 30041, as on
# the TrueNAS).
#
# The library is Immich's whole media location on the pool, as on the
# TrueNAS: originals, thumbnails, encoded videos, and Immich's own nightly
# database dumps (backups/). It belongs to uid 568, which Immich runs as here
# too (pool-access.nix). The database (PostgreSQL 18 with VectorChord 1.1.1,
# the versions the TrueNAS app ran) is on the NVMe.
#
# The GPU (configuration.nix): video transcoding with NVENC is Immich's own
# setting, kept in its database. Machine learning runs on the GPU in
# Immich's own `-cuda` container, the one the TrueNAS ran: nixpkgs has no
# cuDNN for the GTX 1060 (every cuDNN 9 there requires compute capability
# 7.5, the 1060 has 6.1). The container's tag is the version of the Immich
# nixpkgs installs, so the two update together with the flake and never
# drift. The module's own machine learning is off: both want port 3003.
# The container is on the host network and listens on 127.0.0.1 only.
# If its CUDA does not work on the card, it falls back to the CPU, slowly
# and without failing: `nvidia-smi` on the host lists its process while it
# works (the cutover notes have the check).
#
# Immich never starts on an empty database: the library is already there,
# and an empty Immich would offer the first visitor of photos.qwt.ch to
# create the admin account, and its nightly dumps would push the real ones
# out of backups/. It starts once the file `restored` (below) exists.
#
# At the cutover (not tried):
#   1. On the TrueNAS: stop the Immich server container first, so no upload
#      comes in after the dump (`sudo docker ps` for the names), then dump
#      the database from the postgres container, still running. The user and
#      database name are in the app's settings (DB_USERNAME, often postgres):
#        sudo docker stop <server container>
#        sudo sh -c 'docker exec <postgres container> pg_dump -U <user> -Fc \
#          --no-owner --no-privileges <database> > /mnt/Thalamus/Apps/immich.dump'
#      Then stop the app and shut down.
#   2. On NixOS, the module has created an empty database `immich` with its
#      extensions. Restore into it as the role immich (only root can read
#      /mnt/Thalamus, hence the cat), then let Immich start:
#        sudo cat /mnt/Thalamus/Apps/immich.dump \
#          | sudo -u postgres pg_restore --no-owner --role=immich -d immich
#        sudo touch /var/lib/postgresql/immich-restored
#        sudo systemctl start immich-server
#      pg_restore may complain that the extensions already exist; that is
#      harmless. Any other error is not.
#   3. The container saw the library under another path (/data or
#      /usr/src/app/upload). Immich notices the changed media location and
#      rewrites the paths in its database: the journal says "Media location
#      changed". Check that it did, and that thumbnails load.
#   4. In Administration, check: video transcoding uses NVENC, as before;
#      the machine learning URL is http://127.0.0.1:3003 (the database
#      still has the TrueNAS container's, which wins over the one set here).
{ config, lib, pkgs, ... }:
let
  library = "/mnt/Neocortex/Photos";
  restored = "/var/lib/postgresql/immich-restored";
  mlPort = 3003;
  mlCache = "/var/cache/immich";
in {
  services.immich = {
    enable = true;
    host = "0.0.0.0";
    port = 30041;
    openFirewall = true;
    mediaLocation = library;
    # NVENC. The nvidia device files only exist once the driver has
    # loaded, so all devices.
    accelerationDevices = null;
    machine-learning.enable = false;
    # 127.0.0.1, not the module's localhost, which may resolve to ::1
    environment.IMMICH_MACHINE_LEARNING_URL = lib.mkForce "http://127.0.0.1:${toString mlPort}";
  };

  # PostgreSQL 18, as on the TrueNAS: the default here would be the one of
  # the stateVersion (23.11), far older.
  services.postgresql.package = pkgs.postgresql_18;

  systemd.services.immich-server.unitConfig = {
    RequiresMountsFor = [ library ];
    ConditionPathExists = restored;
  };

  virtualisation.oci-containers.containers.immich-machine-learning = {
    image = "ghcr.io/immich-app/immich-machine-learning:v${config.services.immich.package.version}-cuda";
    environment = {
      IMMICH_HOST = "127.0.0.1";
      IMMICH_PORT = toString mlPort;
    };
    # the models, otherwise downloaded again at every boot
    volumes = [ "${mlCache}:/cache" ];
    devices = [ "nvidia.com/gpu=all" ];
    networks = [ "host" ];
  };

  # The GPU in the container: the toolkit describes the driver's devices and
  # libraries (CDI) at boot, and the container needs that description.
  hardware.nvidia-container-toolkit.enable = true;
  systemd.services.podman-immich-machine-learning = {
    requires = [ "nvidia-container-toolkit-cdi-generator.service" ];
    after = [ "nvidia-container-toolkit-cdi-generator.service" ];
  };

  # Every Immich release leaves the old image behind, several GB each. Weekly,
  # remove the images no container uses (a stopped one's is pulled again).
  virtualisation.podman.autoPrune = {
    enable = true;
    flags = [ "--all" ];
  };

  environment.persistence."/persist".directories = [
    "/var/lib/postgresql"
    mlCache
    # podman's images, so the VPN comes up after a reboot without the
    # internet (wg-easy.nix)
    "/var/lib/containers"
  ];
}
