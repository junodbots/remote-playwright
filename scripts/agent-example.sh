#!/bin/bash
# Example agent usage with agent-browser via CDP
# Usage: ./agent-example.sh [command]

CDP_PORT=${CDP_PORT:-9222}
COMMAND=${1:-"snapshot"}

echo "Running agent-browser command: $COMMAND"
echo "CDP Port: $CDP_PORT"
echo ""

# Check if agent-browser is installed
if ! command -v agent-browser &> /dev/null; then
    echo "Error: agent-browser not found. Install it with:"
    echo "  npm run install:agent-browser"
    exit 1
fi

# Run the command with CDP connection
case $COMMAND in
    "snapshot")
        echo "Taking snapshot of current page..."
        agent-browser --cdp "$CDP_PORT" snapshot
        ;;
    "open")
        URL=${2:-"example.com"}
        echo "Opening URL: $URL"
        agent-browser --cdp "$CDP_PORT" open "$URL"
        ;;
    "eval")
        SCRIPT=${2:-"document.title"}
        echo "Evaluating: $SCRIPT"
        agent-browser --cdp "$CDP_PORT" eval "$SCRIPT"
        ;;
    "tab")
        echo "Listing tabs..."
        agent-browser --cdp "$CDP_PORT" tab
        ;;
    "close")
        echo "Closing browser..."
        agent-browser --cdp "$CDP_PORT" close
        ;;
    "help")
        echo "Available commands:"
        echo "  snapshot     - Take accessibility snapshot of current page"
        echo "  open <url>   - Open a URL in the browser"
        echo "  eval <js>    - Evaluate JavaScript in the browser"
        echo "  tab          - List all tabs"
        echo "  close        - Close the browser"
        echo "  help         - Show this help"
        echo ""
        echo "You can also use agent-browser directly:"
        echo "  agent-browser --cdp $CDP_PORT <command>"
        ;;
    *)
        # Pass through any other command
        agent-browser --cdp "$CDP_PORT" "$@"
        ;;
esac
