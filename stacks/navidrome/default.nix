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
    music = {
      path = "/home/ubuntu/music";
      owner = "ubuntu";
      group = "users";
      mode = "0755";
    };
  };

  # Ensure sops, podman and cifs-utils are available on the system
  environment.systemPackages = with pkgs; [sops podman cifs-utils];

  # SMB credentials managed by sops; fill values in `stacks/navidrome/smbcredentials` and encrypt with sops
  sops.secrets."navidrome-smbcredentials" = {
    sopsFile = ./smbcredentials.txt;
    format = "binary";
    owner = "root";
    group = "root";
    mode = "0600";
    key = "";
    restartUnits = ["smb-mount-music.service"];
  };

  # Systemd service to mount the SMB share to /home/ubuntu/music
  systemd.services."smb-mount-music" = {
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "/bin/umount -f /home/ubuntu/music || true";
    };
    path = [pkgs.cifs-utils];
    script = ''
      mkdir -p /home/ubuntu/music
      mountpoint -q /home/ubuntu/music || mount -t cifs "//192.168.0.58/data" /home/ubuntu/music -o credentials=${config.sops.secrets."navidrome-smbcredentials".path},uid=1000,gid=100,vers=3.0
    '';
    wantedBy = ["podman-compose-navidrome-root.target"];
    partOf = ["podman-compose-navidrome-root.target"];
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
      "/home/ubuntu/music:/music:ro"
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

  # Ensure navidrome container starts after the SMB mount
  systemd.services."podman-navidrome" = {
    serviceConfig = {Restart = lib.mkOverride 90 "always";};
    after = ["smb-mount-music.service" "podman-network-navidrome_default.service"];
    requires = ["smb-mount-music.service" "podman-network-navidrome_default.service"];
    partOf = ["podman-compose-navidrome-root.target"];
    wantedBy = ["podman-compose-navidrome-root.target"];
  };
}
