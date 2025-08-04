{
  lib,
  config,
  ...
}: {
  sops.secrets = {
    "alertmanager.yml" = {
      sopsFile = ./config/alertmanager.yml;
      format = "yml";
      key = "";
      restartUnits = [
        "podman-alertmanager.service"
      ];
    };
  };

  # Alertmanager configuration
  virtualisation.oci-containers.containers."alertmanager" = {
    image = "prom/alertmanager:latest";
    volumes = [
      "/home/ubuntu/alertmanager:/alertmanager:rw"
      "${config.sops.secrets."alertmanager.yml".path}:/etc/alertmanager/alertmanager.yml:ro"
    ];
    cmd = [
      "--config.file=/etc/alertmanager/alertmanager.yml"
      "--storage.path=/alertmanager"
      "--web.external-url=https://alertmanager.kuipr.de"
    ];
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.alertmanager.entrypoints" = "websecure";
      "traefik.http.routers.alertmanager.middlewares" = "authelia@docker";
      "traefik.http.routers.alertmanager.rule" = "Host(`alertmanager.kuipr.de`)";
      "traefik.http.routers.alertmanager.tls.certresolver" = "myresolver";
      "traefik.http.services.alertmanager.loadbalancer.server.port" = "9093";
    };
    log-driver = "journald";
    extraOptions = [
      "--network-alias=alertmanager"
      "--network=monitoring_default"
      "--network=proxy"
    ];
  };

  systemd.services."podman-alertmanager" = {
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

  # Discord webhook bridge for alertmanager
  virtualisation.oci-containers.containers."discord-webhook" = {
    image = "plumeeus/alertmanager-discord:latest";
    environment = {
      "LISTEN_ADDRESS" = "0.0.0.0:9094";
    };
    environmentFiles = [
      "${config.sops.secrets."monitoring.env".path}"
    ];
    labels = {
      "traefik.enable" = "false";
    };
    log-driver = "journald";
    extraOptions = [
      "--network-alias=discord-webhook"
      "--network=monitoring_default"
    ];
  };

  systemd.services."podman-discord-webhook" = {
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
