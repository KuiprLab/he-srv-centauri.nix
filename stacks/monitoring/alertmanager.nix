{
  lib,
  config,
  ...
}: {
  sops.secrets = {
    "alertmanager.yml" = {
      sopsFile = ./config/alertmanager.yml;
      format = "yaml";
      key = "";
      mode = "0644";
      owner = "ubuntu";
      group = "users";
      restartUnits = [
        "podman-alertmanager.service"
      ];
    };
  };

  # Alertmanager configuration
  virtualisation.oci-containers.containers."alertmanager" = {
    image = "prom/alertmanager:latest";
    user = "1000:100";
    volumes = [
      "/home/ubuntu/alertmanager:/alertmanager:rw"
      "/var/run/secrets/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro"
    ];
    cmd = [
      "--config.file=/etc/alertmanager/alertmanager.yml"
      "--storage.path=/alertmanager"
      "--web.external-url=https://alertmanager.kuipr.de"
    ];
    labels = {
      "io.containers.autoupdate" = "registry";
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
}
