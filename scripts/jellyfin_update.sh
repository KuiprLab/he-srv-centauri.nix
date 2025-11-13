#!/bin/sh
# Script to trigger Jellyfin library scan when Zurg detects changes
# Arguments passed: $1 = media type (movies/shows/anime), $2 = action (add/remove/update)

JELLYFIN_HOST="http://jellyfin:8096"

# Log the event
echo "[$(date)] Zurg detected change - Type: $1, Action: $2"

# Trigger a library scan for all libraries
# Using curl to call the Jellyfin API
# Note: This triggers a scan without requiring an API key
curl -X POST "${JELLYFIN_HOST}/Library/Refresh" \
	-H "Content-Type: application/json" \
	2>/dev/null

echo "[$(date)] Jellyfin library scan triggered"
