{
  lib,
  config,
  ...
}: {
  # cAdvisor for container metrics
  virtualisation.oci-containers.containers."cadvisor" = {
    image = "gcr.io/cadvisor/cadvisor:latest";
    volumes = [
      "/:/rootfs:ro"
      "/var/run:/var/run:rw"
      "/sys:/sys:ro"
      "/var/lib/containers:/var/lib/containers:ro"
      "/dev/disk/:/dev/disk:ro"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=cadvisor"
      "--network=monitoring_default"
      "--privileged"
    ];
    # ports = [
    #   "8080:8080"
    # ];
  };

  systemd.services."podman-cadvisor" = {
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
