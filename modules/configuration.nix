{
  pkgs,
  lib,
  modulesPath,
  config,
  ...
}: {

  # Import additional configuration files
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./settings.nix
    ./sops.nix
    (import ./docker.nix { inherit pkgs lib config;})
  ];


  ###############################
  # Networking and Firewall Setup
  ###############################

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22    # SSH
      80    # HTTP
      443   # HTTPS
      8081  # Traefik HTTP
      8443  # Traefik HTTPS
      # 8181  # Traefik Dashboard
    ];
  };

}

