# Auto-generated monitoring stack
{
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    ./prometheus.nix
    ./grafana.nix
    ./loki.nix
    ./alertmanager.nix
    ./fail2ban-exporter.nix
  ];

  myFolders = {
    prometheus = {
      path = "/home/ubuntu/prometheus";
      owner = "65534"; # nobody user for prometheus
      group = "65534";
      mode = "0755";
    };
    grafana = {
      path = "/home/ubuntu/grafana";
      owner = "472"; # grafana user
      group = "472";
      mode = "0755";
    };
    loki = {
      path = "/home/ubuntu/loki";
      owner = "65534";
      group = "65534";
      mode = "0755";
    };
    alertmanager = {
      path = "/home/ubuntu/alertmanager";
      owner = "ubuntu";
      group = "users";
      mode = "0755";
    };
  };

  # SOPS secrets for monitoring stack
  sops.secrets = {
    "monitoring.env" = {
      sopsFile = ./monitoring.env;
      format = "dotenv";
      key = "";
      restartUnits = [
        "podman-grafana.service"
        "podman-prometheus.service"
        "podman-alertmanager.service"
      ];
    };
  };

  # Enable container name DNS for all Podman networks
  networking.firewall.interfaces = let
    matchAll =
      if !config.networking.nftables.enable
      then "podman+"
      else "podman*";
  in {
    "${matchAll}".allowedUDPPorts = [53];
  };

  virtualisation.oci-containers.backend = "podman";

  # Networks
  systemd.services."podman-network-monitoring_default" = {
    path = [pkgs.podman];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f monitoring_default";
    };
    script = ''
      podman network inspect monitoring_default || podman network create --dns-enabled monitoring_default
    '';
    partOf = ["podman-compose-monitoring-root.target"];
    wantedBy = ["podman-compose-monitoring-root.target"];
  };

  # Root service
  systemd.targets."podman-compose-monitoring-root" = {
    unitConfig = {
      Description = "Root target for monitoring stack";
    };
    wantedBy = ["multi-user.target"];
  };
}
