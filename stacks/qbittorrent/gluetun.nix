{ lib, ... }:
{

  sops.secrets."gluetun.env" = {
    sopsFile = ./gluetun.env;
    format = "dotenv";
    key = "";
    restartUnits = [ "podman-gluetun.service" ];
  };

  virtualisation.oci-containers.containers."gluetun" = {
    image = "qmcgaw/gluetun";
    log-driver = "journald";
    environmentFiles = [
      "/run/secrets/gluetun.env"
    ];
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
      "--sysctl=net.ipv4.conf.all.src_valid_mark=1"
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
    ports = [
      "8080:8080/tcp"
      "47594/tcp"
      "47594/udp"
    ];

  };
  systemd.services."podman-gluetun" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-seedbox_default.service"
    ];
    requires = [
      "podman-network-seedbox_default.service"
    ];
    partOf = [
      "podman-compose-seedbox-root.target"
    ];
    wantedBy = [
      "podman-compose-seedbox-root.target"
    ];
  };

}
