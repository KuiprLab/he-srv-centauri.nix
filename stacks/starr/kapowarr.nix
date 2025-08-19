# Auto-generated using compose2nix v0.3.2-pre.
{
  pkgs,
  lib,
  config,
  ...
}: {
  myFolders = {
    kapowarr = {
      path = "/home/ubuntu/kapowarr";
      owner = "ubuntu";
      group = "users";
      mode = "0755";
    };
  };
  # Enable container name DNS for all Podman networks.
  networking.firewall.interfaces = let
    matchAll =
      if !config.networking.nftables.enable
      then "podman+"
      else "podman*";
  in {
    "${matchAll}".allowedUDPPorts = [53];
  };
  virtualisation.oci-containers.backend = "podman";
  virtualisation.oci-containers.containers."flaresolverr-gluetun" = {
    image = "ghcr.io/flaresolverr/flaresolverr:latest";
    # ports = [
    #   "8191:8191/tcp"
    # ];
    log-driver = "journald";
    extraOptions = [
      "--network=container:gluetun"
    ];
  };
  systemd.services."podman-flaresolverr-gluetun" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-seedbox_default.service"
      "podman-gluetun.service"
    ];
    requires = [
      "podman-network-seedbox_default.service"
      "podman-gluetun.service"
    ];
    partOf = [
      "podman-compose-seedbox-root.target"
    ];
    wantedBy = [
      "podman-compose-seedbox-root.target"
    ];
  };
  # Containers
  virtualisation.oci-containers.containers."kapowarr" = {
    image = "github.io/mrcas/kapowarr-alpha:latest";
    volumes = [
      "/home/ubuntu/kapowarr:/app/db:rw"
      "/mnt/data/downloads:/app/temp_downloads:rw"
      "/mnt/data/media/comics:/comics-1:rw"
    ];
    dependsOn = [
      "gluetun"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network=container:gluetun"
    ];
    # Add Traefik labels here for kapowarr
    labels = {
      "io.containers.autoupdate" = "registry";
      "traefik.enable" = "true";
      "traefik.http.routers.kapowarr.entrypoints" = "websecure";
      "traefik.http.routers.kapowarr.middlewares" = "authelia@docker";
      "traefik.http.routers.kapowarr.rule" = "Host(`kapowarr.kuipr.de`)";
      "traefik.http.routers.kapowarr.service" = "kapowarr";
      "traefik.http.routers.kapowarr.tls.certresolver" = "myresolver";
      "traefik.http.services.kapowarr.loadbalancer.server.port" = "5656";
    };
  };
  systemd.services."podman-kapowarr" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always"; # Changed from "no" to "always" for better reliability
    };
    after = [
      "podman-network-seedbox_default.service"
      "podman-gluetun.service"
    ];
    requires = [
      "podman-network-seedbox_default.service"
      "podman-gluetun.service"
    ];
    partOf = [
      "podman-compose-seedbox-root.target"
    ];
    wantedBy = [
      "podman-compose-seedbox-root.target"
    ];
  };
}
