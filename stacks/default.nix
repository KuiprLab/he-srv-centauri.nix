{pkgs, ...}: let
  # Get lib from pkgs for dependencies
  lib = pkgs.lib;

  # Get all subdirectories with a default.nix file
  # Find all directories in the current folder, exclude '.' (current directory)
  subdirs =
    builtins.filter
    (name: name != "." && builtins.pathExists (./. + "/${name}/default.nix"))
    (builtins.attrNames (builtins.readDir ./.));

  # Import each subdirectory's default.nix
  # Returns the path to import, not an attribute set
  importedModules = map (name: ./. + "/${name}/default.nix") subdirs;
in {
  # Add all modules to imports
  imports = importedModules;
}
