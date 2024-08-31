{ config, lib, pkgs, ... }: {
  config.sops.secrets = {
    "umami/app_secret" = { };
  };

  config.sops.templates."umami.env" = {
    content = ''
      DATABASE_URL=postgresql://umami:umami@10.88.0.1:5000/umami
      DATABASE_TYPE=postgresql
      APP_SECRET=${config.sops.placeholder."umami/app_secret"}
      TRACKER_SCRIPT_NAME=donotpanic
    '';
    owner = "nix";
  };

  config.virtualisation.oci-containers.containers.umami = {
    image = "ghcr.io/umami-software/umami:postgresql-latest";
    environmentFiles = [ config.sops.templates."umami.env".path ];
    ports = [ "127.0.0.1:8003:3000" ];
    dependsOn = [ "umami-db" ];
  };
  config.virtualisation.oci-containers.containers.umami-db = {
    image = "docker.io/library/postgres:15-alpine";
    environment = {
      POSTGRES_DB = "umami";
      POSTGRES_USER = "umami";
      POSTGRES_PASSWORD = "umami";
    };
    hostname = "umami-db";
    ports = [ "10.88.0.1:5000:5432" ];
    volumes = [
      "/persist/data/umami:/var/lib/postgresql/data"
    ];
  };
}
