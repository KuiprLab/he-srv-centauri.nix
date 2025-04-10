_: {
  services.haproxy = {
    enable = true;
    config = builtins.readFile ./haproxy.cfg;
<<<<<<< Updated upstream
=======
    configPath = "/run/haproxy/haproxy.cfg"; # Add this line
>>>>>>> Stashed changes
  };
}
