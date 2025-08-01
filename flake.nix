{
  description = "NixOS configuration for my Hetzner VPS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # For automatic deployments
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impurity.url = "github:outfoxxed/impurity.nix";

    # For secrets management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };
  };

  outputs = {
    self,
    nixpkgs,
    deploy-rs,
    sops-nix,
    impurity,
    ...
  } @ inputs: let
    system = "aarch64-linux";
    lib = nixpkgs.lib;

    # Settings for Package management
    nixpkgsConfig = {
      allowUnfree = true;
      allowUnsupportedSystem = false;
      allowBroken = true;
      allowInsecure = true; # Fixed typo here
      overlays = [
        (
          _: prev: let
            fetchNixpkgs = rev: (import (builtins.fetchGit {
              inherit rev;
              url = "https://github.com/nixos/nixpkgs";
              ref = "master";
            }) {inherit (prev) system;});
          in {
            inherit ((fetchNixpkgs "a1d539f8eecffd258f3ed1ccc3a055aed56fbaa1").pkgsStatic) libselinux;
          }
        )
      ];
    };
    pkgs = import inputs.nixpkgs {
      inherit system;
      config = nixpkgsConfig;
    };
  in {
    # NixOS configuration
    nixosConfigurations = {
      he-srv-centauri = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        specialArgs = {
          inherit self;
        };
        modules = [
          ./modules/configuration.nix
          ./stacks
          ./services
          sops-nix.nixosModules.sops
          inputs.disko.nixosModules.disko
          {
            imports = [impurity.nixosModules.impurity];
            impurity.configRoot = self;
          }
        ];
      };
    };

    # Deployment configuration using deploy-rs
    deploy.nodes = {
      he-srv-centauri = {
        hostname = "37.27.26.175";
        profiles.system = {
          user = "ubuntu";
          sshUser = "ubuntu";
          path = deploy-rs.lib.aarch64-linux.activate.nixos self.nixosConfigurations.he-srv-centauri;
        };
      };
    };

    # Check deployments
    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

    # Set a formatter for both the system architectures im using
    formatter = {
      aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.alejandra;
      x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;
      aarch64-linux = nixpkgs.legacyPackages.aarch64-linux.alejandra;
    };
  };
}
