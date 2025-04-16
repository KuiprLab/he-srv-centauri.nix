<p align="center">
    <img src="https://nixos.wiki/images/thumb/2/20/Home-nixos-logo.png/414px-Home-nixos-logo.png" width=200/>
    <h1 align="center"><code>he-srv-centauri.nix</code></h1>
    <div style="display: grid;" align="center">
    </div>
    <img src="https://uptime.kuipr.de/api/v1/endpoints/infrastructure_he-srv-centauri/uptimes/30d/badge.svg" height=20/>
</p>
This flake contains the configuration for my Hetzner VPS running various services.

## Getting started

### Prerequisites

- A machine running Ubuntu 24.04
- An open SSH connection for the root user with either a password or ssh key
- The hosts needs to be added to known_hosts before starting the installation
- [just](https://github.com/casey/just) installed

### Installation

1. (Optional) Make sure that your public ssh key has been added to `openssh.authorizedKeys.keys` inside `modules/configuration.nix` otherwise you wont be able to log in.
2. (Optional) Switch out the `initialHashedPassword` with a password hash of a new password.
3. Run `just install`. This will use nix-anywhere to install NixOS onto your host. Optionally pass the IP address of your server, otherwise it will use a default one.
    - The installation will take a while depending on the specs of your server.
    - If the installation fails half way through for any reason you will most like have to reinstall Ubuntu and start from the beginning after fixing the issue.
4. Once NixOS has been installed ssh into the server and clone this repository into your home folder.
5. Create a file at `/var/lib/sops/age-key.txt` and paste your private age key into it.
6. Now you can run `just deploy-local`  (or its alias `just dl`) to deploy your configuration again but this time with all the secrets too
7. Lastly run `tailscale up --accept-routes` to connect to the tailscale network

### Upgrading

Simply run `just upgrade-local` to upgrade the deployment.
TODO: Automatic upgrades

### Other commands

- `convert input output-name`            # Convert docker-compose files to nix files using compose2nix
- `default`                              # Default Recipe
- `deploy`                               # Deploy the config using deploy-rs [alias: d]
- `deploy-local host="he-srv-centauri"`  # Locally deploy the config using nh [alias: dl]
- `edit file`                            # Edit a sops encrypted file
- `encrypt file`                         # Edit the secrets.yaml
- `format`                               # Format all files
- `generate-client-secret`               # Generate a random pbkdf2 secret for use in authelia
- `generate-generic-secret`              # Generate a random 64 bit long secret
- `generate-user-pw-hash password`       # Create a password hash for authelia
- `install ip`                           # Install NixOS using nix-anywhere
- `test`                                 # Does a dry run of the config
- `upgrade-local host="he-srv-centauri"` # Locally update flake and deploy the config using nh [alias: ul]

## Project Structure

```bash
.
├── flake.nix
├── justfile
├── modules # General place for configruation
│   ├── cifs.txt
│   ├── configuration.nix # Main configuration file
│   ├── disko-config.nix # Disko settings   
│   └── hardware-configuration.nix # Hardware settings
├── scripts
│   ├── lazydocker.sh # This script lets your run lazydocker on the server. Run with sudo
│   └── setup-sops.sh # Unused
├── services # Non-docker services 
│   ├── default.nix
│   ├── haproxy
│   ├── fail2ban.nix
│   └── tailscale.nix
├── stacks # Docker stacks
│   ├── authelia
│   ├── default.nix
│   ├── gatus
│   ├── glance
│   ├── jellyfin
│   ├── komga
│   ├── obsidian-share-notes
│   ├── qbittorrent
│   ├── starr
│   └── traefik
└── utils # Custom helper functions
    └── my-declared-folders.nix
```

## Adding New Services

### Non-Docker

Non docker services should be added to the `services` folder and will be automatically included if you add them to `defaults.nix` in that directory.

### Docker

Docker definitions should be added to `stacks` with each stack in its own subfolder besides its secrets and configruation. An easy way to convert docker-compose yaml files is to use
the provided `just convert` command. This takes in the path to the yaml file and the name you want to give the folder inside `stacks`. It will then create that folder and 
automatically convert the file. Lastly you need to remove the podman definition block at the top as thats already defined somewhere else in the config. 
You might also want to decalre some folders using the `myFolders` function:
```nix
  myFolders = {
    uniquename = {
      path = "pat/to/be/created/{multiple,folders}";
      owner = "username";
      group = "groupname";
      mode = "0755";
    };
  };
```
Add the stack to the imports array in `default.nix` inside `stacks/`.

### Adding secrets

For secret management this project uses sops-nix. Create a secrets file in the same directory as your stack and fill it with information. The file can be of type yaml, json, ini, env
or binary files.

After you're finished editing the file encrypt it with `just encrypt path/to/file`. Now include it in your configuration by using the following snippet:
```nix
  sops.secrets."filename" = {
    sopsFile = ./path/to/file;
    key = "";
    owner = "<optional username>"; # optional
    format = "<any of yaml,json,ini,env,binary>"; # optional but recommended
    restartUnits = ["<optional systemd service>"]; # optional
  };
```
You can then access the sercrets either by reading `/run/secrets/filename` or by doing `config.sops.secrets."filename".path`. Be aware that the default owner of this file is `root` if
you dont specify one.

To edit the encrypted file again use `just edit pat/to/file`.

## Configuring Authelia

To add a new oidc client you need to supply a secret. These secrets can be generated by running `just generate-client-secret`. Note: This requires docker.
If you need to add a new user you can generate an argon2 hash by running `just generate-user-pw-hash <password>`. Additionally you can generate generic passwords by using `just generate-generic-secret`.
