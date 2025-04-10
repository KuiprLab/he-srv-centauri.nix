[doc("Default Recipe")]
default:
    just --list

[doc("Deploy the config using deploy-rs")]
deploy: format
    @git add .
    @nix run nixpkgs#deploy-rs -- --remote-build -s .#he-srv-centauri


[doc("Install NixOS using nix-anywhere")]
install: format
    @nix run github:nix-community/nixos-anywhere -- --flake .#he-srv-centauri root@37.27.26.175 --build-on remote

[doc("Deploy the config using deploy-rs")]
deploy-dev: format
    @git add .
    @nix run nixpkgs#deploy-rs -- --remote-build -s .#local-dev


[doc("Format all files")]
format:
    @nix fmt .


[doc("Does a dry run of the config")]
test:
    @nix build .#nixosConfigurations.he-srv-centauri.config.system.build.toplevel --accept-flake-config --impure --extra-experimental-features flakes --extra-experimental-features nix-command --dry-run


[doc("Edit the secrets.yaml")]
edit:
    @nix run nixpkgs#sops -- ./secrets/secrets.yaml
