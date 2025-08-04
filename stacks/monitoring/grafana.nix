{
  lib,
  config,
  ...
}: {
  # Grafana configuration
  virtualisation.oci-containers.containers."grafana" = {
    image = "grafana/grafana-dev";
    environment = {
      "GF_SECURITY_ADMIN_USER" = "admin";
      "GF_USERS_ALLOW_SIGN_UP" = "false";
      "GF_SERVER_DOMAIN" = "grafana.kuipr.de";
      "GF_SERVER_ROOT_URL" = "https://grafana.kuipr.de";
      "GF_PATHS_PLUGINS" = "/var/lib/grafana/plugins";
      "GF_INSTALL_PLUGINS" = ""; # Remove auto-install to avoid permission issues
    };
    environmentFiles = [
      "${config.sops.secrets."monitoring.env".path}"
    ];
    volumes = [
      "/home/ubuntu/grafana:/var/lib/grafana:rw"
      "${./config/grafana-datasources.yml}:/etc/grafana/provisioning/datasources/datasources.yml:ro"
      "${./config/grafana-dashboards.yml}:/etc/grafana/provisioning/dashboards/dashboards.yml:ro"
      "${./dashboards}:/var/lib/grafana/dashboards:ro"
    ];
    user = "472:472"; # grafana user
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.grafana.entrypoints" = "websecure";
      "traefik.http.routers.grafana.rule" = "Host(`grafana.kuipr.de`)";
      "traefik.http.routers.grafana.tls.certresolver" = "myresolver";
      "traefik.http.services.grafana.loadbalancer.server.port" = "3000";
    };
    log-driver = "journald";
    extraOptions = [
      "--network-alias=grafana"
      "--network=monitoring_default"
      "--network=proxy"
    ];
  };

  systemd.services."podman-grafana" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-monitoring_default.service"
      "podman-prometheus.service"
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
