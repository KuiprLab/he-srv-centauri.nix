[doc("Default Recipe")]
default:
    just --list

[doc("Deploy the config using deploy-rs")]
deploy: format
    @nix run nixpkgs#deploy-rs -- --remote-build -s .#he-srv-centauri

[doc("Format all files")]
format:
    @nix fmt .


[doc("Edit the secrets.yaml")]
edit:
    @nix run nixpkgs#sops -- ./secrets/secrets.yaml
