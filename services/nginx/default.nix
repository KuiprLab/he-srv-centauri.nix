{ config, pkgs, ... }:
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "me@dinama.dev";
  };
  
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    
    # Handle HTTP and HTTPS proxying similar to HAProxy setup
    # This setting will ensure proper forwarding of client IP addresses
    proxyResolveWhileRunning = false;
    
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
    
    virtualHosts = {
      # HTTP virtual hosts
      "hl.kuipr.de" = {
        serverName = "~^(.*\.)?hl\.kuipr\.de$";
        listenAddresses = [ "0.0.0.0" ];
        listen = [{ port = 80; addr = "0.0.0.0";}];
        locations."/".proxyPass = "http://192.168.1.69:80";
        locations."/".proxyWebsockets = true;
        forceSSL = false; # We're handling SSL at the TCP level
        enableACME = false; # Not needed with TCP SSL passthrough
      };
      
      "k8s.kuipr.de" = {
        serverName = "~^(.*\.)?k8s\.kuipr\.de$";
        listenAddresses = [ "0.0.0.0" ];
        listen = [{ port = 80; addr = "0.0.0.0"; }];
        locations."/".proxyPass = "http://192.168.1.200:80";
        locations."/".proxyWebsockets = true;
        forceSSL = false; # We're handling SSL at the TCP level
        enableACME = false; # Not needed with TCP SSL passthrough
      };
      
      # Default HTTP backend for all other domains
      "default" = {
        default = true;
        listenAddresses = [ "0.0.0.0" ];
        listen = [{ port = 80; addr = "0.0.0.0"; }];
        locations."/".proxyPass = "http://127.0.0.1:8081";
        locations."/".proxyWebsockets = true;
      };
    };
  };
  
  
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
