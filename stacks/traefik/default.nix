{
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [../../utils/my-declared-folders.nix];

  sops.secrets."traefik.env" = {
    sopsFile = ./traefik.env;
    format = "dotenv";
    key = "";
    restartUnits = ["podman-traefik.service"];
  };

  myFolders = {
    config = {
      path = "/home/ubuntu/traefik/config";
      owner = "ubuntu";
      group = "users";
      mode = "0755";
    };
    letsencrypt = {
      path = "/home/ubuntu/traefik/letsencrypt";
      owner = "ubuntu";
      group = "users";
      mode = "0755";
    };
    logs = {
      path = "/home/ubuntu/traefik/logs";
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
  virtualisation.oci-containers.containers."whoami" = {
    image = "traefik/whoami";
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.whoami.entrypoints" = "websecure";
      "traefik.http.routers.whoami.middlewares" = "authelia@docker";
      "traefik.http.routers.whoami.rule" = "Host(`whoami.kuipr.de`)";
      "traefik.http.routers.whoami.tls.certresolver" = "myresolver";
      "traefik.http.services.whoami.loadbalancer.server.port" = "80";
    };
    log-driver = "journald";
    extraOptions = [
      "--network-alias=whoami"
      "--network=proxy"
    ];
  };
  systemd.services."podman-simple-service" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-proxy.service"
    ];
    requires = [
      "podman-network-proxy.service"
    ];
    partOf = [
      "podman-compose-traefik-root.target"
    ];
    wantedBy = [
      "podman-compose-traefik-root.target"
    ];
  };
  virtualisation.oci-containers.containers."traefik" = {
    image = "traefik:v3.3";
    volumes = [
      "/home/ubuntu/traefik/config:/config:rw"
      "/home/ubuntu/traefik/letsencrypt:/letsencrypt:rw"
      "/home/ubuntu/traefik/logs:/logs:rw"
      "/run/podman/podman.sock:/var/run/docker.sock:ro"
    ];
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.api.rule" = "Host(`traefik.kuipr.de`)";
      "traefik.http.routers.api.entrypoints" = "https";
      "traefik.http.routers.api.service" = "api@internal";
      "traefik.http.routers.api.tls" = "true";
      "traefik.http.routers.api.tls.options" = "default";
      "traefik.http.routers.api.middlewares" = "authelia@docker";
    };
    environmentFiles = [
      "/run/secrets/traefik.env"
    ];
    ports = [
      "8081:80/tcp"
      "8443:443/tcp"
      "8181:8080/tcp"
    ];
    cmd = [
      "--api"
      "--log.level=INFO"
      "--accesslog=true"
      "--accesslog.filepath=/logs/access.log"
      "--accesslog.bufferingsize=100"
      "--api.insecure=true"
      "--providers.docker=true"
      "--providers.file.directory=/config"
      "--providers.file.watch=true"
      "--providers.docker.exposedByDefault=false"
      "--providers.docker.network=proxy"
      "--entryPoints.web.address=:80"
      "--entrypoints.http.http.redirections.entrypoint.to=https"
      "--entrypoints.http.http.redirections.entrypoint.scheme=https"
      "--entrypoints.https=true"
      "--entryPoints.websecure.address=:443"
      "--certificatesresolvers.myresolver.acme.dnschallenge=true"
      "--certificatesresolvers.myresolver.acme.dnschallenge.provider=bunny"
      "--certificatesresolvers.myresolver.acme.email=daniel.inama02@gmail.com"
      "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
      "--serversTransport.insecureSkipVerify=true"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=traefik"
      "--network=proxy"
    ];
  };
  systemd.services."podman-traefik" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-proxy.service"
    ];
    requires = [
      "podman-network-proxy.service"
    ];
    partOf = [
      "podman-compose-traefik-root.target"
    ];
    wantedBy = [
      "podman-compose-traefik-root.target"
    ];
  };

  # Networks
  systemd.services."podman-network-proxy" = {
    path = [pkgs.podman];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f proxy";
    };
    script = ''
      podman network inspect proxy || podman network create proxy
    '';
    partOf = ["podman-compose-traefik-root.target"];
    wantedBy = ["podman-compose-traefik-root.target"];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-traefik-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = ["multi-user.target"];
  };
}
