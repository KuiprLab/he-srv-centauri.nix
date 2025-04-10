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
    # ./sops.nix
    ./hardware-configuration.nix
    ./disko-config.nix
    # (import ./docker.nix {inherit pkgs lib config;})
  ];

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  boot.loader.grub = {
    enable = true;
    device = "nodev"; # For EFI systems
    efiSupport = true;
    efiInstallAsRemovable = true; # Important for some cloud environments
  };

  users.users = {
    ubuntu = {
      isNormalUser = true;
      extraGroups = ["wheel"];
      createHome = true;
      home = "/home/ubuntu";
      initialHashedPassword = "$y$j9T$2DyEjQxPoIjTkt8zCoWl.0$3mHxH.fqkCgu53xa0vannyu4Cue3Q7xL4CrUhMxREKC"; # Password.123
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILaVcv9/0U1k4q08PiGE9lLd3QFxOyy3eqpne9y9CWQq"
      ];
    };

    root = {
      hashedPassword = "!";
      extraGroups = ["wheel"];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILaVcv9/0U1k4q08PiGE9lLd3QFxOyy3eqpne9y9CWQq"
      ];
    };
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
      # 8081 # Traefik HTTP
      # 8443 # Traefik HTTPS
    ];
  };

  # Base system packages
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    wget
    htop
    dig
  ];

  # Enable SSH for remote access
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      PermitEmptyPasswords = "yes";
    };
  };

  # Security hardening
  security = {
    sudo.wheelNeedsPassword = false;
  };

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    optimise = {
      automatic = true;
      dates = ["03:45"]; # Optional; allows customizing optimisation schedule
    };
    settings = {
      auto-optimise-store = true;
      sandbox = false;
      # Add Cachix binary caches (replace "your-cache" with your Cachix cache name)
      trusted-binary-caches = [
        "https://cache.nixos.org/"
      ];

      substituters = [
        "https://cache.nixos.org"
        # nix community's cache server
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };
}
