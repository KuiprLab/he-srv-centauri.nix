{
  homelab,
  lib,
  ...
}: {
  sops.secrets."torrent.env" = {
    sopsFile = ./qbittorrent.env;
    format = "dotenv";
    key = "";
    restartUnits = ["podman-qbittorrent.service"];
  };

  myFolders = {
    qbittorrent = {
      path = "/home/ubuntu/qbittorrent";
      owner = "ubuntu";
      group = "users";
      mode = "0755";
    };
  };
  # Container
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
    # Add specific labels for qbittorrent service
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.qbittorrent.entrypoints" = "websecure";
      "traefik.http.routers.qbittorrent.rule" = "Host(`qbit.kuipr.de`)";
      "traefik.http.routers.qbittorrent.service" = "qbittorrent";
      "traefik.http.routers.qbittorrent.tls.certresolver" = "myresolver";
      "traefik.http.services.qbittorrent.loadbalancer.server.port" = "8585";
    };
  };

  # Service
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
}
