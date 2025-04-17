# Auto-generated using compose2nix v0.3.2-pre.
{ pkgs, lib, config, ... }:

{

  myFolders = {
    kapowarr = {
      path = "/home/ubuntu/kapowarr";
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


  virtualisation.oci-containers.containers."flaresolverr-gluetun" = {
    image = "ghcr.io/flaresolverr/flaresolverr:latest";
    # ports = [
    #   "8191:8191/tcp"
    # ];
    log-driver = "journald";
    extraOptions = [
      "--network=container:gluetun"
    ];
  };
  systemd.services."podman-flaresolverr-gluetun" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-starr_default.service"
    ];
    requires = [
      "podman-network-starr_default.service"
    ];
    partOf = [
      "podman-compose-starr-root.target"
    ];
    wantedBy = [
      "podman-compose-starr-root.target"
    ];
  };

  # Containers
  virtualisation.oci-containers.containers."kapowarr" = {
    image = "mrcas/kapowarr-alpha:latest";
    volumes = [
      "/home/ubuntu/kapowarr:/app/db:rw"
      "/mnt/data/downloads:/app/temp_downloads:rw"
      "/mnt/data/media/comics:/comics-1:rw"
    ];
    dependsOn = [
      "gluetun"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network=container:gluetun"
    ];
  };
  systemd.services."podman-kapowarr" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "no";
    };
    partOf = [
      "podman-compose-kapowarr-root.target"
    ];
    wantedBy = [
      "podman-compose-kapowarr-root.target"
    ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-kapowarr-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
