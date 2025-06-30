#!/bin/bash
# A robust script to set up a Cloudflare Tunnel.
# It creates the tunnel, then reliably finds its ID using the `list` command.
set -e

# --- Configuration ---
TUNNEL_NAME="homelab-k3s-tunnel"
DOMAIN_NAME="milenika.dev"
CREDENTIALS_DIR="$HOME/.cloudflared"

# --- Login (if needed) ---
echo "### Step 1: Authenticating with Cloudflare..."
if [ ! -f "$CREDENTIALS_DIR/cert.pem" ]; then
    cloudflared tunnel login
fi
echo "Authentication complete."

# --- Create Tunnel ---
echo "### Step 2: Creating tunnel '$TUNNEL_NAME' (if it doesn't exist)..."
# This command creates the tunnel and its credential file.
# We use '|| true' to prevent the script from exiting if the tunnel already exists.
cloudflared tunnel create $TUNNEL_NAME || true

# --- Get Tunnel Info Reliably ---
echo "### Step 3: Getting tunnel UUID from Cloudflare..."
# This is the reliable way: list the tunnels and find the one we want.
TUNNEL_UUID=$(cloudflared tunnel list -o json | jq -r --arg name "$TUNNEL_NAME" '.[] | select(.name == $name) | .id')

if [ -z "$TUNNEL_UUID" ]; then
    echo "FATAL: Could not find tunnel '$TUNNEL_NAME' after attempting to create it."
    exit 1
fi
echo "Found tunnel UUID: $TUNNEL_UUID"

# --- Locate Credentials File ---
echo "### Step 4: Locating credentials file..."
CREDENTIALS_FILE="$CREDENTIALS_DIR/$TUNNEL_UUID.json"
if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "FATAL: Credentials file not found at $CREDENTIALS_FILE"
    exit 1
fi
echo "Credentials file found."

# --- Create Kubernetes Secret ---
echo "### Step 5: Creating Kubernetes secret 'tunnel-credentials'..."
kubectl create secret generic tunnel-credentials \
  --from-file=credentials.json=$CREDENTIALS_FILE \
  --namespace=default \
  --dry-run=client -o yaml | kubectl apply -f -

# --- Route DNS ---
echo "### Step 6: Routing DNS to the tunnel..."
cloudflared tunnel route dns $TUNNEL_NAME $DOMAIN_NAME
cloudflared tunnel route dns $TUNNEL_NAME "*.$DOMAIN_NAME"

echo "---"
echo "✅ CLI setup complete!"
echo "You can now run the Ansible playbook."
