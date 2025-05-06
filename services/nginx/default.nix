{
  config,
  pkgs,
  ...
}: {
  sops.secrets."hetzner.env" = {
    sopsFile = ./hetzner.env;
    owner = "ubuntu";
    format = "env";
    key = "";
  };

  security.acme = {
    acceptTerms = true;
    email = "me@dinama.dev";
    certs = {
      "kuipr.de" = {
        dnsProvider = "hetzner";
        credentialsFile = "${config.sops.secrets."hetzner.env".path}";
        dnsPropagationCheck = true;
        domain = "*.kuipr.de";
      };
    };
  };

  services.anubis = {
    instances = {
      default.settings = {
        TARGET = "http://127.0.0.1:8081";
        USE_REMOTE_ADDRESS = true;
      };
    };
  };

  users.users.nginx.extraGroups = [config.users.groups.anubis.name];
  services.nginx = {
    enable = true;
    # recommendedGzipSettings = true;
    # recommendedOptimisation = true;
    # recommendedProxySettings = true;
    # recommendedTlsSettings = true;

    virtualHosts = {
      # HTTP virtual hosts
      # "hl.kuipr.de" = {
      #   serverName = "~^(.*\.)?hl\.kuipr\.de$";
      #   listenAddresses = ["0.0.0.0"];
      #   listen = [
      #     {
      #       port = 80;
      #       addr = "0.0.0.0";
      #     }
      #   ];
      #   locations."/".proxyPass = "http://192.168.1.69:80";
      #   locations."/".proxyWebsockets = true;
      #   forceSSL = false; # We're handling SSL at the TCP level
      #   enableACME = false; # Not needed with TCP SSL passthrough
      # };
      #
      # "k8s.kuipr.de" = {
      #   serverName = "~^(.*\.)?k8s\.kuipr\.de$";
      #   listenAddresses = ["0.0.0.0"];
      #   listen = [
      #     {
      #       port = 80;
      #       addr = "0.0.0.0";
      #     }
      #   ];
      #   locations."/".proxyPass = "http://192.168.1.200:80";
      #   locations."/".proxyWebsockets = true;
      #   forceSSL = false; # We're handling SSL at the TCP level
      #   enableACME = false; # Not needed with TCP SSL passthrough
      # };

      # Default HTTP backend for all other domains
      "kuipr.de" = {
        serverName = "~^([a-z0-9-]+\\.)*kuipr\\.de$";
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://unix:${config.services.anubis.instances.default.settings.BIND}";
          proxyWebsockets = true;
        };

        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
