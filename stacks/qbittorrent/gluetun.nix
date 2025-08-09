{lib, ...}: {
  sops.secrets."gluetun.env" = {
    sopsFile = ./gluetun.env;
    format = "dotenv";
    key = "";
    restartUnits = ["podman-gluetun.service"];
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
      "--network=seedbox_default"
    ];
    ports = [
      "8080:8080/tcp"
      "47594/tcp"
      "5030:5030"
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
