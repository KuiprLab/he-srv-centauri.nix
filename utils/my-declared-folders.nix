{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.myFolders;
in {
  options.myFolders = lib.mkOption {
    type = with lib.types;
      attrsOf (submodule {
        options.path = lib.mkOption {
          type = types.str;
          description = "Absolute path to the folder to create.";
        };
        options.owner = lib.mkOption {
          type = types.str;
          default = "root";
          description = "Owner of the folder.";
        };
        options.group = lib.mkOption {
          type = types.str;
          default = "root";
          description = "Group of the folder.";
        };
        options.mode = lib.mkOption {
          type = types.str;
          default = "0755";
          description = "Permissions mode (e.g., 0755).";
        };
      });
    default = {};
    description = "Declaratively manage folders (create and remove).";
  };

  config = {
    # Create folders using systemd.tmpfiles
    systemd.tmpfiles.rules = lib.flatten (
      lib.mapAttrsToList (
        _: folder: ["d ${folder.path} ${folder.mode} ${folder.owner} ${folder.group} -"]
      )
      cfg
    );

    # Delete removed folders during activation
    system.activationScripts.cleanupMyFolders.text = ''
      set -e

      mkdir -p /var/lib/myfolders
      old_paths_file="/var/lib/myfolders/declared-paths"
      new_paths_file="$(mktemp)"

      # Save current folder paths to temp file
      cat <<EOF > "$new_paths_file"
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (_: f: f.path) cfg)}
      EOF

      if [[ -f "$old_paths_file" ]]; then
        comm -23 "$old_paths_file" "$new_paths_file" | while read -r path; do
          if [[ -n "$path" && -d "$path" ]]; then
            echo "Removing folder no longer declared: $path"
            rm -rf "$path"
          fi
        done
      fi

      mv "$new_paths_file" "$old_paths_file"
    '';
  };
}
