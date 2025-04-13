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
    image = "lscr.io/linuxserver/qbittorrent:latest";
    log-driver = "journald";
    environmentFiles = [
      "/run/secrets/torrent.env"
    ];
    volumes = [
      "/mnt/data/torrents:/downloads:rw"
      "/home/ubuntu/qbittorrent:/config:rw"
    ];
    dependsOn = [
      "gluetun"
    ];
    extraOptions = [
      "--network=container:gluetun"
    ];
  };

  # Service
  systemd.services."podman-qbittorrent" = {
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
