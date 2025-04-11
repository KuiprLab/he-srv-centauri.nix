#!/usr/bin/env bash


eval $(op signin)
# Create the sops directory
mkdir -p /var/lib/sops
chmod 700 /var/lib/sops
# Check if 1Password CLI is configured
if ! op user list &>/dev/null; then
  echo "1Password CLI is not configured. Please run 'op signin' first."
  exit 1
fi

# Get age key from 1Password, assuming it's stored as a secure note
# Replace "Age Key" with the actual item name and "private_key" with the field name
AGE_KEY=$(op read "op://OpsVault/he-srv-centauri-sops-key/age")

if [ -z "$AGE_KEY" ]; then
  echo "Failed to retrieve age key from 1Password"
  exit 1
fi

# Write the key to the file
echo "$AGE_KEY" > /var/lib/sops/age-key.txt
chmod 600 /var/lib/sops/age-key.txt

echo "Successfully initialized age key for sops-nix"
