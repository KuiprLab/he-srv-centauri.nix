{
  services.tailscale.enable = true;
  services.zabbixAgent = {
    enable = true;
    openFirewall = true;
    server = "192.168.1.177";
    settings = {
      Hostname = "he-srv-centauri";
      ServerActive = "192.168.1.177";
    };
  };
}
