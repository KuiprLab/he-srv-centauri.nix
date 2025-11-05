alias dm := deploy-main
alias dd := deploy-dev
alias u := upgrade

current-branch := `git rev-parse --abbrev-ref HEAD`

[doc("Default Recipe")]
default:
    just --list

[doc("Install NixOS using nix-anywhere")]
install ip="37.27.26.175": format test
    @nix run github:nix-community/nixos-anywhere -- --flake .#he-srv-centauri root@{{ip}} --build-on remote

# Helper to warn if deploying dev
warn-if-dev branch:
    @if [ "{{branch}}" = "dev" ]; then echo -e "\033[38;5;208m[WARNING] You are deploying the 'dev' branch!\033[0m"; fi


[doc("Locally deploy the config using nh")]
deploy-main host="he-srv-centauri":
    @sudo chown ubuntu *
    @just warn-if-dev main
    @if [ "{{current-branch}}" = "dev" ]; then sudo git checkout main; else echo "Already on main."; fi
    @sudo git pull
    @nix run nixpkgs#nh -- os switch -H {{host}} .

[doc("Locally deploy the config using nh")]
deploy-dev host="he-srv-centauri":
    @just warn-if-dev dev
    @if [ "{{current-branch}}" = "main" ]; then sudo git checkout dev; else echo "Already on dev."; fi
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
    @LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 64; echo

[doc("Generate a random pbkdf2 secret for use in authelia")]
generate-client-secret:
    @docker run --rm authelia/authelia:latest authelia crypto hash generate pbkdf2 --variant sha512 --random --random.length 72 --random.charset rfc3986

[doc("Show disk usage with a nice summary")]
disk-usage:
    @echo "=== Disk Usage Summary ==="
    @df -h / | tail -n 1
    @echo ""
    @echo "=== Largest Directories in / ==="
    @sudo du -h --max-depth=1 / 2>/dev/null | sort -hr | head -n 10
    @echo ""
    @echo "=== Nix Store Size ==="
    @du -sh /nix/store 2>/dev/null || echo "No /nix/store found"

[doc("Clean up Nix store and generations")]
nix-clean:
    @echo "=== Cleaning Nix Store ==="
    @sudo nix-collect-garbage -d
    @echo ""
    @echo "=== Optimizing Nix Store ==="
    @sudo nix-store --optimize
    @echo ""
    @echo "=== Current Disk Usage ==="
    @df -h / | tail -n 1
