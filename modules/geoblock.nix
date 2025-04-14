# central-europe-allowlist.nix
{ config, pkgs, lib, ... }:

let
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
  ];

  # Join country codes for IPTables rule
  allowedCountriesStr = lib.concatStringsSep "," allowedCountries;

  # Use customized xtables-addons package
  customXtablesAddons = pkgs.xtables-addons.override {
    kernel = config.boot.kernelPackages.kernel;
  };

  # Create script to download and build GeoIP database
  updateGeoIPScript = pkgs.writeScriptBin "update-geoip-db" ''
    #!${pkgs.runtimeShell}
    set -e

    # Create GeoIP directory if it doesn't exist
    GEOIP_DIR="/usr/share/xt_geoip/"
    mkdir -p $GEOIP_DIR
    
    # Get current date for database filename
    DATE=$(date +'%Y-%m')
    GEOIP_URL="https://download.db-ip.com/free/dbip-country-lite-$DATE.csv.gz"
    GEOIP_CSV_GZ_FILE="$GEOIP_DIR/dbip-country-lite-$DATE.csv.gz"
    GEOIP_CSV_FILE="$GEOIP_DIR/dbip-country-lite-$DATE.csv"
    
    echo "Downloading GeoIP database..."
    ${pkgs.curl}/bin/curl -L "$GEOIP_URL" -o "$GEOIP_CSV_GZ_FILE"
    
    echo "Extracting GeoIP CSV file..."
    cd $GEOIP_DIR
    ${pkgs.gzip}/bin/gunzip -f "$GEOIP_CSV_GZ_FILE"
    
    echo "Building the GeoIP database with xtables-addons..."
    mv "$GEOIP_CSV_FILE" "$GEOIP_DIR/dbip-country-lite.csv"
    
    # Find the xt_geoip_build script
    GEOIP_BUILD="${customXtablesAddons}/libexec/xtables-addons/xt_geoip_build"
    
    # Build the database
    "$GEOIP_BUILD" -D "$GEOIP_DIR" "$GEOIP_DIR"/*.csv
    
    # Clean up
    rm -f "$GEOIP_DIR"/*.csv
    
    echo "GeoIP database update completed"
  '';

  # Create script to setup IPTables rules for Central Europe
  setupIPTablesScript = pkgs.writeScriptBin "setup-central-europe-allowlist" ''
    #!${pkgs.runtimeShell}
    set -e
    
    # Ensure xt_geoip module is loaded
    ${pkgs.kmod}/bin/modprobe xt_geoip
    
    # Clear existing rules and set default policies
    ${pkgs.iptables}/bin/iptables -F
    ${pkgs.iptables}/bin/iptables -X
    
    # Allow established connections
    ${pkgs.iptables}/bin/iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    # Allow loopback
    ${pkgs.iptables}/bin/iptables -A INPUT -i lo -j ACCEPT
    
    # Allow specified countries and block all others
    ${pkgs.iptables}/bin/iptables -A INPUT -m geoip --src-cc ${allowedCountriesStr} -j ACCEPT
    ${pkgs.iptables}/bin/iptables -A INPUT -m geoip ! --src-cc ${allowedCountriesStr} -j DROP
    
    echo "IPTables rules set to allow only Central European countries"
  '';

in {
  # Define system packages
  environment.systemPackages = with pkgs; [
    # Basic tools
    curl
    gzip
    perl
    unzip
    
    # Required perl modules
    perlPackages.TextCSV
    perlPackages.MooseXTypesNetAddr
    
    # Custom scripts
    updateGeoIPScript
    setupIPTablesScript
    
    # Include our custom xtables-addons package
    customXtablesAddons
  ];
  
  boot = {
    # Enable required kernel modules
    kernelModules = [ "xt_geoip" ];
    
    # Automatically load modules at boot
    extraModulePackages = [ customXtablesAddons ];
    
    # Use latest kernel for better compatibility
    kernelPackages = pkgs.linuxPackages_latest;
  };

  # Create directory for GeoIP database
  system.activationScripts.geoip = ''
    mkdir -p /usr/share/xt_geoip
  '';
  
  # Periodically update GeoIP database (monthly)
  systemd.services.update-geoip = {
    description = "Update GeoIP Database";
    path = with pkgs; [ curl gzip perl ];
    script = "${updateGeoIPScript}/bin/update-geoip-db";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };
  
  systemd.timers.update-geoip = {
    description = "Timer for GeoIP Database Updates";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "monthly";
      Persistent = true;
      RandomizedDelaySec = "12h";
    };
  };
  
  # Set up IPTables rules on startup
  systemd.services.setup-country-allowlist = {
    description = "Set up country-based IPTables allowlist";
    after = [ "network.target" "update-geoip.service" ];
    wants = [ "update-geoip.service" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ iptables kmod ];
    script = "${setupIPTablesScript}/bin/setup-central-europe-allowlist";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };
  
  # Ensure dependencies are met
  networking.firewall.enable = lib.mkForce false;  # Disable default firewall to use our custom IPTables rules
  
  # Create a simple service to check if the setup is working
  systemd.services.geoip-status = {
    description = "Check GeoIP and IPTables status";
    path = with pkgs; [ iptables kmod ];
    script = ''
      #!/bin/sh
      echo "GeoIP Module Status:"
      ${pkgs.kmod}/bin/lsmod | grep xt_geoip || echo "xt_geoip module not loaded!"
      
      echo "IPTables GeoIP Rules:"
      ${pkgs.iptables}/bin/iptables -L INPUT | grep geoip
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      RemainAfterExit = true;
    };
  };
}
