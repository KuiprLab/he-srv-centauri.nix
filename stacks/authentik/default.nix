# Auto-generated using compose2nix v0.3.2-pre.
{ pkgs, lib, config, ... }:

{
  imports = [../../utils/my-declared-folders.nix];

  sops.secrets."authentik.env" = {
    sopsFile = ./authentik.env;
    format = "dotenv";
    key = "";
    restartUnits = ["podman-ak-server.service"];
  };


    myFolders = {
        authentik = {
            path = "/home/ubuntu/authentik/{media,templates,postgresql,certs}";
            owner = "ubuntu";
            group = "users";
            mode = "0755";
        };
    };

  # Enable container name DNS for all Podman networks.
  networking.firewall.interfaces = let
    matchAll = if !config.networking.nftables.enable then "podman+" else "podman*";
  in {
    "${matchAll}".allowedUDPPorts = [ 53 ];
  };

  virtualisation.oci-containers.backend = "podman";

  # Containers
  virtualisation.oci-containers.containers."ak-server" = {
    image = "ghcr.io/goauthentik/server:latest";
    volumes = [
      "/home/ubuntu/authentik/media:/media:rw"
      "/home/ubuntu/authentik/media/custom.css:/web/dist/custom.css:rw"
      "/home/ubuntu/authentik/templates:/templates:rw"
    ];
    ports = [
      "9191:9000/tcp"
    ];
    environmentFiles = [
      "/run/secrets/authentik.env"
    ];
    cmd = [ "server" ];
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.server.entrypoints" = "websecure";
      "traefik.http.routers.server.rule" = "Host(`auth.kuipr.de`)";
      "traefik.http.routers.server.tls.certresolver" = "myresolver";
      "traefik.http.services.server.loadbalancer.server.port" = "9000";
      "traefik.port" = "9000";
    };
    dependsOn = [
      "authentik-postgresql"
      "authentik-redis"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=server"
      "--network=authentik_default"
      "--network=proxy"
    ];
  };
  systemd.services."podman-ak-server" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-authentik_default.service"
    ];
    requires = [
      "podman-network-authentik_default.service"
    ];
    partOf = [
      "podman-compose-authentik-root.target"
    ];
    wantedBy = [
      "podman-compose-authentik-root.target"
    ];
  };
  virtualisation.oci-containers.containers."authentik-authentik-proxy" = {
    image = "ghcr.io/goauthentik/proxy";
    ports = [
      "9000:9000/tcp"
      "9443:9443/tcp"
    ];
    labels = {
      "traefik.docker.network" = "proxy";
      "traefik.enable" = "true";
      "traefik.http.middlewares.authentik.forwardauth.address" = "http://authentik-proxy:9000/outpost.goauthentik.io/auth/traefik";
      "traefik.http.middlewares.authentik.forwardauth.authResponseHeaders" = "X-authentik-username,X-authentik-groups,X-authentik-entitlements,X-authentik-email,X-authentik-name,X-authentik-uid,X-authentik-jwt,X-authentik-meta-jwks,X-authentik-meta-outpost,X-authentik-meta-provider,X-authentik-meta-app,X-authentik-meta-version,Authorization,Set-Cookie";
      "traefik.http.middlewares.authentik.forwardauth.trustForwardHeader" = "true";
      "traefik.http.routers.authentik.entryPoints" = "websecure";
      "traefik.http.routers.authentik.rule" = "Host(`auth.kuipr.de`) || HostRegexp(`{subdomain:[A-Za-z0-9](?:[A-Za-z0-9\\-]{0,61}[A-Za-z0-9])?}.kuipr.de`) && PathPrefix(`/outpost.goauthentik.io/`)";
      "traefik.port" = "9000";
    };
    dependsOn = [
      "ak-server"
    ];
    environmentFiles = [
      "/run/secrets/authentik.env"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=authentik-proxy"
      "--network=authentik_default"
      "--network=proxy"
    ];
  };
  systemd.services."podman-authentik-authentik-proxy" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-authentik_default.service"
    ];
    requires = [
      "podman-network-authentik_default.service"
    ];
    partOf = [
      "podman-compose-authentik-root.target"
    ];
    wantedBy = [
      "podman-compose-authentik-root.target"
    ];
  };
  virtualisation.oci-containers.containers."authentik-postgresql" = {
    image = "docker.io/library/postgres:16-alpine";
    volumes = [
      "/home/ubuntu/authentik/postgresql:/var/lib/postgresql/data:rw"
    ];
    log-driver = "journald";
    environmentFiles = [
      "/run/secrets/authentik.env"
    ];
    extraOptions = [
      "--health-cmd=pg_isready -d \${POSTGRES_DB} -U \${POSTGRES_USER}"
      "--health-interval=30s"
      "--health-retries=5"
      "--health-start-period=20s"
      "--health-timeout=5s"
      "--network-alias=postgresql"
      "--network=authentik_default"
      "--network=proxy"
    ];
  };
  systemd.services."podman-authentik-postgresql" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-authentik_default.service"
    ];
    requires = [
      "podman-network-authentik_default.service"
    ];
    partOf = [
      "podman-compose-authentik-root.target"
    ];
    wantedBy = [
      "podman-compose-authentik-root.target"
    ];
  };
  virtualisation.oci-containers.containers."authentik-redis" = {
    image = "docker.io/library/redis:alpine";
    volumes = [
      "authentik_redis:/data:rw"
    ];
    environmentFiles = [
      "/run/secrets/authentik.env"
    ];
    cmd = [ "--save" "60" "1" "--loglevel" "warning" ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=redis-cli ping | grep PONG"
      "--health-interval=30s"
      "--health-retries=5"
      "--health-start-period=20s"
      "--health-timeout=3s"
      "--network-alias=redis"
      "--network=authentik_default"
      "--network=proxy"
    ];
  };
  systemd.services."podman-authentik-redis" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-authentik_default.service"
      "podman-volume-authentik_redis.service"
    ];
    requires = [
      "podman-network-authentik_default.service"
      "podman-volume-authentik_redis.service"
    ];
    partOf = [
      "podman-compose-authentik-root.target"
    ];
    wantedBy = [
      "podman-compose-authentik-root.target"
    ];
  };
  virtualisation.oci-containers.containers."authentik-worker" = {
    image = "ghcr.io/goauthentik/server:latest";
    volumes = [
      "/home/ubuntu/authentik/certs:/certs:rw"
      "/home/ubuntu/authentik/media:/media:rw"
      "/home/ubuntu/authentik/templates:/templates:rw"
      "/run/podman/podman.sock:/var/run/docker.sock:rw"
    ];
    environmentFiles = [
      "/run/secrets/authentik.env"
    ];
    cmd = [ "worker" ];
    dependsOn = [
      "authentik-postgresql"
      "authentik-redis"
    ];
    user = "root";
    log-driver = "journald";
    extraOptions = [
      "--network-alias=worker"
      "--network=authentik_default"
      "--network=proxy"
    ];
  };
  systemd.services."podman-authentik-worker" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-authentik_default.service"
    ];
    requires = [
      "podman-network-authentik_default.service"
    ];
    partOf = [
      "podman-compose-authentik-root.target"
    ];
    wantedBy = [
      "podman-compose-authentik-root.target"
    ];
  };

  # Networks
  systemd.services."podman-network-authentik_default" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f authentik_default";
    };
    script = ''
      podman network inspect authentik_default || podman network create authentik_default
    '';
    partOf = [ "podman-compose-authentik-root.target" ];
    wantedBy = [ "podman-compose-authentik-root.target" ];
  };

  # Volumes
  systemd.services."podman-volume-authentik_database" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      podman volume inspect authentik_database || podman volume create authentik_database --driver=local
    '';
    partOf = [ "podman-compose-authentik-root.target" ];
    wantedBy = [ "podman-compose-authentik-root.target" ];
  };
  systemd.services."podman-volume-authentik_redis" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      podman volume inspect authentik_redis || podman volume create authentik_redis --driver=local
    '';
    partOf = [ "podman-compose-authentik-root.target" ];
    wantedBy = [ "podman-compose-authentik-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-authentik-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
