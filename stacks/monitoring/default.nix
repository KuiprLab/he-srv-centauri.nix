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
  ];

  myFolders = {
    monitoring = {
      path = "/home/ubuntu/{prometheus,grafana,loki,alertmanager}";
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
      podman network inspect monitoring_default || podman network create monitoring_default
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
