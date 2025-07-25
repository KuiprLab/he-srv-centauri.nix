# Auto-generated using compose2nix v0.3.2-pre.
{
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [../../utils/my-declared-folders.nix];

  myFolders = {
    zabbix-db = {
      path = "/home/ubuntu/zabbix/db-data";
      owner = "ubuntu";
      group = "users";
      mode = "0755";
    };
    zabbix-server = {
      path = "/home/ubuntu/zabbix/server-data";
      owner = "ubuntu";
      group = "users";
      mode = "0755";
    };
    zabbix-web = {
      path = "/home/ubuntu/zabbix/web-data";
      owner = "ubuntu";
      group = "users";
      mode = "0755";
    };
  };

  sops.secrets."zabbix.env" = {
    sopsFile = ./zabbix.env;
    format = "dotenv";
    key = "";
    restartUnits = ["podman-zabbix-db.service" "podman-zabbix-server.service" "podman-zabbix-web.service"];
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
  virtualisation.oci-containers.containers."zabbix-db" = {
    image = "postgres:16-alpine";
    environment = {
      "POSTGRES_DB" = "zabbix";
      "POSTGRES_USER" = "zabbix";
      "TZ" = "Europe/Rome";
    };
    environmentFiles = [
      "/run/secrets/zabbix.env"
    ];
    volumes = [
      "/home/ubuntu/zabbix/db-data:/var/lib/postgresql/data:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=zabbix-db"
      "--network=zabbix_default"
    ];
  };

  virtualisation.oci-containers.containers."zabbix-server" = {
    image = "zabbix/zabbix-server-pgsql:latest";
    environment = {
      "DB_SERVER_HOST" = "zabbix-db";
      "POSTGRES_DB" = "zabbix";
      "POSTGRES_USER" = "zabbix";
      "TZ" = "Europe/Rome";
    };
    environmentFiles = [
      "/run/secrets/zabbix.env"
    ];
    volumes = [
      "/home/ubuntu/zabbix/server-data:/var/lib/zabbix:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=zabbix-server"
      "--network=zabbix_default"
    ];
    dependsOn = ["zabbix-db"];
  };

  virtualisation.oci-containers.containers."zabbix-web" = {
    image = "zabbix/zabbix-web-nginx-pgsql:latest";
    environment = {
      "ZBX_SERVER_HOST" = "zabbix-server";
      "DB_SERVER_HOST" = "zabbix-db";
      "POSTGRES_DB" = "zabbix";
      "POSTGRES_USER" = "zabbix";
      "TZ" = "Europe/Rome";
    };
    environmentFiles = [
      "/run/secrets/zabbix.env"
    ];
    volumes = [
      "/home/ubuntu/zabbix/web-data:/etc/ssl/nginx:rw"
    ];
    labels = {
      "traefik.docker.network" = "proxy";
      "traefik.enable" = "true";
      "traefik.http.routers.zabbix.entrypoints" = "websecure";
      "traefik.http.routers.zabbix.middlewares" = "authelia@docker";
      "traefik.http.routers.zabbix.rule" = "Host(`monit.kuipr.de`)";
      "traefik.http.routers.zabbix.tls.certresolver" = "myresolver";
      "traefik.http.services.zabbix.loadbalancer.server.port" = "8080";
    };
    log-driver = "journald";
    extraOptions = [
      "--network-alias=zabbix-web"
      "--network=zabbix_default"
      "--network=proxy"
    ];
    dependsOn = ["zabbix-server"];
  };

  # Service configurations
  systemd.services."podman-zabbix-db" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-zabbix_default.service"
    ];
    requires = [
      "podman-network-zabbix_default.service"
    ];
    partOf = [
      "podman-compose-zabbix-root.target"
    ];
    wantedBy = [
      "podman-compose-zabbix-root.target"
    ];
  };

  systemd.services."podman-zabbix-server" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-zabbix_default.service"
      "podman-zabbix-db.service"
    ];
    requires = [
      "podman-network-zabbix_default.service"
    ];
    partOf = [
      "podman-compose-zabbix-root.target"
    ];
    wantedBy = [
      "podman-compose-zabbix-root.target"
    ];
  };

  systemd.services."podman-zabbix-web" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-zabbix_default.service"
      "podman-zabbix-server.service"
    ];
    requires = [
      "podman-network-zabbix_default.service"
    ];
    partOf = [
      "podman-compose-zabbix-root.target"
    ];
    wantedBy = [
      "podman-compose-zabbix-root.target"
    ];
  };

  # Networks
  systemd.services."podman-network-zabbix_default" = {
    path = [pkgs.podman];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f zabbix_default";
    };
    script = ''
      podman network inspect zabbix_default || podman network create zabbix_default
    '';
    partOf = ["podman-compose-zabbix-root.target"];
    wantedBy = ["podman-compose-zabbix-root.target"];
  };

  # Root service
  systemd.targets."podman-compose-zabbix-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = ["multi-user.target"];
  };
}
