{ config, pkgs, ... }: {

  #### ACME / global Anubis defaults ####
  security.acme = {
    acceptTerms = true;
    defaults.email = "me@dinama.dev";
  };
  services.anubis.defaultOptions = {
    botPolicy = { dnsbl = false; };
    settings.DIFFICULTY = 3;
  };

  #### Three Anubis instances: hl, k8s, fallback ####
  services.anubis = {
    instances = {
      hl = {
        settings = {
          TARGET = "http://192.168.1.69:80";
          BIND    = "/run/anubis/hl.sock";
          # BIND_NETWORK = "unix";  # default
        };
      };
      k8s = {
        settings = {
          TARGET = "http://192.168.1.200:80";
          BIND    = "/run/anubis/k8s.sock";
        };
      };
      default = {
        settings = {
          TARGET = "http://127.0.0.1:8081";
          BIND    = "/run/anubis/default.sock";
        };
      };
    };
  };

  #### Give nginx access to all Anubis sockets ####
  users.users.nginx.extraGroups = [
    config.users.groups.anubis.name
  ];

  #### Nginx: HTTP vhosts proxying into the matching Anubis socket ####
  services.nginx = {
    enable = true;
    recommendedGzipSettings      = true;
    recommendedOptimisation      = true;
    recommendedProxySettings     = true;
    recommendedTlsSettings       = true;
    stream.enable                = true;  # for TCP passthrough if you need it
    proxyResolveWhileRunning     = false;

    streamConfig = ''  # (keep your TCP/SNI passthrough here) '' ;

    virtualHosts = {

      # hl.kuipr.de → Anubis hl.sock → backend 192.168.1.69:80
      "hl.kuipr.de" = {
        serverName        = "~^(.*\\.)?hl\\.kuipr\\.de$";
        listenAddresses   = [ "0.0.0.0" ];
        listen            = [ { addr = "0.0.0.0"; port = 80; } ];
        locations."/" = {
          proxyPass       = "http://unix:/run/anubis/hl.sock:";
          proxyWebsockets = true;
        };
        forceSSL          = false;
        enableACME        = false;
      };

      # k8s.kuipr.de → Anubis k8s.sock → backend 192.168.1.200:80
      "k8s.kuipr.de" = {
        serverName        = "~^(.*\\.)?k8s\\.kuipr\\.de$";
        listenAddresses   = [ "0.0.0.0" ];
        listen            = [ { addr = "0.0.0.0"; port = 80; } ];
        locations."/" = {
          proxyPass       = "http://unix:/run/anubis/k8s.sock:";
          proxyWebsockets = true;
        };
        forceSSL          = false;
        enableACME        = false;
      };

      # fallback/default → Anubis default.sock → your fallback service
      "default" = {
        default           = true;
        listen            = [ { addr = "127.0.0.1"; port = 8081; } ];
        locations."/" = {
          proxyPass       = "http://unix:/run/anubis/default.sock:";
          proxyWebsockets = true;
        };
      };
    };
  };

  #### Firewall ####
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
