{pkgs, ...}: {
  networking = {
    hostName = "he-srv-centauri";
    nameservers = ["9.9.9.9"];
  };

  system.stateVersion = "23.11";

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
      PermitRootLogin = "no";
      PasswordAuthentication = true;
      PermitEmptyPasswords = "yes";
    };
  };

  # Security hardening
  security = {
    sudo.wheelNeedsPassword = true;
    auditd.enable = true;
  };

  # Create a default user with SSH access
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
