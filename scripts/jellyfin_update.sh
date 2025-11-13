#!/bin/sh
# Script to trigger Jellyfin library scan when Zurg detects changes
# Arguments passed: $1 = media type (movies/shows/anime), $2 = action (add/remove/update)

JELLYFIN_HOST="http://jellyfin:8096"

# Check if API key is set
if [ -z "$JELLYFIN_API_KEY" ]; then
	echo "[$(date)] ERROR: JELLYFIN_API_KEY environment variable is not set"
	exit 1
fi

# Log the event
echo "[$(date)] Zurg detected change - Type: $1, Action: $2"

# Trigger a library scan for all libraries
# Using curl to call the Jellyfin API with authentication
curl -X POST "${JELLYFIN_HOST}/Library/Refresh" \
	-H "Content-Type: application/json" \
	-H "X-Emby-Token: ${JELLYFIN_API_KEY}" \
	2>/dev/null

if [ $? -eq 0 ]; then
	echo "[$(date)] Jellyfin library scan triggered successfully"
else
	echo "[$(date)] ERROR: Failed to trigger Jellyfin library scan"
	exit 1
fi
