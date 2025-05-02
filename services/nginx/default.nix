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

      "example.com" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:12345";
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
