# Auto-generated for Authelia migration
{
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [../../utils/my-declared-folders.nix];

  sops.secrets."authelia.env" = {
    sopsFile = ./authelia.env;
    format = "dotenv";
    key = "";
    restartUnits = ["podman-authelia.service"];
  };

  sops.secrets."configuration.yml" = {
    sopsFile = ./configuration.yml;
    format = "yaml";
    key = "";
    restartUnits = ["podman-authelia.service"];
  };

  sops.secrets."authelia-users.yaml" = {
    sopsFile = ./users.yaml;
    key = "";
    restartUnits = ["podman-authelia.service"];
  };

  myFolders = {
    authelia = {
      path = "/home/ubuntu/authelia/{config,data,db,data/redis}";
      owner = "ubuntu";
      group = "users";
      mode = "0755";
    };
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
  virtualisation.oci-containers.containers."authelia" = {
    image = "authelia/authelia:latest";
    volumes = [
      "/home/ubuntu/authelia/config:/config:rw"
      "/run/secrets/configuration.yml:/config/configuration.yml:ro"
      "/home/ubuntu/authelia/data:/data:rw"
      "/run/secrets/authelia-users.yaml:/config/users_database.yaml:rw"
    ];
    ports = [
      "9091:9091/tcp"
    ];
    environmentFiles = [
      "/run/secrets/authelia.env"
    ];
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.authelia.rule" = "Host(`auth.kuipr.de`)";
      "traefik.http.routers.authelia.entrypoints" = "websecure";
      "traefik.http.routers.authelia.tls.certresolver" = "myresolver";
      "traefik.http.services.authelia.loadbalancer.server.port" = "9091";
      "traefik.http.middlewares.authelia.forwardauth.address" = "http://authelia:9091/api/verify?rd=https://auth.kuipr.de";
      "traefik.http.middlewares.authelia.forwardauth.trustForwardHeader" = "true";
      "traefik.http.middlewares.authelia.forwardauth.authResponseHeaders" = "Remote-User,Remote-Groups,Remote-Name,Remote-Email";
    };
    log-driver = "journald";
    extraOptions = [
      "--network-alias=authelia"
      "--network=authelia_default"
      "--network=proxy"
    ];
  };
  systemd.services."podman-authelia" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-authelia_default.service"
    ];
    requires = [
      "podman-network-authelia_default.service"
    ];
    partOf = [
      "podman-compose-authelia-root.target"
    ];
    wantedBy = [
      "podman-compose-authelia-root.target"
    ];
  };

  # virtualisation.oci-containers.containers."redis" = {
  #   image = "redis:alpine";
  #   volumes = [
  #     "/home/ubuntu/authelia/data/redis:/data:rw"
  #   ];
  #   labels = {};
  #   log-driver = "journald";
  #   extraOptions = [
  #     "--network-alias=redis"
  #     "--network=authelia_default"
  #   ];
  # };

  # systemd.services."podman-authelia-redis" = {
  #   serviceConfig = {
  #     Restart = lib.mkOverride 90 "always";
  #   };
  #   after = [
  #     "podman-network-authelia_default.service"
  #   ];
  #   requires = [
  #     "podman-network-authelia_default.service"
  #   ];
  #   partOf = [
  #     "podman-compose-authelia-root.target"
  #   ];
  #   wantedBy = [
  #     "podman-compose-authelia-root.target"
  #   ];
  # };

  # Networks
  systemd.services."podman-network-authelia_default" = {
    path = [pkgs.podman];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f authelia_default";
    };
    script = ''
      podman network inspect authelia_default || podman network create authelia_default
    '';
    partOf = ["podman-compose-authelia-root.target"];
    wantedBy = ["podman-compose-authelia-root.target"];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-authelia-root" = {
    unitConfig = {
      Description = "Root target generated for Authelia.";
    };
    wantedBy = ["multi-user.target"];
  };
}
