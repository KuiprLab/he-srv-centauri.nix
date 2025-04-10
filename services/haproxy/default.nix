_: {
  services.haproxy = {
    enable = true;
    config = builtins.readFile ./haproxy.cfg;
    configPath = "/run/haproxy/haproxy.cfg";  # Add this line
  };
}
