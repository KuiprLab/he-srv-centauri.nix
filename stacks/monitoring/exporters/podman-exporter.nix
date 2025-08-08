{
  lib,
  config,
  ...
}: {
  virtualisation.oci-containers.containers."podman-exporter" = {
    image = "quay.io/navidys/prometheus-podman-exporter";
    volumes = [
      "/run/podman/podman.sock:/run/podman/podman.sock:ro"
    ];
    log-driver = "journald";

    environment = {
      "CONTAINER_HOST" = "unix:///run/podman/podman.sock";
    };
    extraOptions = [
      "--network-alias=podman-exporter"
      "--network=monitoring_default"
    ];
  };

  systemd.services."podman-podman-exporter" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-monitoring_default.service"
    ];
    requires = [
      "podman-network-monitoring_default.service"
    ];
    partOf = [
      "podman-compose-monitoring-root.target"
    ];
    wantedBy = [
      "podman-compose-monitoring-root.target"
    ];
  };
}
