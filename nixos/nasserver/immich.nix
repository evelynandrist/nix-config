# Immich: photos.qwt.ch, through nginx on packardserver (port 30041, as on
# the TrueNAS).
#
# The library is Immich's whole media location on the pool, as on the
# TrueNAS: originals, thumbnails, encoded videos, and Immich's own nightly
# database dumps (backups/). The database (PostgreSQL 18 with VectorChord,
# the versions the TrueNAS app ran) is on the NVMe.
#
# The user immich has uid and gid 568, the TrueNAS's `apps`: Immich ran as
# that there, so the library is already its own and never needs a chown.
#
# The GPU (configuration.nix): video transcoding with NVENC is Immich's own
# setting, kept in its database. Machine learning runs on the CPU. On the
# GPU it would need onnxruntime built with CUDA and cuDNN 9, and every
# cuDNN 9 in nixpkgs (9.12 and later) requires compute capability 7.5; the
# GTX 1060 has 6.1. Packaging an older cuDNN would also mean hours of
# compiling onnxruntime here and on dellserver after every flake bump.
#
# Immich never starts on an empty database: the library is already there,
# and an empty Immich would offer the first visitor of photos.qwt.ch to
# create the admin account, and its nightly dumps would push the real ones
# out of backups/. It starts once the file `restored` (below) exists.
#
# At the cutover (none of this was tried):
#   1. On the TrueNAS, with Immich running, dump its database. The user and
#      database name are in the app's settings (DB_USERNAME, often postgres):
#        sudo docker exec <postgres container> pg_dump -U <user> -Fc \
#          --no-owner --no-privileges <database> > /mnt/Thalamus/Apps/immich.dump
#      Then stop the app and shut down.
#   2. On NixOS, the module has created an empty database `immich` with its
#      extensions. Restore into it as the role immich (only root can read
#      /mnt/Thalamus, hence the cat), then let Immich start:
#        sudo cat /mnt/Thalamus/Apps/immich.dump \
#          | sudo -u postgres pg_restore --no-owner --role=immich -d immich
#        sudo touch /var/lib/postgresql/immich-restored
#        sudo systemctl start immich-server
#   3. The container saw the library under another path (/data or
#      /usr/src/app/upload). Immich notices the changed media location and
#      rewrites the paths in its database: the journal says "Media location
#      changed". Check that it did, and that thumbnails load.
#   4. In Administration, check: video transcoding uses NVENC, as before;
#      the machine learning URL is http://localhost:3003 (the database
#      still has the container's, which wins over the module's default).
{ config, lib, pkgs, ... }:
let
  library = "/mnt/Neocortex/Photos";
  restored = "/var/lib/postgresql/immich-restored";
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
  };

  users.users.immich = {
    uid = 568;
    extraGroups = [ "pools" ];
  };
  users.groups.immich.gid = 568;

  # PostgreSQL 18, as on the TrueNAS: the default here would be the one of
  # the stateVersion (23.11), far older.
  services.postgresql.package = pkgs.postgresql_18;

  systemd.services.immich-server.unitConfig = {
    RequiresMountsFor = [ library ];
    ConditionPathExists = restored;
  };

  environment.persistence."/persist".directories = [ "/var/lib/postgresql" ];
}
