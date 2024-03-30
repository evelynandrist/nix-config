{ config, pkgs, ... }:
{
  sops.secrets = {
    "umami/app_secret" = { };
  };

  sops.templates."umami.env" = {
    content = ''
      DATABASE_URL=postgresql://umami:umami@127.0.0.1:5000/umami
      DATABASE_TYPE=postgresql
      APP_SECRET=${config.sops.placeholder."umami/app_secret"}
      TRACKER_SCRIPT_NAME=donotpanic
    '';
  };

  config.virtualisation.oci-containers.containers.umami = {
    image = "ghcr.io/umami-software/umami:postgresql-latest";
    environmentFiles = [ config.sops.templates."umami.env".path ];
    ports = [ "127.0.0.1:8003:3000" ];
    dependsOn = "umami-db";
  };
  config.virtualisation.oci-containers.containers.umami-db = {
    image = "postgres:15-alpine";
    environment = {
      POSTGRES_DB = "umami";
      POSTGRES_USER = "umami";
      POSTGRES_PASSWORD = "umami";
    };
    ports = [ "127.0.0.1:5000:5432" ];
    volumes = [
      "/perist/data/umami:/var/lib/postgresql/data"
    ];
  };
}
