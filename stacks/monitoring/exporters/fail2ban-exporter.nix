{
  lib,
  config,
  ...
}: {
  virtualisation.oci-containers.containers."fail2ban-exporter" = {
    image = "registry.gitlab.com/hctrdev/fail2ban-prometheus-exporter:latest";
    volumes = [
      "/var/run/fail2ban/:/var/run/fail2ban:ro"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=fail2ban-exporter"
      "--network=monitoring_default"
    ];
  };

  systemd.services."podman-fail2ban-exporter" = {
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
