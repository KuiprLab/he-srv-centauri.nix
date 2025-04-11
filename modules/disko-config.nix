{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02";
              priority = 1;
            };
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = ["-f"]; # Force formatting
                subvolumes = {
                  # Subvolume for root
                  "@" = {
                    mountpoint = "/";
                  };
                  # Subvolume for home
                  "@home" = {
                    mountpoint = "/home";
                  };
                  # Subvolume for snapshots
                  "@snapshots" = {
                    mountpoint = "/snapshots";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
