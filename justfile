alias d := deploy
alias dl := deploy-local
alias ul := upgrade-local

[doc("Default Recipe")]
default:
    just --list

[doc("Deploy the config using deploy-rs")]
deploy: format
    @git add .
    @nix run nixpkgs#deploy-rs -- --remote-build -s .#he-srv-centauri


[doc("Install NixOS using nix-anywhere")]
install: format test
    @nix run github:nix-community/nixos-anywhere -- --flake .#he-srv-centauri root@37.27.26.175 --build-on remote

[doc("Locally deploy the config using nh")]
deploy-local host="he-srv-centauri":
    @nix run nixpkgs#nh -- os switch -H {{host}} .

[doc("Locally update flake and deploy the config using nh")]
upgrade-local host="he-srv-centauri":
    @nix run nixpkgs#nh -- os switch --hostname {{host}} --update .


[doc("Format all files")]
format:
    @nix fmt .


[doc("Does a dry run of the config")]
test:
    @nix build .#nixosConfigurations.he-srv-centauri.config.system.build.toplevel --accept-flake-config --impure --extra-experimental-features flakes --extra-experimental-features nix-command --dry-run


[doc("Edit the secrets.yaml")]
encrypt file:
    @export SOPS_AGE_KEY=$(op read "op://OpsVault/he-srv-centauri-sops-key/age"); nix run nixpkgs#sops -- -e -i {{file}}

edit file:
    @export SOPS_AGE_KEY=$(op read "op://OpsVault/he-srv-centauri-sops-key/age"); nix run nixpkgs#sops -- edit {{file}}


[doc("Convert docker-compose files to nix files using compose2nix")]
convert input output-name:
    @mkdir -p ./stacks/{{output-name}}
    @nix run github:aksiksi/compose2nix -- -inputs={{input}}  -generate_unused_resources -output=./stacks/{{output-name}}/default.nix
