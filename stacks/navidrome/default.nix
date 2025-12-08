{
  pkgs,
  lib,
  config,
  ...
}: {
  # Create some host folders
  myFolders = {
    navidrome = {
      path = "/home/ubuntu/navidrome/{data,conf}";
      owner = "ubuntu";
      group = "users";
      mode = "0755";
    };
    icloud = {
      path = "/home/ubuntu/icloud";
      owner = "ubuntu";
      group = "users";
      mode = "0755";
    };
  };

  # Ensure rclone and sops are available on the system
  environment.systemPackages = with pkgs; [rclone sops podman];

  # sops-managed rclone.conf
  sops.secrets."rclone.conf" = {
    sopsFile = ./rclone-icloud.conf;
    format = "binary";
    owner = "ubuntu";
    group = "users";
    mode = "0755";
    key = "";
    restartUnits = ["podman-rclone-icloud.service"];
  };

  # Run rclone as a Podman container to ensure the icloud backend is available
  virtualisation.oci-containers.containers."rclone-icloud" = {
    image = "rclone/rclone:latest";
    volumes = [
      "${config.sops.secrets."rclone.conf".path}:/config/rclone/rclone.conf:rw"
      "/home/ubuntu/icloud:/data:rw,rshared"
    ];
    cmd = [ "mount" "icloud:Documents/03 Resources/Music" "/data" "--config" "/config/rclone/rclone.conf" "--allow-other" "--vfs-cache-mode" "full" "--dir-cache-time" "72h" "--poll-interval" "15s" ];
    log-driver = "journald";
    extraOptions = [
      "--cap-add=SYS_ADMIN"
      "--device=/dev/fuse:/dev/fuse:rwm"
      "--security-opt=apparmor:unconfined"
      "--network-alias=rclone-icloud"
      "--network=navidrome_default"
      "--network=proxy"
    ];
  };

  systemd.services."podman-rclone-icloud" = {
    serviceConfig = { Restart = lib.mkOverride 90 "always"; };
    after = [ "podman-network-navidrome_default.service" ];
    requires = [ "podman-network-navidrome_default.service" ];
    partOf = [ "podman-compose-navidrome-root.target" ];
    wantedBy = [ "podman-compose-navidrome-root.target" ];
  };


  # Podman network for navidrome
  systemd.services."podman-network-navidrome_default" = {
    path = [pkgs.podman];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f navidrome_default";
    };
    script = ''
      podman network inspect navidrome_default || podman network create navidrome_default
    '';
    wantedBy = ["podman-compose-navidrome-root.target"];
    partOf = ["podman-compose-navidrome-root.target"];
  };

  # Navidrome container
  virtualisation.oci-containers.containers."navidrome" = {
    image = "navidrome/navidrome:latest";
    environment = {
      "NAVIDROME_LOG_LEVEL" = "info";
    };
    volumes = [
      "/home/ubuntu/icloud:/music:ro"
      "/home/ubuntu/navidrome/data:/data:rw"
      "/home/ubuntu/navidrome/conf:/config:rw"
    ];
    user = "0:0";
    log-driver = "journald";
    extraOptions = [
      "--network-alias=navidrome"
      "--network=navidrome_default"
      "--network=proxy"
    ];
    labels = {
      "io.containers.autoupdate" = "registry";
      "traefik.enable" = "true";
      "traefik.http.routers.navidrome.entrypoints" = "anubis";
      "traefik.http.routers.navidrome.rule" = "Host(`music.kuipr.de`)";
      "traefik.http.services.navidrome.loadbalancer.server.port" = "4533";
    };
  };

  # Podman root target to manage lifecycle
  systemd.targets."podman-compose-navidrome-root" = {
    unitConfig = {Description = "Root target generated for navidrome.";};
    wantedBy = ["multi-user.target"];
  };

  # Ensure navidrome container starts after rclone mount
  systemd.services."podman-navidrome" = {
    serviceConfig = {Restart = lib.mkOverride 90 "always";};
    after = ["podman-rclone-icloud.service" "podman-network-navidrome_default.service"];
    requires = ["podman-rclone-icloud.service" "podman-network-navidrome_default.service"];
    partOf = ["podman-compose-navidrome-root.target"];
    wantedBy = ["podman-compose-navidrome-root.target"];
  };
}
