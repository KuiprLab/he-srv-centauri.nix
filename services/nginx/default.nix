{ config, pkgs, ... }:
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "me@dinama.dev";
  };
  
  # Anubis service configuration
 services.anubis = {
    package = pkgs.anubis;
    instances = {
      "nginx" = {
        settings = {
          TARGET = "unix:///run/nginx/nginx.sock";
          DIFFICULTY = 5; # Set difficulty level
          # Explicitly define socket path and settings
          BIND = "/run/anubis/nginx/nginx.sock";
          BIND_NETWORK = "unix";
          SOCKET_MODE = "0660";
        };
        # If you need a custom bot policy, add it here
        # botPolicy = { ... };
      };
    };
  };
  # Make sure nginx has the proper permissions to access the anubis socket
  users.users.nginx.extraGroups = [ config.users.groups.anubis.name ];
  
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    
    # Handle HTTP and HTTPS proxying similar to HAProxy setup
    # This setting will ensure proper forwarding of client IP addresses
    proxyResolveWhileRunning = false;
    
    # Add Anubis upstream configuration
    appendHttpConfig = ''
      # Define Anubis upstream
      upstream anubis {
        # This uses the socket path from the Anubis instance
        server unix:${config.services.anubis.instances.nginx.settings.BIND};
      }
    '';
    
    # Stream configuration to handle TCP traffic like HAProxy does
    streamConfig = ''
      # This mimics HAProxy's TCP mode behavior
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
    
    # Create a server block for the backend socket that Anubis will forward to
    # This is where all the actual HTTP routing happens after Anubis filtering
    virtualHosts = {
      # HTTP virtual hosts
      "hl.kuipr.de" = {
        serverName = "~^(.*\.)?hl\.kuipr\.de$";
        listenAddresses = [ "0.0.0.0" ];
        listen = [{ port = 80; addr = "0.0.0.0";}];
        # Route through Anubis instead of directly to backend
        locations."/".proxyPass = "http://anubis";
        locations."/".extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
        '';
        locations."/".proxyWebsockets = true;
        forceSSL = false; # We're handling SSL at the TCP level
        enableACME = false; # Not needed with TCP SSL passthrough
      };
      
      "k8s.kuipr.de" = {
        serverName = "~^(.*\.)?k8s\.kuipr\.de$";
        listenAddresses = [ "0.0.0.0" ];
        listen = [{ port = 80; addr = "0.0.0.0"; }];
        # Route through Anubis instead of directly to backend
        locations."/".proxyPass = "http://anubis";
        locations."/".extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
        ''; 
        locations."/".proxyWebsockets = true;
        forceSSL = false; # We're handling SSL at the TCP level
        enableACME = false; # Not needed with TCP SSL passthrough
      };
      
      # Default HTTP backend for all other domains
      "default" = {
        default = true;
        listenAddresses = [ "0.0.0.0" ];
        listen = [{ port = 80; addr = "0.0.0.0"; }];
        # Route through Anubis instead of directly to backend
        locations."/".proxyPass = "http://anubis";
        locations."/".extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
        '';
        locations."/".proxyWebsockets = true;
      };
      
      # Create backend server blocks that listen on UNIX socket for each virtual host
      "hl.kuipr.de-backend" = {
        serverName = "hl.kuipr.de";
        listen = [{ port = 0; addr = "unix:/run/nginx/nginx.sock"; }];
        locations."/".proxyPass = "http://192.168.1.69:80";
        locations."/".proxyWebsockets = true;
      };
      
      "k8s.kuipr.de-backend" = {
        serverName = "k8s.kuipr.de";
        listen = [{ port = 0; addr = "unix:/run/nginx/nginx.sock"; }];
        locations."/".proxyPass = "http://192.168.1.200:80";
        locations."/".proxyWebsockets = true;
      };
      
      "default-backend" = {
        default = true;
        listen = [{ port = 0; addr = "unix:/run/nginx/nginx.sock"; }];
        locations."/".proxyPass = "http://127.0.0.1:8081";
        locations."/".proxyWebsockets = true;
      };
    };
  };
  
  # Ensure the required runtime directories exist for Nginx
  systemd.tmpfiles.rules = [
    "d /run/nginx 0755 nginx nginx -"
    # Anubis directories are managed by systemd
  ];
  
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
