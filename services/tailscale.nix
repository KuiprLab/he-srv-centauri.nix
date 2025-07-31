{
  services.tailscale.enable = true;
  services.zabbixAgent = {
    enable = true;
    openFirewall = true;
    server = "100.106.68.78";
    settings = {
      Hostname = "he-srv-centauri";
      ServerActive = "100.106.68.78";
    };
  };
}
