{ pkgs, lib, config, ... }:
let
  updateScript = pkgs.writeShellScriptBin "update-containers" ''
    export PATH=${lib.makeBinPath [ pkgs.docker ]}:$PATH
    set -euo pipefail

    echo "Starting container update process at $(date)"

    # Pull all images (this will update existing ones)
    echo "Pulling all Docker images..."
    sudo docker images | awk '(NR>1) && ($2!~/none/) {print $1":"$2}' | xargs -L1 sudo docker pull

    # Restart all containers
    echo "Restarting all containers..."
    sudo systemctl restart podman-*

    echo "Container update process completed at $(date)"
  '';
in
{
  systemd.timers.update-containers = {
    timerConfig = {
      Unit = "update-containers.service";
      OnCalendar = "weekly";
      Persistent = true;
    };
    wantedBy = [ "timers.target" ];
  };

  systemd.services.update-containers = {
    description = "Update all Docker images and restart all containers";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe updateScript;
      User = "root";
    };
    wants = [ "docker.service" ];
    after = [ "docker.service" "network-online.target" ];
  };
}
