{
  lib,
  config,
  ...
}: {
  virtualisation.oci-containers.containers."fail2ban-exporter" = {
    image = "crazymax/fail2ban:latest";
    volumes = [
      "/var/log:/var/log:ro"
      "/home/ubuntu/f2b-exporter:/data"
    ];
    # environmentFiles = [
    # ];
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
