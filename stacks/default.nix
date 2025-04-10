{
  # Import nixpkgs
  pkgs ? import <nixpkgs> {}
}:

let
  # Get all subdirectories with a default.nix file
  # Find all directories in the current folder, exclude '.' (current directory)
  subdirs = builtins.filter 
    (name: name != "." && builtins.pathExists (./. + "/${name}/default.nix"))
    (builtins.attrNames (builtins.readDir ./.));
  
  # Import each subdirectory's default.nix
  importDir = name: {
    # Use the directory name as the attribute name
    inherit name;
    # Import the default.nix from that directory
    value = import (./. + "/${name}/default.nix") { inherit pkgs; };
  };
  
  # Convert the list of imports into an attribute set
  apps = builtins.listToAttrs (map importDir subdirs);
  
in {
  # Expose all the apps
  inherit apps;
  
  # Create a convenient all attribute that contains all apps
  all = pkgs.symlinkJoin {
    name = "all-apps";
    paths = builtins.attrValues apps;
  };
  
  # Also expose each app at the top level for direct access
  # e.g., you can use `nix-build -A app1` instead of `nix-build -A apps.app1`
} // apps
