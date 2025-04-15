# country-allowlist.nix
{
  config,
  pkgs,
  lib,
  ...
}: let
  # Define allowed country codes (ISO 3166-1 alpha-2)
  allowedCountries = [
    "AT" # Austria
    "CH" # Switzerland
    "CZ" # Czech Republic
    "DE" # Germany
    "HU" # Hungary
    "LI" # Liechtenstein
    "PL" # Poland
    "SK" # Slovakia
    "SI" # Slovenia
    "IT" # Italy
    "NL" # Netherlands
  ];

  # Join country codes for IPTables rule
  allowedCountriesStr = lib.concatStringsSep "," allowedCountries;

  # Create script to download and build GeoIP database
  updateGeoIPScript = pkgs.writeScriptBin "update-geoip-db" ''
    #!${pkgs.runtimeShell}
    set -e

    # Create GeoIP directory if it doesn't exist
    GEOIP_DIR="/var/lib/ip-geoblock"
    mkdir -p $GEOIP_DIR

    echo "Downloading GeoIP database..."
    # Get current date for database filename
    DATE=$(date +'%Y-%m')
    GEOIP_URL="https://download.db-ip.com/free/dbip-country-lite-$DATE.csv.gz"
    GEOIP_CSV_GZ_FILE="$GEOIP_DIR/dbip-country-lite-$DATE.csv.gz"
    GEOIP_CSV_FILE="$GEOIP_DIR/dbip-country-lite-$DATE.csv"

    ${pkgs.curl}/bin/curl -L "$GEOIP_URL" -o "$GEOIP_CSV_GZ_FILE"

    echo "Extracting GeoIP CSV file..."
    cd $GEOIP_DIR
    ${pkgs.gzip}/bin/gunzip -f "$GEOIP_CSV_GZ_FILE"

    # Convert the DB-IP CSV to the ipset format
    # The format is: IP-Range,CountryCode
    echo "Converting database to ipset format..."
    for country in ${allowedCountriesStr}; do
      ${pkgs.gnugrep}/bin/grep ",$country$" "$GEOIP_CSV_FILE" | ${pkgs.gawk}/bin/awk -F, '{print $1}' > "$GEOIP_DIR/allowed_$country.txt"
      echo "Processed $country"
    done

    echo "GeoIP database update completed"
  '';

  # Create script to setup IPTables rules for allowed countries
  setupIPTablesScript = pkgs.writeScriptBin "setup-country-allowlist" ''
    #!${pkgs.runtimeShell}
    set -e

    GEOIP_DIR="/var/lib/ip-geoblock"

    # Flush existing ipset rules
    if ${pkgs.ipset}/bin/ipset list | grep -q "allowed_countries"; then
      ${pkgs.ipset}/bin/ipset destroy allowed_countries
    fi

    # Create a new ipset
    ${pkgs.ipset}/bin/ipset create allowed_countries hash:net family inet hashsize 16384 maxelem 500000

    # Add allowed country IP ranges to the ipset
    for country in ${allowedCountriesStr}; do
      if [ -f "$GEOIP_DIR/allowed_$country.txt" ]; then
        while IFS= read -r ip_range; do
          ${pkgs.ipset}/bin/ipset add allowed_countries "$ip_range"
        done < "$GEOIP_DIR/allowed_$country.txt"
        echo "Added IPs for $country to the ipset"
      else
        echo "Warning: No IP data found for $country"
      fi
    done

    # Set up iptables rules
    # Clear existing rules
    ${pkgs.iptables}/bin/iptables -F
    ${pkgs.iptables}/bin/iptables -X

    # Allow established connections
    ${pkgs.iptables}/bin/iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Allow loopback
    ${pkgs.iptables}/bin/iptables -A INPUT -i lo -j ACCEPT

    # Allow connections from allowed countries using the ipset
    ${pkgs.iptables}/bin/iptables -A INPUT -m set --match-set allowed_countries src -j ACCEPT

    # Block everything else
    ${pkgs.iptables}/bin/iptables -A INPUT -j DROP

    echo "IPTables rules set to allow only specified countries"
  '';
in {
  # Define system packages
  environment.systemPackages = with pkgs; [
    # Basic tools
    curl
    gzip
    gnugrep
    gawk
    ipset
    iptables

    # Custom scripts
    updateGeoIPScript
    setupIPTablesScript
  ];

  # Ensure ipset kernel module is loaded
  boot = {
    kernelModules = ["ip_set" "ip_set_hash_net"];

    # Use latest kernel for better compatibility
    kernelPackages = pkgs.linuxPackages_latest;
  };

  # Create directory for GeoIP database
  system.activationScripts.geoip = ''
    mkdir -p /var/lib/ip-geoblock
  '';

  # Periodically update GeoIP database (monthly)
  systemd.services.update-geoip = {
    description = "Update GeoIP Database";
    path = with pkgs; [curl gzip gnugrep gawk];
    script = "${updateGeoIPScript}/bin/update-geoip-db";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  systemd.timers.update-geoip = {
    description = "Timer for GeoIP Database Updates";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "monthly";
      Persistent = true;
      RandomizedDelaySec = "12h";
    };
  };

  # Set up IPTables rules on startup
  systemd.services.setup-country-allowlist = {
    description = "Set up country-based IPTables allowlist";
    after = ["network.target" "update-geoip.service"];
    wants = ["update-geoip.service"];
    wantedBy = ["multi-user.target"];
    path = with pkgs; [iptables ipset];
    script = "${setupIPTablesScript}/bin/setup-country-allowlist";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  # Ensure dependencies are met
  networking.firewall.enable = lib.mkForce false; # Disable default firewall to use our custom IPTables rules

  # Create a simple service to check if the setup is working
  systemd.services.geoip-status = {
    description = "Check GeoIP and IPTables status";
    path = with pkgs; [iptables ipset];
    script = ''
      #!/bin/sh
      echo "IPSet Status:"
      ${pkgs.ipset}/bin/ipset list allowed_countries || echo "allowed_countries ipset not found!"

      echo "IPTables Rules:"
      ${pkgs.iptables}/bin/iptables -L INPUT
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      RemainAfterExit = true;
    };
  };
}
