{
  lib,
  config,
  ...
}: {
  # Loki for log aggregation
  virtualisation.oci-containers.containers."loki" = {
    image = "grafana/loki:latest";
    volumes = [
      "/home/ubuntu/loki:/loki:rw"
      "${./config/loki.yml}:/etc/loki/local-config.yaml:ro"
    ];
    user = "65534:65534"; # nobody user
    cmd = [
      "-config.file=/etc/loki/local-config.yaml"
    ];
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.loki.entrypoints" = "websecure";
      "traefik.http.routers.loki.middlewares" = "authelia@docker";
      "traefik.http.routers.loki.rule" = "Host(`loki.kuipr.de`)";
      "traefik.http.routers.loki.tls.certresolver" = "myresolver";
      "traefik.http.services.loki.loadbalancer.server.port" = "3100";
    };
    log-driver = "journald";
    extraOptions = [
      "--network-alias=loki"
      "--network=monitoring_default"
      "--network=proxy"
    ];
  };

  systemd.services."podman-loki" = {
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

  # Promtail for log collection
  virtualisation.oci-containers.containers."promtail" = {
    image = "grafana/promtail:latest";
    volumes = [
      "/run/podman/podman.sock:/var/run/docker.sock:ro"
      "${./config/promtail.yml}:/etc/promtail/config.yml:ro"
      "/home/ubuntu/traefik/logs:/home/ubuntu/traefik/logs:ro"
      "/var/log:/var/log:ro"
    ];
    cmd = [
      "-config.file=/etc/promtail/config.yml"
    ];
    labels = {
      "traefik.http.services.promtail.loadbalancer.server.port" = "1000";
    };
    log-driver = "journald";
    extraOptions = [
      "--network-alias=promtail"
      "--network=monitoring_default"
    ];
  };

  systemd.services."podman-promtail" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-monitoring_default.service"
      "podman-loki.service"
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
