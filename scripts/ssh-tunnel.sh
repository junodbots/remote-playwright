#!/bin/bash
# SSH Tunnel helper for remote browser access
# Usage: ./ssh-tunnel.sh [remote_host] [remote_port] [local_port]

set -e

REMOTE_HOST=${1:-"your-server.com"}
REMOTE_PORT=${2:-9222}
LOCAL_PORT=${3:-9222}

echo "Creating SSH tunnel..."
echo "Local port $LOCAL_PORT -> $REMOTE_HOST:$REMOTE_PORT"
echo ""
echo "This will forward your local port $LOCAL_PORT to the remote browser."
echo "Keep this terminal open while using agent-browser."
echo ""

# Create SSH tunnel with auto-reconnect
ssh -N -L "$LOCAL_PORT:localhost:$REMOTE_PORT" \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -o ExitOnForwardFailure=yes \
    "$REMOTE_HOST"
