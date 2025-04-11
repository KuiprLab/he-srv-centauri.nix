{
  config,
  lib,
  pkgs,
  ...
}: let
  folders = config.myFolders;
  # Generate the creation command for each folder.
  folderCreationCommands = lib.mapAttrsToList (name: folder: ''
    echo "Creating folder ${folder.path}"
    mkdir -p "${folder.path}"
    chown ${folder.owner}:${folder.group} "${folder.path}"
    chmod ${folder.mode} "${folder.path}"
  '')
  folders;

  # Generate a list of declared folder paths.
  declaredFolderPaths =
    lib.mapAttrsToList (name: folder: folder.path) folders;
in {
  options.myFolders = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.path = lib.mkOption {
        type = lib.types.str;
        description = "Absolute path of the folder to manage.";
      };
      options.owner = lib.mkOption {
        type = lib.types.str;
        default = "root";
        description = "Owner of the folder.";
      };
      options.group = lib.mkOption {
        type = lib.types.str;
        default = "root";
        description = "Group of the folder.";
      };
      options.mode = lib.mkOption {
        type = lib.types.str;
        default = "0755";
        description = "Permission mode for the folder (e.g., 0755).";
      };
    });
    default = {};
    description = "A set of folders that are created (with mkdir) and then removed when no longer declared. Removal is skipped if the folder is not empty.";
  };

  config = {
    system.activationScripts.manageFolders = {
      text = ''
                set -e

                # Directory to store the list of declared folder paths.
                mkdir -p /var/lib/myfolders
                old_paths_file="/var/lib/myfolders/declared-paths"
                new_paths_file="$(mktemp)"

                # Create or update declared folders.
                ${lib.concatStringsSep "\n" folderCreationCommands}

                # Write the current declared folder paths to the temporary file.
                cat <<EOF > "$new_paths_file"
        ${lib.concatStringsSep "\n" declaredFolderPaths}
        EOF

                # If an old declared list exists, check for folders to remove.
                if [ -f "$old_paths_file" ]; then
                  comm -23 "$old_paths_file" "$new_paths_file" | while read -r path; do
                    if [ -n "$path" ] && [ -d "$path" ]; then
                      if [ -z "$(ls -A "$path")" ]; then
                        echo "Removing empty folder no longer declared: $path"
                        rm -rf "$path"
                      else
                        echo "Warning: Folder $path is not empty, skipping deletion."
                      fi
                    fi
                  done
                fi

                # Update stored list of declared folder paths.
                mv "$new_paths_file" "$old_paths_file"
      '';
    };
  };
}
