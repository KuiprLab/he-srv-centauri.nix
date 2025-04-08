[doc("Default Recipe")]
default:
    just --list

[doc("Deploy the config using deploy-rs")]
deploy: format
    @git add .
    @nix run nixpkgs#deploy-rs -- --remote-build -s .#he-srv-centauri

[doc("Deploy the config using deploy-rs")]
deploy-dev: format
    @git add .
    @nix run nixpkgs#deploy-rs -- --remote-build -s .#local-dev


[doc("Format all files")]
format:
    @nix fmt .


[doc("Edit the secrets.yaml")]
edit:
    @nix run nixpkgs#sops -- ./secrets/secrets.yaml
