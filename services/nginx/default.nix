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

    # Define Anubis upstream
    upstreams."anubis" = {
      servers = {
        "127.0.0.1:8923" = {};
      };
    };

    virtualHosts = {
      # HTTP redirects for all domains
      "hl.kuipr.de" = {
        serverName = "~^(.*\.)?hl\.kuipr\.de$";
        locations."/".return = "301 https://$host$request_uri";
      };

      "k8s.kuipr.de" = {
        serverName = "~^(.*\.)?k8s\.kuipr\.de$";
        locations."/".return = "301 https://$host$request_uri";
      };

      # HTTPS virtual hosts with Anubis integration
      "hl.kuipr.de-ssl" = {
        serverName = "~^(.*\.)?hl\.kuipr\.de$";
        forceSSL = true;
        enableACME = true;
        locations."/".proxyPass = "http://anubis";
        locations."/".proxyWebsockets = true;
      };

      "k8s.kuipr.de-ssl" = {
        serverName = "~^(.*\.)?k8s\.kuipr\.de$";
        forceSSL = true;
        enableACME = true;
        locations."/".proxyPass = "http://anubis";
        locations."/".proxyWebsockets = true;
      };

      # Default HTTPS backend
      "default" = {
        default = true;
        forceSSL = true;
        enableACME = true;
        locations."/".proxyPass = "http://anubis";
        locations."/".proxyWebsockets = true;
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # Ensure Anubis socket directory exists
  systemd.tmpfiles.rules = [
    "d /run/anubis 0755 anubis anubis"
  ];
}
