{
  config,
  lib,
  pkgs,
  ...
}: {
  # Add 1Password CLI to system packages
  environment.systemPackages = [
    pkgs.age
    pkgs._1password-cli
  ];

  # Define a service that runs on first boot to set up the sops age key
  systemd.services.sops-init-age-key = {
    description = "Initialize age key for sops-nix from 1Password";
    wantedBy = ["multi-user.target"];
    after = ["network.target" "network-online.target"];
    wants = ["network-online.target"];

    # Run only once (on first boot)
    unitConfig = {
      ConditionPathExists = "!/var/lib/sops/age-key.txt";
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Run as root since we need to write to protected directories
      User = "root";
    };

    script = ''
      eval $(op signin)
      # Create the sops directory
      mkdir -p /var/lib/sops
      chmod 700 /var/lib/sops
      # Check if 1Password CLI is configured
      if ! op user list &>/dev/null; then
        echo "1Password CLI is not configured. Please run 'op signin' first."
        exit 1
      fi

      # Get age key from 1Password, assuming it's stored as a secure note
      # Replace "Age Key" with the actual item name and "private_key" with the field name
      AGE_KEY=$(op item get "Age Key" --field "private_key")

      if [ -z "$AGE_KEY" ]; then
        echo "Failed to retrieve age key from 1Password"
        exit 1
      fi

      # Write the key to the file
      echo "$AGE_KEY" > /var/lib/sops/age-key.txt
      chmod 600 /var/lib/sops/age-key.txt

      echo "Successfully initialized age key for sops-nix"
    '';
  };

  # Configure sops-nix to use the key
  sops = {
    age = {
      keyFile = "/var/lib/sops/age-key.txt";
      generateKey = false; # Don't generate a key, we're importing it
    };
  };
}
