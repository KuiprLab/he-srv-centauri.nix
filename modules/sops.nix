{
  config,
  pkgs,
  lib,
  ...
}: {
  # Enable sops
  sops = {
    # Path to the default sops file
    defaultSopsFile = ../secrets/secrets.yaml;

    # Configure default key to use for encryption
    age.keyFile = "/var/lib/sops-nix/key.txt";

    # Generate a key if it doesn't exist
    age.generateKey = true;

    # Define secrets
    secrets = {
      # Discord webhook for notifications
      "discord-webhook" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      # Authentication platform credentials
      "authentik-env" = {
        owner = "root";
        group = "root";
        mode = "0400";
        path = "/etc/docker-compose/stacks/.env";
      };

      # Database credentials
      "postgres-password" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      # WireGuard VPN configuration
      "wireguard-env" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      "wireguard-key" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      # qBittorrent credentials
      "qbittorrent-credentials" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      # Traefik environment variables
      "traefik-env" = {
        owner = "root";
        group = "root";
        mode = "0400";
        path = "/etc/docker-compose/stacks/traefik/.env";
      };

      # Unpacker configuration
      "unpacker-env" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      # Decluttarr configuration (for media management)
      "decluttarr-env" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      # API keys for media servers
      "sonarr-api-key" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      "radarr-api-key" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };

      "lidarr-api-key" = {
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    # Define templates for substituting secrets in configuration files
    templates = {
      # Process qBittorrent configuration with secrets
      "qbittorrent-yaml" = {
        path = "/etc/docker-compose/stacks/qbittorrent.yaml";
        owner = "root";
        group = "root";
        mode = "0400";
        content = ''
          ${builtins.readFile ../stacks/qbittorrent.yaml}
        '';
      };

      # Process starr stack with secrets
      "starr-yaml" = {
        path = "/etc/docker-compose/stacks/starr.yaml";
        owner = "root";
        group = "root";
        mode = "0400";
        content = ''
          ${builtins.readFile ../stacks/starr.yaml}
        '';
      };

      # Process authentik stack with secrets
      "authentik-yaml" = {
        path = "/etc/docker-compose/stacks/authentik.yaml";
        owner = "root";
        group = "root";
        mode = "0400";
        content = ''
          ${builtins.readFile ../stacks/authentik.yaml}
        '';
      };

      # Process traefik stack with secrets
      "traefik-yaml" = {
        path = "/etc/docker-compose/stacks/traefik.yaml";
        owner = "root";
        group = "root";
        mode = "0400";
        content = ''
          ${builtins.readFile ../stacks/traefik.yaml}
        '';
      };
    };
  };

  # Install sops and related tools
  environment.systemPackages = with pkgs; [
    sops
    age
    ssh-to-age
    gnupg
    jq
    yq
  ];
}
