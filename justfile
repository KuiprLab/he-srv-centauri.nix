alias dm := deploy-main
alias dd := deploy-dev
alias u := upgrade

[doc("Default Recipe")]
default:
    just --list

[doc("Install NixOS using nix-anywhere")]
install ip="37.27.26.175": format test
    @nix run github:nix-community/nixos-anywhere -- --flake .#he-srv-centauri root@{{ip}} --build-on remote

[doc("Locally deploy the config using nh")]
deploy-main host="he-srv-centauri":
    @sudo git checkout main
    @sudo git pull
    @nix run nixpkgs#nh -- os switch -H {{host}} .


[doc("Locally deploy the config using nh")]
deploy-dev host="he-srv-centauri":
    @sudo git checkout dev
    @sudo git pull
    @nix run nixpkgs#nh -- os switch -H {{host}} .


[doc("Locally update flake and deploy the config using nh")]
upgrade host="he-srv-centauri":
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

[doc("Edit a sops encrypted file")]
edit file:
    @export SOPS_AGE_KEY=$(op read "op://OpsVault/he-srv-centauri-sops-key/age"); nix run nixpkgs#sops -- edit {{file}}


[doc("Convert docker-compose files to nix files using compose2nix")]
convert input output-name:
    @mkdir -p ./stacks/{{output-name}}
    @nix run github:aksiksi/compose2nix -- -inputs={{input}}  -generate_unused_resources -output=./stacks/{{output-name}}/default.nix


[doc("Create a password hash for authelia")]
generate-user-pw-hash password:
    @docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password {{password}}

[doc("Generate a random 64 bit long secret")]
generate-generic-secret:
    @tr -dc A-Za-z0-9 </dev/urandom | head -c 64; echo

[doc("Generate a random pbkdf2 secret for use in authelia")]
generate-client-secret:
    @docker run --rm authelia/authelia:latest authelia crypto hash generate pbkdf2 --variant sha512 --random --random.length 72 --random.charset rfc3986
