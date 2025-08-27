# Manual Setup for he-srv-centauri

This document outlines the manual setup steps required for this NixOS configuration that are not managed by GitOps.

## 1. Initial NixOS Installation

This repository manages the configuration of a NixOS system, but it does not handle the initial installation of NixOS itself. You will need to follow the official NixOS installation guide to get a bare system up and running.

During the installation, you will need to partition your disks. This repository uses `disko` for declarative disk partitioning. The configuration can be found in `modules/disko-config.nix`. You can adapt this configuration to your needs.

Once NixOS is installed, you can clone this repository and proceed with the following steps.

## 2. Sops for Secret Management

This repository uses `sops` to manage secrets. The secrets are encrypted with an age key that is stored in 1Password. To decrypt the secrets, you will need to set up `sops` with the age key.

The `scripts/setup-sops.sh` script automates this process. It will:

1.  Create the `/var/lib/sops` directory.
2.  Fetch the age key from 1Password.
3.  Write the key to `/var/lib/sops/age-key.txt`.

To run the script, you will need to have the 1Password CLI installed and configured. Then, you can run the following command:

```bash
./scripts/setup-sops.sh
```

## 3. CIFS Mount

This configuration mounts a CIFS share at `/mnt/data`. The credentials for the CIFS mount are stored in `modules/cifs.txt`, which is a sops-encrypted file.

After setting up `sops` as described above, the CIFS mount should work automatically. The `cifs-creds` secret will be decrypted and used to mount the share.

You may need to adjust the CIFS mount configuration in `modules/configuration.nix` to match your environment. Specifically, you may need to change the `device` and other options in the `fileSystems."/mnt/data"` block.

## 4. Application Configuration

Many of the applications in this repository require manual configuration after they are deployed. This section outlines the necessary steps for each application.

### Authelia

Authelia is used for authentication. Users are managed in the `stacks/authelia/users.yaml` file. This file is encrypted with sops.

To add a new user, you will need to:

1.  Decrypt the `users.yaml` file.
2.  Add the new user to the file.
3.  Encrypt the file with sops.

### Jellyfin

Jellyfin is a media server. While the basic configuration is managed by this repository, you will need to perform the following tasks through the Jellyfin web UI:

*   **Add Media Libraries**: Configure your media libraries so that Jellyfin can find your movies, TV shows, and music.
*   **Install and Configure Plugins**: This repository adds several custom plugin repositories to Jellyfin. You will need to install and configure the plugins you want to use from these repositories.
*   **Create Users**: Create users and set their permissions.

### Starr Suite (Sonarr, Radarr, Lidarr)

The Starr suite is used for managing media collections. You will need to configure the following in the web UI for each application:

*   **Connect to Download Clients**: Connect Sonarr, Radarr, and Lidarr to your download client (e.g., qBittorrent).
*   **Add Indexers**: Add indexers (e.g., Prowlarr) to search for media.
*   **Define Quality Profiles**: Define quality profiles to specify the quality of the media you want to download.