{
  config,
  pkgs,
  ...
}: {
  security.acme = {
    acceptTerms = true;
    defaults.email = "me@dinama.dev";
  };

  services.anubis = {
    defaultOptions = {
      botPolicy = {dnsbl = false;};
      settings.DIFFICULTY = 3;
    };
    instances = {
      default.settings.TARGET = "http://127.0.0.1:8081";
    };
  };

  users.users.nginx.extraGroups = [ config.users.groups.anubis.name ];
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts = {
      # HTTP virtual hosts
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

      # Default HTTP backend for all other domains
      "default" = {
        default = true;
        listen = [
          {
            port = 443;
            addr = "";
          }
        ];
        # locations."/".proxyPass = "http://127.0.0.1:8081";
        locations."/".proxyPass = "http://unix:${config.services.anubis.instances.default.settings.BIND}";
        locations."/".proxyWebsockets = true;
      };
    };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
