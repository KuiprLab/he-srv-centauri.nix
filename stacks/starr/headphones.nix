# Auto-generated using compose2nix v0.3.2-pre.
{
  pkgs,
  lib,
  config,
  ...
}: {
  sops.secrets."headphones.env" = {
    sopsFile = ./headphones.env;
    format = "dotenv";
    key = "";
    restartUnits = ["podman-headphones.service"];
  };

  myFolders = {
    headphones = {
      path = "/home/ubuntu/headphones";
      owner = "ubuntu";
      group = "users";
      mode = "0755";
    };
  };

  virtualisation.oci-containers.containers."headphones" = {
    image = "factualgoldfish/headphones:latest";
    volumes = [
      "/home/ubuntu/headphones:/config:rw"
      "/mnt/data/media/music:/music:rw"
      "/mnt/data/downloads:/downloads:rw"
    ];
    user = "0:0";
    labels = {
      "traefik.docker.network" = "proxy";
      "traefik.enable" = "true";
      "traefik.http.routers.headphones.entrypoints" = "websecure";
      "traefik.http.routers.headphones.middlewares" = "authelia@docker";
      "traefik.http.routers.headphones.rule" = "Host(`headphones.kuipr.de`)";
      "traefik.http.routers.headphones.tls.certresolver" = "myresolver";
      "traefik.http.services.headphones.loadbalancer.server.port" = "8181";
      "traefik.port" = "8181";
    };
    environmentFiles = [
      "/run/secrets/headphones.env"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=headphones"
      "--network=proxy"
      "--network=starr_default"
    ];
  };
  systemd.services."podman-headphones" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-starr_default.service"
    ];
    requires = [
      "podman-network-starr_default.service"
    ];
    partOf = [
      "podman-compose-starr-root.target"
    ];
    wantedBy = [
      "podman-compose-starr-root.target"
    ];
  };
}
