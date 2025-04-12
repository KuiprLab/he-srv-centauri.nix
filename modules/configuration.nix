{
  pkgs,
  modulesPath,
  config,
  ...
}: {
  # Import additional configuration files
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./hardware-configuration.nix
    ./disko-config.nix
  ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = ["--all"];
    };
  };

  opnix = {
    # This is where you put your Service Account token in .env file format, e.g.
    # OP_SERVICE_ACCOUNT_TOKEN="{your token here}"
    # See: https://developer.1password.com/docs/service-accounts/use-with-1password-cli/#get-started
    # This file should have permissions 400 (file owner read only) or 600 (file owner read-write)
    # The systemd script will print a warning for you if it's not
    environmentFile = "/etc/opnix.env";
    # Set the systemd services that will use 1Password secrets; this makes them wait until
    # secrets are deployed before attempting to start the service.
    # systemdWantedBy = [ "my-systemd-service" "homepage-dashboard" ];
    # Specify the secrets you need
    secrets = {
      sops-age = {
        source = "{{ op://OpsVault/he-srv-centauri-sops-key/age }}";
        user = "ubuntu";
        group = "users";
        mode = "0600";
        path = "/home/ubuntu";
      };
      cifs-password = {
        source = "{{ op://OpsVault/Hetzner Storage Box/password }}";
        user = "ubuntu";
        group = "users";
        mode = "0600";
        path = "/home/ubuntu";
      };
    };
  };

  sops = {
    age.keyFile = config.opnix.secrets.sops-age.path; # Point to your actual key location
    age.generateKey = false; # Don't generate a new key
  };

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  networking.hostName = "he-srv-centauri";

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
      initialHashedPassword = "$2y$10$xv/YjFKBVf4quQl.jCdGrO.i1lHX2a.IJC2dQFVzAeCngyD.pP/hC";
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDOrOMsB4HsTcteuorxIiVk+CPOY/gIbfLkV0yLWmI9JS8zVii3ud5kgnzWbUik3M+b3h6FS/j9HqTEJ0jV9DhYp1smBr43dUN3AGeHPCR3MX2cTb+EB8UDwdoyMalMKK18oQ/8dRnv7n9FHuRrrplVb28PIU9Z7pi4AXXMQw7akZjcGomRhmWZ9IP2LSI3d+XJDp0B2TmG7MTeERIAWo1brY4TBp7Bgra66V33XO+o5PtoQqJ1H671OETrCM/4BgIIUoz3twvcGhmrMYqW0RmyodVIvJtvHvSoIeZAWJWz0dKtnhAlN7ZPn1WuOGABPlHUzdj1cPgs0RJC8es+OI+3U9H7Qh6bjLlPK0FtbEX9oCQwTTppuv6Gk78SuQCbAMfdzvNA74ziqjon1qvgy1k2A9d2y9XVIyL0lSJHBDED7OkjkgxKm8qikTSSL5+jQx7QfdTgRmP3k5ZbYM6rBeUgZxxRJAxRlpxZhweTYfSsUyU3luYFXoO6BYAxQ0nWgaiBFJnadwUgh+XRm8tK8x/2ipgnnHBS5fY4P8Lfc/Kegb6Q1GTr4klF5Q2aG5SZj934CZSq/lLM8K3ImQcola6M/LjPAkqCbSHe2gvPjO800JSrsL+47eyMpMHhUfqFno4EXV2mxbUQYu4xkxisSQw1BAdPRsurpMcrzHZg2YbVBQ=="
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
      8081 # Traefik HTTP
      8443 # Traefik HTTPS
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
    just
    btrbk
    cifs-utils # For SMB/CIFS shares
  ];

  # Enable SSH for remote access
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false; # Disable password authentication
      PermitEmptyPasswords = "no"; # Disable empty passwords
      PubkeyAuthentication = true; # Explicitly enable key authentication
    };
  };

  # Security hardening
  security = {
    sudo.wheelNeedsPassword = false;
  };

  nix = {
    extraOptions = ''
      experimental-features = nix-command flakes
      warn-dirty = false
    '';
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

  fileSystems."/mnt/media" = {
    device = "//u397529.your-storagebox.de/backup";
    fsType = "cifs";
    options = let
      # this line prevents hanging on network split
      # TODO: pull credentials from 1password
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
    in ["${automount_opts},credentials=${config.opnix.secrets.cifs-password.path},uid=1000,gid=100"];
  };

  # Configure automatic snapshots using btrbk
  # services.btrbk = {
  #   enabled = true;
  #   settings = {
  #     timestamp_format = "long";
  #     preserve_day_of_week = "monday";
  #     preserve_hour_of_day = "0";
  #
  #     volume = {
  #       "/btrfs_pool" = {
  #         subvolume = {
  #           "@home" = {
  #             snapshot_dir = "/snapshots/home";
  #             snapshot_preserve = "48h 7d 4w 6m";
  #             snapshot_create = "always";
  #           };
  #         };
  #       };
  #     };
  #   };
  # };

  # Setup systemd timer to run btrbk
  # systemd.services.btrbk-snapshot = {
  #   description = "BTRBK Snapshot Service";
  #   serviceConfig = {
  #     Type = "oneshot";
  #     ExecStart = "${pkgs.btrbk}/bin/btrbk run";
  #   };
  # };
  #
  # systemd.timers.btrbk-snapshot = {
  #   description = "BTRBK Snapshot Timer";
  #   wantedBy = ["timers.target"];
  #   timerConfig = {
  #     OnCalendar = "hourly"; # Run every hour, adjust as needed
  #     Persistent = true;
  #   };
  # };
}
