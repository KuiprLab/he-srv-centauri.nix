{
  lib,
  config,
  ...
}: {
  # Prometheus configuration
  virtualisation.oci-containers.containers."prometheus" = {
    image = "prom/prometheus:latest";
    volumes = [
      "/home/ubuntu/prometheus:/prometheus:rw"
      "${./config/prometheus.yml}:/etc/prometheus/prometheus.yml:ro"
      "${./config/alert-rules.yml}:/etc/prometheus/alert-rules.yml:ro"
    ];
    user = "65534:65534"; # nobody user
    cmd = [
      "--config.file=/etc/prometheus/prometheus.yml"
      "--storage.tsdb.path=/prometheus"
      "--web.console.libraries=/etc/prometheus/console_libraries"
      "--web.console.templates=/etc/prometheus/consoles"
      "--storage.tsdb.retention.time=30d"
      "--web.enable-lifecycle"
      "--web.enable-admin-api"
      "--query.max-concurrency=20"
      "--log.level=info"
    ];
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.prometheus.entrypoints" = "websecure";
      "traefik.http.routers.prometheus.middlewares" = "authelia@docker";
      "traefik.http.routers.prometheus.rule" = "Host(`prometheus.kuipr.de`)";
      "traefik.http.routers.prometheus.tls.certresolver" = "myresolver";
      "traefik.http.services.prometheus.loadbalancer.server.port" = "9090";
    };
    log-driver = "journald";
    extraOptions = [
      "--network-alias=prometheus"
      "--network=monitoring_default"
      "--network=proxy"
      "--add-host=host.containers.internal:host-gateway"
    ];
  };

  systemd.services."podman-prometheus" = {
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

  # Node Exporter for system metrics
  virtualisation.oci-containers.containers."node-exporter" = {
    image = "prom/node-exporter:latest";
    cmd = [
      "--path.procfs=/host/proc"
      "--path.rootfs=/host/rootfs"
      "--path.sysfs=/host/sys"
      "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)"
    ];
    volumes = [
      "/proc:/host/proc:ro"
      "/sys:/host/sys:ro"
      "/:/host/rootfs:ro"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=node-exporter"
      "--network=monitoring_default"
      "--pid=host"
    ];
  };

  systemd.services."podman-node-exporter" = {
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

  # cAdvisor for container metrics
  services.cadvisor = {
    enable = true;
    port = "8081";
  };
}
