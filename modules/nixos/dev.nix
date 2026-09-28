# Backend services for local development.
{ config, lib, pkgs, ... }:

let
  cfg = config.haywan.dev;
in
{
  options.haywan.dev = {
    docker.enable = lib.mkEnableOption "Docker";
    postgresql.enable = lib.mkEnableOption "PostgreSQL 15";
    redis.enable = lib.mkEnableOption "Redis";
    mongodb.enable = lib.mkEnableOption "MongoDB (compiles from source — slow!)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.docker.enable {
      virtualisation.docker = {
        enable = true;
        daemon.settings = {
          dns = [ "1.1.1.1" "8.8.8.8" ];
          log-driver = "journald";
          registry-mirrors = [ "https://mirror.gcr.io" ];
          storage-driver = "overlay2";
        };
      };
      haywan.user.extraGroups = [ "docker" ];
    })

    (lib.mkIf cfg.postgresql.enable {
      services.postgresql = {
        enable = true;
        package = pkgs.postgresql_15;
      };
    })

    (lib.mkIf cfg.redis.enable {
      services.redis = {
        package = pkgs.redis;
        servers."".enable = true;
      };
    })

    {
      services.mongodb = {
        enable = cfg.mongodb.enable;
        package = pkgs.mongodb-ce;
      };
    }
  ];
}
