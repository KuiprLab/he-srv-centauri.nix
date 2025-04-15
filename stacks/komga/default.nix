{
  pkgs,
  lib,
  config,
  ...
}: {
  myFolders = {
    komga = {
      path = "/home/ubuntu/komga";
      owner = "ubuntu";
      group = "users";
      mode = "0755";
    };
  };

  sops.secrets."komga.yaml" = {
    sopsFile = ./application.yaml;
    owner = "ubuntu";
    format = "yaml";
    key = "";
    restartUnits = ["podman-komga.service"];
  };
  # Enable container name DNS for all Podman networks.
  networking.firewall.interfaces = let
    matchAll =
      if !config.networking.nftables.enable
      then "podman+"
      else "podman*";
  in {
    "${matchAll}".allowedUDPPorts = [53];
  };

  virtualisation.oci-containers.backend = "podman";

  # Containers
  virtualisation.oci-containers.containers."komga" = {
    image = "gotson/komga";
    environment = {
      "KOMGA_OAUTH2_ACCOUNT_CREATION" = "true";
      "KOMGA_OIDC_EMAIL_VERIFICATION" = "false";
      "TZ" = "Europe/Berlin";
    };
    volumes = [
      "/home/ubuntu/komga:/config:rw"
      "/run/secrets/komga.yaml:/config/application.yaml:rw"
      "/mnt/data/media/comics:/data:rw"
    ];
    labels = {
      "traefik.docker.network" = "proxy";
      "traefik.enable" = "true";
      "traefik.http.routers.komga.entrypoints" = "websecure";
      "traefik.http.routers.komga.rule" = "Host(`comics.kuipr.de`)";
      "traefik.http.routers.komga.tls.certresolver" = "myresolver";
      "traefik.http.services.komga.loadbalancer.server.port" = "25600";
      "traefik.port" = "25600";
    };
    user = "1000:1000";
    log-driver = "journald";
    extraOptions = [
      "--network-alias=komga"
      "--network=komga_default"
      "--network=proxy"
    ];
  };
  systemd.services."podman-komga" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-komga_default.service"
    ];
    requires = [
      "podman-network-komga_default.service"
    ];
    partOf = [
      "podman-compose-komga-root.target"
    ];
    wantedBy = [
      "podman-compose-komga-root.target"
    ];
  };

  # Networks
  systemd.services."podman-network-komga_default" = {
    path = [pkgs.podman];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f komga_default";
    };
    script = ''
      podman network inspect komga_default || podman network create komga_default
    '';
    partOf = ["podman-compose-komga-root.target"];
    wantedBy = ["podman-compose-komga-root.target"];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-komga-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = ["multi-user.target"];
  };
}
