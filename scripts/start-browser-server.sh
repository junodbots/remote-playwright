#!/bin/bash
# Start Chrome/Chromium with remote debugging enabled
# Usage: ./start-browser-server.sh [port] [profile_dir]

set -e

PORT=${1:-9222}
PROFILE_DIR=${2:-"$HOME/.chrome-remote-profile"}

echo "Starting Chrome with remote debugging on port $PORT..."
echo "Profile directory: $PROFILE_DIR"

# Detect Chrome/Chromium executable
if command -v chromium &> /dev/null; then
    CHROME_BIN="chromium"
elif command -v chromium-browser &> /dev/null; then
    CHROME_BIN="chromium-browser"
elif command -v google-chrome &> /dev/null; then
    CHROME_BIN="google-chrome"
elif command -v google-chrome-stable &> /dev/null; then
    CHROME_BIN="google-chrome-stable"
else
    echo "Error: Chrome/Chromium not found. Please install Chrome or Chromium."
    exit 1
fi

echo "Using browser: $CHROME_BIN"

# Create profile directory if it doesn't exist
mkdir -p "$PROFILE_DIR"

# Kill any existing Chrome processes on this port
pkill -f "remote-debugging-port=$PORT" || true
sleep 1

# Start Chrome with remote debugging
$CHROME_BIN \
    --remote-debugging-port=$PORT \
    --user-data-dir="$PROFILE_DIR" \
    --no-first-run \
    --no-default-browser-check \
    --enable-automation \
    --password-store=basic \
    --use-mock-keychain \
    --force-color-profile=srgb \
    --disable-background-timer-throttling \
    --disable-backgrounding-occluded-windows \
    --disable-renderer-backgrounding \
    --disable-features=TranslateUI \
    --disable-ipc-flooding-protection \
    --disable-dev-shm-usage \
    --disable-features=IsolateOrigins,site-per-process \
    --disable-site-isolation-trials \
    about:blank &

CHROME_PID=$!
echo "Chrome started with PID: $CHROME_PID"
echo "Remote debugging available at: http://localhost:$PORT"
echo ""
echo "To test the connection, run:"
echo "  curl http://localhost:$PORT/json/version"
echo ""
echo "Press Ctrl+C to stop the browser"

# Wait for Chrome
wait $CHROME_PID
