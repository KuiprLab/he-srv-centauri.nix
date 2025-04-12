# Auto-generated using compose2nix v0.3.2-pre.
{
  pkgs,
  lib,
  config,
  ...
}: {
  sops.secrets."qbittorrent.env" = {
    sopsFile = ./qbittorrent.env;
    format = "dotenv";
    key = "";
    restartUnits = ["podman-gluetun.service" "podman-kapowarr.service" "podman-qbittorrent.service"];
  };

  myFolders = {
    gluetun = {
      path = "/home/ubuntu/gluetun";
      owner = "ubuntu";
      group = "users";
      mode = "0755";
    };

    kapowarr = {
      path = "/home/ubuntu/kapowarr";
      owner = "ubuntu";
      group = "users";
      mode = "0755";
    };

    qbittorrent = {
      path = "/home/ubuntu/qbittorrent";
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

  # Containers
  virtualisation.oci-containers.containers."flaresolverr_comics" = {
    image = "ghcr.io/flaresolverr/flaresolverr:latest";
    environmentFiles = [
      "/run/secrets/qbittorrent.env"
    ];
    dependsOn = [
      "gluetun"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network=container:gluetun"
    ];
  };
  systemd.services."podman-flaresolverr_comics" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    partOf = [
      "podman-compose-qbittorrent-root.target"
    ];
    wantedBy = [
      "podman-compose-qbittorrent-root.target"
    ];
  };
  virtualisation.oci-containers.containers."gluetun" = {
    image = "qmcgaw/gluetun";
    environmentFiles = [
      "/run/secrets/qbittorrent.env"
    ];

    volumes = [
      "/home/ubuntu/gluetun:/gluetun:rw"
    ];
    ports = [
      "8888:8888/tcp"
      "8388:8388/tcp"
      "8388:8388/udp"
      "6881:6881/tcp"
      "6881:6881/udp"
      "8585:8585/tcp"
      "5656:5656/tcp"
    ];
    labels = {
      "traefik.docker.network" = "proxy";
      "traefik.enable" = "true";
      "traefik.http.routers.kapowarr.entrypoints" = "websecure";
      "traefik.http.routers.kapowarr.middlewares" = "authentik@docker";
      "traefik.http.routers.kapowarr.rule" = "Host(`kapowarr.kuipr.de`)";
      "traefik.http.routers.kapowarr.service" = "kapowarr";
      "traefik.http.routers.kapowarr.tls.certresolver" = "myresolver";
      "traefik.http.routers.qbittorrent.entrypoints" = "websecure";
      "traefik.http.routers.qbittorrent.rule" = "Host(`qbit.kuipr.de`)";
      "traefik.http.routers.qbittorrent.service" = "qbittorrent";
      "traefik.http.routers.qbittorrent.tls.certresolver" = "myresolver";
      "traefik.http.services.kapowarr.loadbalancer.server.port" = "5656";
      "traefik.http.services.qbittorrent.loadbalancer.server.port" = "8585";
    };
    log-driver = "journald";
    extraOptions = [
      "--cap-add=NET_ADMIN"
      "--device=/dev/net/tun:/dev/net/tun:rwm"
      "--health-cmd=[\"wget\", \"-qO-\", \"https://ipinfo.io/ip\"]"
      "--health-interval=30s"
      "--health-retries=3"
      "--health-start-period=10s"
      "--health-timeout=10s"
      "--network-alias=gluetun"
      "--network=proxy"
      "--network=qbittorrent_default"
    ];
  };
  systemd.services."podman-gluetun" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-qbittorrent_default.service"
    ];
    requires = [
      "podman-network-qbittorrent_default.service"
    ];
    partOf = [
      "podman-compose-qbittorrent-root.target"
    ];
    wantedBy = [
      "podman-compose-qbittorrent-root.target"
    ];
  };
  virtualisation.oci-containers.containers."kapowarr" = {
    image = "mrcas/kapowarr-alpha:latest";
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
  };
  systemd.services."podman-kapowarr" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    partOf = [
      "podman-compose-qbittorrent-root.target"
    ];
    wantedBy = [
      "podman-compose-qbittorrent-root.target"
    ];
  };
  virtualisation.oci-containers.containers."qbittorrent" = {
    image = "lscr.io/linuxserver/qbittorrent:latest";
    environmentFiles = [
      "/run/secrets/qbittorrent.env"
    ];
    volumes = [
      "/home/ubuntu/qbittorrent:/config:rw"
      "/mnt/data/torrents:/downloads:rw"
    ];
    dependsOn = [
      "gluetun"
    ];
    user = "0:0";
    log-driver = "journald";
    extraOptions = [
      "--network=container:gluetun"
    ];
  };
  systemd.services."podman-qbittorrent" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    partOf = [
      "podman-compose-qbittorrent-root.target"
    ];
    wantedBy = [
      "podman-compose-qbittorrent-root.target"
    ];
  };

  # Networks
  systemd.services."podman-network-qbittorrent_default" = {
    path = [pkgs.podman];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f qbittorrent_default";
    };
    script = ''
      podman network inspect qbittorrent_default || podman network create qbittorrent_default
    '';
    partOf = ["podman-compose-qbittorrent-root.target"];
    wantedBy = ["podman-compose-qbittorrent-root.target"];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-qbittorrent-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = ["multi-user.target"];
  };
}
