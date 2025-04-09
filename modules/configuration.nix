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
    ./hardware-configuration.nix
    ./disko-config.nix
    (import ./docker.nix {inherit pkgs lib config;})
  ];

  ###############################
  # Networking and Firewall Setup
  ###############################

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  boot.loader.grub.enable = true;

  services.openssh.enable = true;


  users.users.ubuntu = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    createHome = true;
    group = "users";
    home = "/home/ubuntu";
    shell = "/bin/bash";

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILaVcv9/0U1k4q08PiGE9lLd3QFxOyy3eqpne9y9CWQq"
    ];
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  system.stateVersion = "24.11";

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22 # SSH
      80 # HTTP
      443 # HTTPS
      8081 # Traefik HTTP
      8443 # Traefik HTTPS
      # 8181  # Traefik Dashboard
    ];
  };
}
