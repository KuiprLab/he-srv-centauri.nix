{ pkgs, lib, config, ... }:
let
  # Discord webhook URL from sops secrets
  discordWebhookUrl = config.sops.secrets.discord-webhook-url.path;
  
  updateScript = pkgs.writeShellScriptBin "update-containers" ''
    export PATH=${lib.makeBinPath [ pkgs.podman pkgs.jq pkgs.curl pkgs.nettools pkgs.coreutils ]}:$PATH
    set -euo pipefail
    
    # Initialize counters and arrays
    updated_count=0
    restarted_count=0
    failed_count=0
    declare -a updated_images=()
    declare -a restarted_containers=()
    declare -a failed_operations=()
    
    echo "Starting container update process at $(date)"
    
    # Get all unique images from running and stopped containers
    echo "Discovering container images..."
    images=$(${pkgs.podman}/bin/podman ps -a --format="{{.Image}}" | sort -u | grep -v '^$')
    
    if [ -z "$images" ]; then
      echo "No container images found"
      exit 0
    fi
    
    echo "Found images to check: $images"
    
    # Pull updates for each image
    for image in $images; do
      echo "Checking for updates: $image"
      
      # Get current image ID
      current_id=$(${pkgs.podman}/bin/podman images --format="{{.ID}}" "$image" 2>/dev/null | head -n1 || echo "")
      
      # Pull the image
      if ${pkgs.podman}/bin/podman pull "$image" >/dev/null 2>&1; then
        # Get new image ID after pull
        new_id=$(${pkgs.podman}/bin/podman images --format="{{.ID}}" "$image" 2>/dev/null | head -n1 || echo "")
        
        # Check if image was actually updated
        if [ "$current_id" != "$new_id" ] && [ -n "$new_id" ]; then
          echo "Image updated: $image"
          updated_images+=("$image")
          ((updated_count++))
          
          # Find and restart containers using this image
          echo "Looking for containers using image: $image"
          containers=$(${pkgs.podman}/bin/podman ps -a --filter="ancestor=$image" --format="{{.Names}}" 2>/dev/null | grep -v '^
        else
          echo "No update available for: $image"
        fi
      else
        echo "Failed to pull: $image"
        failed_operations+=("pull $image")
        ((failed_count++))
      fi
    done
    
    # Prepare Discord notification
    timestamp=$(date -Iseconds)
    hostname=$(hostname)
    
    # Create summary message
    if [ $updated_count -eq 0 ] && [ $failed_count -eq 0 ]; then
      summary="✅ All container images are up to date"
      color=3066993  # Green
    elif [ $failed_count -eq 0 ]; then
      summary="🔄 Successfully updated $updated_count image(s) and restarted $restarted_count container(s)"
      color=3447003  # Blue
    else
      summary="⚠️ Updated $updated_count image(s), restarted $restarted_count container(s), but encountered $failed_count error(s)"
      color=15105570  # Orange
    fi
    
    # Build detailed message
    details=""
    if [ ''${#updated_images[@]} -gt 0 ]; then
      details="$details**Updated Images:**\n"
      for img in "''${updated_images[@]}"; do
        details="$details• $img\n"
      done
      details="$details\n"
    fi
    
    if [ ''${#restarted_containers[@]} -gt 0 ]; then
      details="$details**Restarted Containers:**\n"
      for container in "''${restarted_containers[@]}"; do
        details="$details• $container\n"
      done
      details="$details\n"
    fi
    
    if [ ''${#failed_operations[@]} -gt 0 ]; then
      details="$details**Failed Operations:**\n"
      for operation in "''${failed_operations[@]}"; do
        details="$details• $operation\n"
      done
    fi
    
    # Send Discord notification
    echo "Sending Discord notification..."
    
    webhook_url=$(cat "${discordWebhookUrl}")
    
    payload=$(${pkgs.jq}/bin/jq -n \
      --arg summary "$summary" \
      --arg details "$details" \
      --arg hostname "$hostname" \
      --arg timestamp "$timestamp" \
      --argjson color "$color" \
      '{
        embeds: [{
          title: "Container Update Report",
          description: $summary,
          color: $color,
          fields: [
            {
              name: "Details",
              value: (if $details == "" then "No additional details" else $details end),
              inline: false
            }
          ],
          footer: {
            text: ("Host: " + $hostname)
          },
          timestamp: $timestamp
        }]
      }')
    
    if ${pkgs.curl}/bin/curl -X POST \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "$webhook_url" \
      --silent --show-error --fail; then
      echo "Discord notification sent successfully"
    else
      echo "Failed to send Discord notification"
    fi
    
    echo "Container update process completed at $(date)"
    echo "Summary: Updated $updated_count images, restarted $restarted_count containers, $failed_count failures"
    
    # Exit with success code even if there were some failures, since the main process worked
    # Only exit with error if critical operations failed
    if [ $failed_count -gt 0 ]; then
      echo "Some operations failed, but continuing..."
      exit 0  # Changed from letting it exit with error
    fi
  '';
in
{
  # Define the sops secret for the Discord webhook URL
  sops.secrets.discord-webhook-url = {
    sopsFile = ./discord-webhook.yaml;  # Adjust path to your secrets file
    owner = "root";
    group = "root";
    mode = "0400";
  };

  systemd.timers.update-containers = {
    timerConfig = {
      Unit = "update-containers.service";
      OnCalendar = "daily";  # Changed from "Mon 02:00" to "daily"
      Persistent = true;  # Run if system was down during scheduled time
    };
    wantedBy = [ "timers.target" ];
  };

  systemd.services.update-containers = {
    description = "Update container images and restart affected containers";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe updateScript;
      # Security settings
      User = "root";  # Need root access for sops secrets and podman
      PrivateTmp = true;
      ProtectHome = true;
      NoNewPrivileges = true;
      # Allow access to podman socket
      SupplementaryGroups = [ "podman" ];
    };
    # Ensure podman is available
    wants = [ "podman.service" ];
    after = [ "podman.service" "network-online.target" ];
  };
} || echo "")
          
          if [ -n "$containers" ]; then
            for container in $containers; do
              echo "Found container to restart: $container"
              if ${pkgs.podman}/bin/podman restart "$container" >/dev/null 2>&1; then
                echo "Successfully restarted: $container"
                restarted_containers+=("$container")
                ((restarted_count++))
              else
                echo "Failed to restart: $container"
                failed_operations+=("restart $container")
                ((failed_count++))
              fi
            done
          else
            echo "No containers found using image: $image"
            # Try alternative approach - look for containers by image ID
            echo "Trying to find containers by image ID..."
            containers_by_id=$(${pkgs.podman}/bin/podman ps -a --format="{{.Names}} {{.Image}} {{.ImageID}}" 2>/dev/null | grep "$new_id" | cut -d' ' -f1 || echo "")
            
            if [ -n "$containers_by_id" ]; then
              for container in $containers_by_id; do
                echo "Found container by ID to restart: $container"
                if ${pkgs.podman}/bin/podman restart "$container" >/dev/null 2>&1; then
                  echo "Successfully restarted: $container"
                  restarted_containers+=("$container")
                  ((restarted_count++))
                else
                  echo "Failed to restart: $container"
                  failed_operations+=("restart $container")
                  ((failed_count++))
                fi
              done
            else
              echo "No containers found for updated image: $image"
            fi
          fi
        else
          echo "No update available for: $image"
        fi
      else
        echo "Failed to pull: $image"
        failed_operations+=("pull $image")
        ((failed_count++))
      fi
    done
    
    # Prepare Discord notification
    timestamp=$(date -Iseconds)
    hostname=$(hostname)
    
    # Create summary message
    if [ $updated_count -eq 0 ] && [ $failed_count -eq 0 ]; then
      summary="✅ All container images are up to date"
      color=3066993  # Green
    elif [ $failed_count -eq 0 ]; then
      summary="🔄 Successfully updated $updated_count image(s) and restarted $restarted_count container(s)"
      color=3447003  # Blue
    else
      summary="⚠️ Updated $updated_count image(s), restarted $restarted_count container(s), but encountered $failed_count error(s)"
      color=15105570  # Orange
    fi
    
    # Build detailed message
    details=""
    if [ ''${#updated_images[@]} -gt 0 ]; then
      details="$details**Updated Images:**\n"
      for img in "''${updated_images[@]}"; do
        details="$details• $img\n"
      done
      details="$details\n"
    fi
    
    if [ ''${#restarted_containers[@]} -gt 0 ]; then
      details="$details**Restarted Containers:**\n"
      for container in "''${restarted_containers[@]}"; do
        details="$details• $container\n"
      done
      details="$details\n"
    fi
    
    if [ ''${#failed_operations[@]} -gt 0 ]; then
      details="$details**Failed Operations:**\n"
      for operation in "''${failed_operations[@]}"; do
        details="$details• $operation\n"
      done
    fi
    
    # Send Discord notification
    echo "Sending Discord notification..."
    
    webhook_url=$(cat "${discordWebhookUrl}")
    
    payload=$(${pkgs.jq}/bin/jq -n \
      --arg summary "$summary" \
      --arg details "$details" \
      --arg hostname "$hostname" \
      --arg timestamp "$timestamp" \
      --argjson color "$color" \
      '{
        embeds: [{
          title: "Container Update Report",
          description: $summary,
          color: $color,
          fields: [
            {
              name: "Details",
              value: (if $details == "" then "No additional details" else $details end),
              inline: false
            }
          ],
          footer: {
            text: ("Host: " + $hostname)
          },
          timestamp: $timestamp
        }]
      }')
    
    if ${pkgs.curl}/bin/curl -X POST \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "$webhook_url" \
      --silent --show-error --fail; then
      echo "Discord notification sent successfully"
    else
      echo "Failed to send Discord notification"
    fi
    
    echo "Container update process completed at $(date)"
    echo "Summary: Updated $updated_count images, restarted $restarted_count containers, $failed_count failures"
  '';
in
{
  # Define the sops secret for the Discord webhook URL
  sops.secrets.discord-webhook-url = {
    sopsFile = ./discord-webhook.yaml;  # Adjust path to your secrets file
    owner = "root";
    group = "root";
    mode = "0400";
  };

  systemd.timers.update-containers = {
    timerConfig = {
      Unit = "update-containers.service";
      OnCalendar = "daily";  # Changed from "Mon 02:00" to "daily"
      Persistent = true;  # Run if system was down during scheduled time
    };
    wantedBy = [ "timers.target" ];
  };

  systemd.services.update-containers = {
    description = "Update container images and restart affected containers";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe updateScript;
      # Security settings
      User = "root";  # Need root access for sops secrets and podman
      PrivateTmp = true;
      ProtectHome = true;
      NoNewPrivileges = true;
      # Allow access to podman socket
      SupplementaryGroups = [ "podman" ];
    };
    # Ensure podman is available
    wants = [ "podman.service" ];
    after = [ "podman.service" "network-online.target" ];
  };
}
