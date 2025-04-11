#!/usr/bin/env bash

# Generate Argon2id hashed passwords for Authelia users
# This script requires docker/podman to be installed

# Check if docker/podman is available
if command -v docker &> /dev/null; then
    CMD="docker"
elif command -v podman &> /dev/null; then
    CMD="podman"
else
    echo "Either docker or podman is required but neither is installed."
    exit 1
fi

# Ask for the password
read -s -p "Enter the password to hash: " PASSWORD
echo ""
read -s -p "Confirm password: " PASSWORD_CONFIRM
echo ""

if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo "Passwords do not match!"
    exit 1
fi

# Use Authelia's own container to generate the hash
echo "Generating Argon2id hash..."
HASH=$($CMD run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password "$PASSWORD")

echo "Password hash generated."
echo ""
echo "For users.yml, copy this into your user's configuration:"
echo "    password: \"$HASH\""
