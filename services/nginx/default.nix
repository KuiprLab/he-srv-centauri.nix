{ config, pkgs, ... }:

{
      security.acme = {
        acceptTerms = true;
        defaults.email = "me@dinama.dev";
      };

services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts = {
      # Wildcard for any subdomain under hl.kuipr.de
      "hl.kuipr.de" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://192.168.1.69:80";
        locations."/".proxyWebsockets = true;
        locations."/".extraConfig = ''
          proxy_ssl_server_name on;
          proxy_pass_header Authorization;
        '';
      };

      # Wildcard for any subdomain under k8s.kuipr.de
      "k8s.kuipr.de" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://192.168.1.200:80";
        locations."/".proxyWebsockets = true;
        locations."/".extraConfig = ''
          proxy_ssl_server_name on;
          proxy_pass_header Authorization;
        '';
      };

    };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # Optional: if you want a custom Nginx configuration outside of the default virtualHosts.
  # Ensure to configure `nginx.conf` as needed.
  # services.nginx.extraConfig = ''
  #   # Additional Nginx configuration if needed
  # '';
}
