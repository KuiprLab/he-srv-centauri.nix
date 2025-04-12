# Auto-generated using compose2nix v0.3.2-pre.
{
  pkgs,
  lib,
  config,
  ...
}: {
  sops.secrets."share-notes.env" = {
    sopsFile = ./share-notes.env;
    format = "dotenv";
    key = "";
    restartUnits = ["podman-notesx-server.service"];
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
  virtualisation.oci-containers.containers."notesx-server" = {
    image = "ghcr.io/note-sx/server:latest";
    environmentFiles = [
      "/run/secrets/share-notes.env"
    ];
    volumes = [
      "./db:/notesx/db:rw,Z"
      "./userfiles:/notesx/userfiles:rw,Z"
    ];
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.notesx-server.entrypoints" = "websecure";
      "traefik.http.routers.notesx-server.rule" = "Host(`notes.kuipr.de`)";
      "traefik.http.routers.notesx-server.tls.certresolver" = "myresolver";
      "traefik.http.services.notesx-server.loadbalancer.server.port" = "3000";
    };
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=(wget -qO - http://localhost:3000/v1/ping | grep -q ok) || exit 1"
      "--health-interval=30s"
      "--health-retries=2"
      "--health-start-period=10s"
      "--health-timeout=5s"
      "--network-alias=notesx-server"
      "--network=obsidian-share-notes_default"
      "--network=proxy"
    ];
  };
  systemd.services."podman-notesx-server" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-obsidian-share-notes_default.service"
    ];
    requires = [
      "podman-network-obsidian-share-notes_default.service"
    ];
    partOf = [
      "podman-compose-obsidian-share-notes-root.target"
    ];
    wantedBy = [
      "podman-compose-obsidian-share-notes-root.target"
    ];
  };

  # Networks
  systemd.services."podman-network-obsidian-share-notes_default" = {
    path = [pkgs.podman];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f obsidian-share-notes_default";
    };
    script = ''
      podman network inspect obsidian-share-notes_default || podman network create obsidian-share-notes_default
    '';
    partOf = ["podman-compose-obsidian-share-notes-root.target"];
    wantedBy = ["podman-compose-obsidian-share-notes-root.target"];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-obsidian-share-notes-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = ["multi-user.target"];
  };
}
