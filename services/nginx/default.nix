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
        TARGET = "http://127.0.0.1:8081";  # Traefik HTTP endpoint
        USE_REMOTE_ADDRESS = true;
      };
      
      # Create a special instance for Jellyfin to bypass Anubis processing
      jellyfin.settings = {
        TARGET = "http://127.0.0.1:8081";  # Traefik HTTP endpoint
        USE_REMOTE_ADDRESS = true;
        # Minimal processing for Jellyfin traffic
        MAX_BODY_SIZE = 0;  # Unlimited body size
        DISABLE_SECURITY_HEADERS = true;  # Don't add any security headers
      };
    };
  };

  users.users.nginx.extraGroups = [config.users.groups.anubis.name];
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    # Stream configuration to handle TCP/SSL traffic
    streamConfig = ''
      # SSL/TLS passthrough for specific domains
      upstream hl_backend_ssl {
        server 192.168.1.69:443;
      }

      upstream k8s_backend_ssl {
        server 192.168.1.200:443;
      }

      upstream traefik_backend_ssl {
        server 127.0.0.1:8443;
      }

      # SSL/TLS routing based on SNI
      map $ssl_preread_server_name $ssl_backend {
        ~\.hl\.kuipr\.de$ hl_backend_ssl;
        ~\.k8s\.kuipr\.de$ k8s_backend_ssl;
        default traefik_backend_ssl;
      }

      # HTTPS listener
      server {
        listen 443;
        proxy_pass $ssl_backend;
        ssl_preread on;
      }
    '';

    virtualHosts = {
      # HTTP virtual hosts for specific subdomains
      "hl.kuipr.de" = {
        serverName = "~^(.*\.)?hl\.kuipr\.de$";
        listenAddresses = ["0.0.0.0"];
        listen = [
          {
            port = 80;
            addr = "0.0.0.0";
          }
        ];
        locations."/".proxyPass = "http://192.168.1.69:80";
        locations."/".proxyWebsockets = true;
        forceSSL = false; # We're handling SSL at the TCP level
        enableACME = false; # Not needed with TCP SSL passthrough
      };

      "k8s.kuipr.de" = {
        serverName = "~^(.*\.)?k8s\.kuipr\.de$";
        listenAddresses = ["0.0.0.0"];
        listen = [
          {
            port = 80;
            addr = "0.0.0.0";
          }
        ];
        locations."/".proxyPass = "http://192.168.1.200:80";
        locations."/".proxyWebsockets = true;
        forceSSL = false; # We're handling SSL at the TCP level
        enableACME = false; # Not needed with TCP SSL passthrough
      };

      # Special handling for Jellyfin to prevent redirect loops
      "jelly.kuipr.de" = {
        serverName = "~^jelly\.kuipr\.de$";
        forceSSL = true;
        locations."/" = {
          # Use the special jellyfin instance of Anubis
          proxyPass = "http://unix:${config.services.anubis.instances.jellyfin.settings.BIND}";
          proxyWebsockets = true;
        };
        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_read_timeout 300;
          proxy_connect_timeout 300;
          proxy_send_timeout 300;
          # Prevent redirect loops
          proxy_redirect off;
        '';
      };

      # Default HTTP backend for all other domains
      "kuipr.de" = {
        serverName = "~^([a-z0-9-]+\\.)*kuipr\\.de$";
        forceSSL = true;
        
        # Exclude the domains we've already defined
        extraConfig = ''
          if ($host ~* ^(.*\.)?hl\.kuipr\.de$) {
            return 404;
          }
          if ($host ~* ^(.*\.)?k8s\.kuipr\.de$) {
            return 404;
          }
          if ($host ~* ^jelly\.kuipr\.de$) {
            return 404;
          }
        '';

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
