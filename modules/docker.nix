{
  pkgs,
  config,
  ...
}: {
  ############################
  # Docker and Docker Compose
  ############################

  # Enable docker with auto-pruning support.
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = ["--all"];
    };
  };

  # Create directory structure for docker-compose
  system.activationScripts.dockerCompose = ''
    mkdir -p /etc/docker-compose/stacks
    mkdir -p /var/lib/docker-compose-secrets
  '';

  # Service to run the main docker-compose file at startup
  systemd.services.docker-compose-stacks = {
    description = "Docker Compose Application Service";
    wantedBy = ["multi-user.target"];
    requires = ["docker.service"];
    after = ["docker.service" "network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      WorkingDirectory = "/etc/docker-compose";
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose -f /etc/docker-compose/docker-compose.yaml up -d";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose -f /etc/docker-compose/docker-compose.yaml down";
      TimeoutStartSec = "0";
    };
  };

  # Watchtower service for automatic Docker container updates with Discord notifications.
  systemd.services.watchtower = {
    description = "Watchtower Docker Container Updater";
    wantedBy = ["multi-user.target"];
    requires = ["docker.service"];
    after = ["docker.service" "network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStartPre = "-${pkgs.docker}/bin/docker rm -f watchtower";
      ExecStart = ''
        ${pkgs.docker}/bin/docker run -d \
          --name watchtower \
          --restart unless-stopped \
          -v /var/run/docker.sock:/var/run/docker.sock \
          -e WATCHTOWER_NOTIFICATIONS=shoutrrr \
          -e WATCHTOWER_NOTIFICATION_URL="discord://$DISCORD_WEBHOOK_TOKEN@" \
          -e WATCHTOWER_NOTIFICATION_REPORT=true \
          -e WATCHTOWER_CLEANUP=true \
          -e WATCHTOWER_SCHEDULE="0 0 4 * * *" \
          containrrr/watchtower
      '';
      ExecStop = "${pkgs.docker}/bin/docker stop watchtower";
      EnvironmentFile = config.sops.secrets.discord-webhook.path;
    };
  };

  ###################################
  # Main Docker Compose Configuration
  ###################################

  # Setup main docker-compose file.
  environment.etc."docker-compose/docker-compose.yaml".text = ''
    version: '3'

    services:
      watchtower:
        image: containrrr/watchtower
        container_name: watchtower
        restart: unless-stopped
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock
        environment:
          - WATCHTOWER_NOTIFICATIONS=shoutrrr
          - WATCHTOWER_NOTIFICATION_URL=${config.sops.placeholder.discord-webhook}
          - WATCHTOWER_NOTIFICATION_REPORT=true
          - WATCHTOWER_CLEANUP=true
          - WATCHTOWER_SCHEDULE=0 0 4 * * *
        networks:
          - proxy

    networks:
      proxy:
        external: true
  '';

  # Copy all stacks from the local ./stacks directory dynamically
  environment.etc."docker-compose/stacks".source = ../stacks;

  ######################################################
  # Dynamic Docker Stack Initialization on System Start
  ######################################################

  systemd.services.initialize-docker-stacks = {
    description = "Initialize Docker Networks and Stacks";
    wantedBy = ["multi-user.target"];
    requires = ["docker.service"];
    after = ["docker.service" "network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStart = pkgs.writeShellScript "initialize-docker-stacks" ''
        set -e

        # Create the proxy network if it doesn't exist.
        if ! ${pkgs.docker}/bin/docker network inspect proxy &>/dev/null; then
          ${pkgs.docker}/bin/docker network create proxy
        fi

        cd /etc/docker-compose/stacks

        # Start key stacks first (e.g., traefik and authentik). Adjust as needed.
        for file in traefik.yaml authentik.yaml; do
          if [ -f "$file" ]; then
            echo "Starting stack: $file"
            ${pkgs.docker-compose}/bin/docker-compose -f "$file" up -d
          fi
        done

        # Now start all other stacks found dynamically in the directory.
        for file in *.yaml; do
          if [ "$file" != "traefik.yaml" ] && [ "$file" != "authentik.yaml" ]; then
            echo "Starting stack: $file"
            ${pkgs.docker-compose}/bin/docker-compose -f "$file" up -d
          fi
        done
      '';
    };
  };
}
