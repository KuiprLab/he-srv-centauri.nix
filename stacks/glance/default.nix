# Auto-generated using compose2nix v0.3.2-pre.
{ pkgs, lib, config, ... }:

{
  myFolders = {
    glance = {
      path = "/home/ubuntu/glance";
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
  virtualisation.oci-containers.containers."glance" = {
    image = "glanceapp/glance";
    volumes = [
      "/home/ubuntu/glance:/app/config:rw"
      "${./glance.yml}:/app/config/glance.yml:rw"
      "${./homelab.yml}:/app/config/homelab.yml:rw"
      "${./feed.yml}:/app/config/feed.yml:rw"
    ];
    # ports = [
    #   "8080:8080/tcp"
    # ];

    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.glance.entrypoints" = "websecure";
      "traefik.http.routers.glance.rule" = "Host(`dash.kuipr.de`)";
      "traefik.http.routers.glance.middlewares" = "authelia@docker";
      "traefik.http.routers.glance.tls.certresolver" = "myresolver";
      "traefik.http.services.glance.loadbalancer.server.port" = "8080";
    };
    log-driver = "journald";
    extraOptions = [
      "--network-alias=glance"
      "--network=glance_default"
      "--network=proxy"
    ];
  };
  systemd.services."podman-glance" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-glance_default.service"
    ];
    requires = [
      "podman-network-glance_default.service"
    ];
    partOf = [
      "podman-compose-glance-root.target"
    ];
    wantedBy = [
      "podman-compose-glance-root.target"
    ];
  };

  # Networks
  systemd.services."podman-network-glance_default" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f glance_default";
    };
    script = ''
      podman network inspect glance_default || podman network create glance_default
    '';
    partOf = [ "podman-compose-glance-root.target" ];
    wantedBy = [ "podman-compose-glance-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-glance-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
