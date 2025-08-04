{
  homelab,
  lib,
  ...
}: {
  sops.secrets = {
    "torrent.env" = {
      sopsFile = ./qbittorrent.env;
      format = "dotenv";
      key = "";
      restartUnits = ["podman-qbittorrent.service"];
    };
    "qbit_exporter.env" = {
      sopsFile = ./qbit_exporter.env;
      format = "dotenv";
      key = "";
      restartUnits = ["podman-qbittorrent.service"];
    };
  };

  myFolders = {
    qbittorrent = {
      path = "/home/ubuntu/qbittorrent";
      owner = "ubuntu";
      group = "users";
      mode = "0755";
    };
  };

  # qBittorrent Container
  virtualisation.oci-containers.containers."qbittorrent" = {
    image = "ghcr.io/hotio/qbittorrent:latest";
    log-driver = "journald";
    environmentFiles = [
      "/run/secrets/torrent.env"
    ];
    volumes = [
      "/mnt/data/torrents:/app/qBittorrent/downloads:rw"
      "/home/ubuntu/qbittorrent:/config:rw"
    ];
    dependsOn = [
      "gluetun"
    ];
    extraOptions = [
      "--network=container:gluetun"
    ];
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.qbittorrent.entrypoints" = "websecure";
      "traefik.http.routers.qbittorrent.rule" = "Host(`qbit.kuipr.de`)";
      "traefik.http.routers.qbittorrent.service" = "qbittorrent";
      "traefik.http.routers.qbittorrent.tls.certresolver" = "myresolver";
      "traefik.http.services.qbittorrent.loadbalancer.server.port" = "8585";
    };
  };

  # qBittorrent Exporter Container
  virtualisation.oci-containers.containers."qbittorrent-exporter" = {
    image = "ghcr.io/esanchezm/prometheus-qbittorrent-exporter:latest";
    log-driver = "journald";
    environmentFiles = [
      "/run/secrets/qbit_exporter.env"
    ];
    ports = [
      "8000:8000"
    ];
    dependsOn = [
      "qbittorrent"
    ];
    extraOptions = [
      "--network=monitoring_default"
    ];
  };

  # qBittorrent Service
  systemd.services."podman-qbittorrent" = {
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

  # qBittorrent Exporter Service
  systemd.services."podman-qbittorrent-exporter" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-qbittorrent.service"
      "podman-gluetun.service"
    ];
    requires = [
      "podman-qbittorrent.service"
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
