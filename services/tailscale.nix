{
  services.tailscale.enable = true;
  services.zabbixAgent = {
    enable = true;
    openFirewall = true;
    settings = {
      Hostname = "he-srv-centauri";
      ServerActive = "192.168.1.177";
      Server = "127.0.0.1,192.168.1.177";
    };
  };
}
