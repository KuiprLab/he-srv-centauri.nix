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

  # Create directory structure for docker-compose and services
  system.activationScripts.dockerCompose = ''
    mkdir -p /etc/docker-compose/stacks/{traefik,authentik}
    mkdir -p /var/lib/docker-compose-secrets
    mkdir -p /var/lib/traefik/{letsencrypt,logs,config}
    mkdir -p /var/lib/authentik/{media,templates,certs,postgresql}
    chown -R 1000:1000 /var/lib/authentik
    chown -R root:root /var/lib/traefik
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
          -e WATCHTOWER_NOTIFICATION_URL="$(cat ${config.sops.secrets.discord-webhook.path})@" \
          -e WATCHTOWER_NOTIFICATION_REPORT=true \
          -e WATCHTOWER_CLEANUP=true \
          -e WATCHTOWER_SCHEDULE="0 0 4 * * *" \
          containrrr/watchtower
      '';
      ExecStop = "${pkgs.docker}/bin/docker stop watchtower";
    };
    environment = {
      DOCKER_HOST = "unix:///var/run/docker.sock";
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

        # Create environment files from sops secrets
        cat ${config.sops.secrets.traefik-env.path} > traefik/.env
        cat ${config.sops.secrets.authentik-env.path} > authentik/.env

        # Start key stacks first (e.g., traefik and authentik)
        for file in traefik.yaml authentik.yaml; do
          if [ -f "$file" ]; then
            echo "Starting stack: $file"
            ${pkgs.docker-compose}/bin/docker-compose -f "$file" up -d
          fi
        done

        # Now start all other stacks found dynamically in the directory
        for file in *.yaml; do
          if [ "$file" != "traefik.yaml" ] && [ "$file" != "authentik.yaml" ]; then
            # Get the stack name without .yaml extension
            stack_name="$(basename "$file" .yaml)"
            
            # If a sops secret exists for this stack, create its .env file
            if [ -f "${config.sops.secrets."$stack_name-env".path}" ]; then
              mkdir -p "$stack_name"
              cat "${config.sops.secrets."$stack_name-env".path}" > "$stack_name/.env"
            fi

            echo "Starting stack: $file"
            ${pkgs.docker-compose}/bin/docker-compose -f "$file" up -d
          fi
        done
      '';
    };
    environment = {
      DOCKER_HOST = "unix:///var/run/docker.sock";
    };
  };
}
