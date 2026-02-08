#!/bin/bash
#
# Agent Connection Script
# Agents run this to connect to their assigned browser
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_NAME="${SERVER_NAME:-vm2.junod.dev}"
AGENT_NAME="${AGENT_NAME:-$(whoami)}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Get agent's assigned port from server
get_agent_port() {
    local agent_name="$1"
    
    # Check if we have a cached port
    local cache_file="$HOME/.agent-browser-port"
    if [ -f "$cache_file" ]; then
        local cached_port=$(cat "$cache_file")
        # Verify it's still valid
        if ssh "$SERVER_NAME" "test -f ~/.chrome-agents/pids/${agent_name}_port" 2>/dev/null; then
            local server_port=$(ssh "$SERVER_NAME" "cat ~/.chrome-agents/pids/${agent_name}_port" 2>/dev/null)
            if [ "$cached_port" = "$server_port" ]; then
                echo "$cached_port"
                return
            fi
        fi
    fi
    
    # Get port from server
    local port=$(ssh "$SERVER_NAME" "cat ~/.chrome-agents/pids/${agent_name}_port" 2>/dev/null || echo "")
    
    if [ -n "$port" ]; then
        echo "$port" > "$cache_file"
        echo "$port"
    else
        echo ""
    fi
}

# Main connect function
connect() {
    echo ""
    echo "=================================="
    echo "Agent Browser Connection"
    echo "=================================="
    echo "Agent: $AGENT_NAME"
    echo "Server: $SERVER_NAME"
    echo ""
    
    # Step 1: Check if browser is running on server
    log_info "Checking browser status on server..."
    
    local port=$(get_agent_port "$AGENT_NAME")
    
    if [ -z "$port" ]; then
        log_warn "No browser assigned for agent '$AGENT_NAME'"
        echo ""
        echo "Please ask the admin to start a browser for you:"
        echo "  ssh $SERVER_NAME"
        echo "  ./scripts/server-manager.sh start $AGENT_NAME"
        echo ""
        exit 1
    fi
    
    log_success "Found browser on port $port"
    
    # Step 2: Check if SSH tunnel exists
    log_info "Checking SSH tunnel..."
    
    local tunnel_pid=$(lsof -Pi :$port -sTCP:LISTEN -t 2>/dev/null || echo "")
    
    if [ -n "$tunnel_pid" ]; then
        # Verify it's an SSH tunnel
        if ps -p "$tunnel_pid" -o comm= 2>/dev/null | grep -q ssh; then
            log_success "SSH tunnel already active (PID: $tunnel_pid)"
        else
            log_warn "Port $port is in use by another process"
            echo "Please use a different agent name or stop the conflicting process"
            exit 1
        fi
    else
        # Create SSH tunnel
        log_info "Creating SSH tunnel to port $port..."
        ssh -N -L "${port}:localhost:${port}" "$SERVER_NAME" &
        local tunnel_pid=$!
        sleep 2
        
        # Verify tunnel
        if kill -0 "$tunnel_pid" 2>/dev/null; then
            log_success "SSH tunnel created (PID: $tunnel_pid)"
        else
            log_error "Failed to create SSH tunnel"
            exit 1
        fi
    fi
    
    # Step 3: Test connection
    log_info "Testing browser connection..."
    
    if curl -s "http://localhost:$port/json/version" >/dev/null 2>&1; then
        log_success "Browser connection successful!"
        
        # Get browser info
        local browser_info=$(curl -s "http://localhost:$port/json/version" 2>/dev/null | grep -o '"Browser": "[^"]*"' | cut -d'"' -f4)
        echo "  Browser: $browser_info"
    else
        log_warn "Browser not responding on port $port"
        echo "The browser may still be starting up. Try again in a few seconds."
    fi
    
    echo ""
    echo "=================================="
    echo "Connection Ready!"
    echo "=================================="
    echo ""
    echo "Your browser is available at:"
    echo "  CDP URL: http://localhost:$port"
    echo ""
    echo "Usage Examples:"
    echo ""
    echo "1. Test connection:"
    echo "   curl http://localhost:$port/json/version"
    echo ""
    echo "2. Use with Playwright:"
    echo "   const browser = await chromium.connectOverCDP('http://localhost:$port');"
    echo ""
    echo "3. Use agent-browser:"
    echo "   agent-browser --cdp $port open https://example.com"
    echo ""
    echo "4. Open DevTools (in Chrome on your machine):"
    echo "   chrome://inspect/#devices"
    echo "   Click 'Configure' and add: localhost:$port"
    echo ""
    echo "=================================="
    echo ""
    echo "To disconnect, press Ctrl+C or run:"
    echo "  kill $tunnel_pid"
    echo ""
    
    # Keep tunnel open
    wait "$tunnel_pid"
}

# Quick check - just test if everything is working
check() {
    local port=$(get_agent_port "$AGENT_NAME")
    
    if [ -z "$port" ]; then
        echo "❌ No browser assigned"
        exit 1
    fi
    
    # Check tunnel
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        # Check browser
        if curl -s "http://localhost:$port/json/version" >/dev/null 2>&1; then
            echo "✅ Connected on port $port"
            exit 0
        else
            echo "⚠️  Tunnel active but browser not responding"
            exit 1
        fi
    else
        echo "❌ No tunnel on port $port"
        exit 1
    fi
}

# Show help
help() {
    echo "Agent Browser Connection Tool"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  connect    Connect to your assigned browser (default)"
    echo "  check      Quick status check"
    echo "  help       Show this help"
    echo ""
    echo "Environment Variables:"
    echo "  SERVER_NAME    Server hostname (default: vm2.junod.dev)"
    echo "  AGENT_NAME     Your agent name (default: $(whoami))"
    echo ""
    echo "Examples:"
    echo "  $0                    # Connect as $(whoami)"
    echo "  AGENT_NAME=dev1 $0    # Connect as dev1"
    echo "  $0 check              # Check connection status"
    echo ""
}

# Main
case "${1:-connect}" in
    connect|"")
        connect
        ;;
    check)
        check
        ;;
    help|--help|-h)
        help
        ;;
    *)
        echo "Unknown command: $1"
        help
        exit 1
        ;;
esac
