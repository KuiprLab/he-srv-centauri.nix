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
    # Simplify service restarts to reduce activation issues
    restartUnits = [];
  };

  sops.secrets."gluetun.env" = {
    sopsFile = ./gluetun.env;
    format = "dotenv";
    key = "";
    # Simplify service restarts to reduce activation issues
    restartUnits = ["podman-gluetun.service"];
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
    "${matchAll}" = {
            allowedUDPPorts = [53];
    allowedTCPPorts = [
      8888
      8388
      8388
      6881
      6881
      8585
      5656
        ];

        };
            
  };

  virtualisation.oci-containers.backend = "podman";

  # Networks - Create network first
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
    wantedBy = ["multi-user.target"];
  };

  # Containers
  # VPN container first
  virtualisation.oci-containers.containers."gluetun" = {
    image = "qmcgaw/gluetun";
    environmentFiles = [
      "/run/secrets/gluetun.env"
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
      "traefik.http.routers.kapowarr.middlewares" = "authelia@docker";
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
      "--cap-add=NET_RAW" # Added capability
      "--device=/dev/net/tun:/dev/net/tun:rwm"
      "--health-cmd=[\"wget\", \"-qO-\", \"https://ipinfo.io/ip\"]"
      "--health-interval=30s"
      "--health-retries=3"
      "--health-start-period=10s"
      "--health-timeout=10s"
      "--network-alias=gluetun"
      "--network=proxy"
      "--network=qbittorrent_default"
      "--sysctl=net.ipv4.conf.all.src_valid_mark=1" # Added sysctl
    ];
  };

  systemd.services."podman-gluetun" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-qbittorrent_default.service"
      "sops-nix.service" # Make sure secrets are available
    ];
    requires = [
      "podman-network-qbittorrent_default.service"
    ];
    wantedBy = ["multi-user.target"];
  };

  # Other containers
  virtualisation.oci-containers.containers."flaresolverr_comics" = {
    image = "ghcr.io/flaresolverr/flaresolverr:latest";
    environmentFiles = [
      "/run/secrets/qbittorrent.env"
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
    after = ["podman-gluetun.service"];
    requires = ["podman-gluetun.service"];
    wantedBy = ["multi-user.target"];
  };

  virtualisation.oci-containers.containers."kapowarr" = {
    image = "mrcas/kapowarr-alpha:latest";
    volumes = [
      "/home/ubuntu/kapowarr:/app/db:rw"
      "/mnt/data/downloads:/app/temp_downloads:rw"
      "/mnt/data/media/comics:/comics-1:rw"
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
    after = ["podman-gluetun.service"];
    requires = ["podman-gluetun.service"];
    wantedBy = ["multi-user.target"];
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
    after = ["podman-gluetun.service"];
    requires = ["podman-gluetun.service"];
    wantedBy = ["multi-user.target"];
  };

  # Remove the target-based approach to simplify service management
  # Each service now has wantedBy = ["multi-user.target"] instead
}
