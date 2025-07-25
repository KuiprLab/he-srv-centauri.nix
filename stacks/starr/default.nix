# Auto-generated using compose2nix v0.3.2-pre.
{
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    ./kapowarr.nix
  ];

  sops.secrets."radarr.env" = {
    sopsFile = ./radarr.env;
    format = "dotenv";
    key = "";
    restartUnits = ["podman-radarr.service"];
  };

  sops.secrets."sonarr.env" = {
    sopsFile = ./sonarr.env;
    format = "dotenv";
    key = "";
    restartUnits = ["podman-sonarr.service"];
  };

  sops.secrets."prowlarr.env" = {
    sopsFile = ./prowlarr.env;
    format = "dotenv";
    key = "";
    restartUnits = ["podman-prowlarr.service"];
  };

  sops.secrets."flaresolverr.env" = {
    sopsFile = ./flaresolverr.env;
    format = "dotenv";
    key = "";
    restartUnits = ["podman-flaresolverr.service"];
  };

  sops.secrets."lidarr.env" = {
    sopsFile = ./lidarr.env;
    format = "dotenv";
    key = "";
    restartUnits = ["podman-lidarr.service"];
  };

  myFolders = {
    starr = {
      path = "/home/ubuntu/{sonarr,radarr,prowlarr,lidarr}";
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

  virtualisation.oci-containers.containers."flaresolverr" = {
    image = "ghcr.io/flaresolverr/flaresolverr:latest";
    ports = [
      "8191:8191/tcp"
    ];
    environmentFiles = [
      "/run/secrets/flaresolverr.env"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=flaresolverr"
      "--network=proxy"
      "--network=starr_default"
    ];
  };
  systemd.services."podman-flaresolverr" = {
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
  virtualisation.oci-containers.containers."prowlarr" = {
    image = "lscr.io/linuxserver/prowlarr:latest";
    volumes = [
      "/home/ubuntu/prowlarr:/config:rw"
    ];
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.prowlarr.entrypoints" = "websecure";
      "traefik.http.routers.prowlarr.middlewares" = "authelia@docker";
      "traefik.http.routers.prowlarr.rule" = "Host(`prowlarr.kuipr.de`)";
      "traefik.http.routers.prowlarr.tls.certresolver" = "myresolver";
      "traefik.http.services.prowlarr.loadbalancer.server.port" = "9696";
    };
    environmentFiles = [
      "/run/secrets/prowlarr.env"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=prowlarr"
      "--network=proxy"
      "--network=starr_default"
    ];
  };
  systemd.services."podman-prowlarr" = {
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
  virtualisation.oci-containers.containers."radarr" = {
    image = "lscr.io/linuxserver/radarr:latest";
    volumes = [
      "/home/ubuntu/radarr:/config:rw"
      "/mnt/data/media/movies:/movies:rw"
      "/mnt/data/torrents:/app/qBittorrent/downloads:rw"
    ];
    environmentFiles = [
      "/run/secrets/radarr.env"
    ];
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.radarr.entrypoints" = "websecure";
      "traefik.http.routers.radarr.middlewares" = "authelia@docker";
      "traefik.http.routers.radarr.rule" = "Host(`radarr.kuipr.de`)";
      "traefik.http.routers.radarr.tls.certresolver" = "myresolver";
      "traefik.http.services.radarr.loadbalancer.server.port" = "7878";
    };
    log-driver = "journald";
    extraOptions = [
      "--network-alias=radarr"
      "--network=proxy"
      "--network=starr_default"
    ];
  };
  systemd.services."podman-radarr" = {
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
  virtualisation.oci-containers.containers."sonarr" = {
    image = "lscr.io/linuxserver/sonarr:latest";
    volumes = [
      "/home/ubuntu/sonarr:/config:rw"
      "/mnt/data/media/tv:/tv:rw"
      "/mnt/data/torrents:/app/qBittorrent/downloads:rw"
    ];
    labels = {
      "traefik.docker.network" = "proxy";
      "traefik.enable" = "true";
      "traefik.http.routers.sonarr.entrypoints" = "websecure";
      "traefik.http.routers.sonarr.middlewares" = "authelia@docker";
      "traefik.http.routers.sonarr.rule" = "Host(`sonarr.kuipr.de`)";
      "traefik.http.routers.sonarr.tls.certresolver" = "myresolver";
      "traefik.http.services.sonarr.loadbalancer.server.port" = "8989";
      "traefik.port" = "8989";
    };
    environmentFiles = [
      "/run/secrets/sonarr.env"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=sonarr"
      "--network=proxy"
      "--network=starr_default"
    ];
  };
  systemd.services."podman-sonarr" = {
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
  virtualisation.oci-containers.containers."unpackerr" = {
    image = "golift/unpackerr";
    volumes = [
      "/mnt/data/torrents:/downloads:rw"
    ];
    labels = {
      # Dummy port otherwise traefik gets mad
      "traefik.http.services.unpackerr.loadbalancer.server.port" = "1337";
    };
    user = "1000:1000";
    log-driver = "journald";
    extraOptions = [
      "--network-alias=unpackerr"
      "--network=proxy"
      "--network=starr_default"
    ];
  };

  virtualisation.oci-containers.containers."lidarr" = {
    image = "lscr.io/linuxserver/lidarr:2.13.1-nightly";
    volumes = [
      "/home/ubuntu/lidarr:/config:rw"
      "/mnt/data/media/music:/music:rw"
      "/mnt/data/downloads:/downloads:rw"
      "/mnt/data/torrents:/app/qBittorrent/downloads:rw"
    ];
    labels = {
      "traefik.docker.network" = "proxy";
      "traefik.enable" = "true";
      "traefik.http.routers.lidarr.entrypoints" = "websecure";
      "traefik.http.routers.lidarr.middlewares" = "authelia@docker";
      "traefik.http.routers.lidarr.rule" = "Host(`lidarr.kuipr.de`)";
      "traefik.http.routers.lidarr.tls.certresolver" = "myresolver";
      "traefik.http.services.lidarr.loadbalancer.server.port" = "8686";
      "traefik.port" = "8686";
    };
    environmentFiles = [
      "/run/secrets/lidarr.env"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=lidarr"
      "--network=proxy"
      "--network=starr_default"
    ];
  };
  systemd.services."podman-lidarr" = {
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

  systemd.services."podman-unpackerr" = {
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

  # Networks
  systemd.services."podman-network-starr_default" = {
    path = [pkgs.podman];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f starr_default";
    };
    script = ''
      podman network inspect starr_default || podman network create starr_default
    '';
    partOf = ["podman-compose-starr-root.target"];
    wantedBy = ["podman-compose-starr-root.target"];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-starr-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = ["multi-user.target"];
  };
}
