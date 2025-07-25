# Auto-generated using compose2nix v0.3.2-pre.
{
  pkgs,
  lib,
  config,
  ...
}: {
  # Runtime
  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
    dockerCompat = true;
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
  virtualisation.oci-containers.containers."dozzle" = {
    image = "amir20/dozzle:latest";
    volumes = [
      "/run/podman/podman.sock:/var/run/docker.sock:rw"
    ];
    # ports = [
    #   "8080:8080/tcp"
    # ];
    cmd = [
      "--enable-shell"
    ];
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.dozzle.entrypoints" = "websecure";
      "traefik.http.routers.dozzle.middlewares" = "authelia@docker";
      "traefik.http.routers.dozzle.rule" = "Host(`dozzle.kuipr.de`)";
      "traefik.http.routers.dozzle.tls.certresolver" = "myresolver";
      "traefik.http.services.dozzle.loadbalancer.server.port" = "8080";
    };
    log-driver = "journald";
    extraOptions = [
      "--network-alias=dozzle"
      "--network=dozzle_default"
    ];
  };
  systemd.services."podman-dozzle" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "no";
    };
    after = [
      "podman-network-dozzle_default.service"
    ];
    requires = [
      "podman-network-dozzle_default.service"
    ];
    partOf = [
      "podman-compose-dozzle-root.target"
    ];
    wantedBy = [
      "podman-compose-dozzle-root.target"
    ];
  };

  # Networks
  systemd.services."podman-network-dozzle_default" = {
    path = [pkgs.podman];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f dozzle_default";
    };
    script = ''
      podman network inspect dozzle_default || podman network create dozzle_default
    '';
    partOf = ["podman-compose-dozzle-root.target"];
    wantedBy = ["podman-compose-dozzle-root.target"];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-dozzle-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = ["multi-user.target"];
  };
}
