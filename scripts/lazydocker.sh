export DOCKER_HOST=unix:///run/podman/podman.sock
alias docker='podman'
nix run nixpkgs#lazydocker
