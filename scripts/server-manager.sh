#!/bin/bash
#
# Multi-Agent Browser Server Manager
# Manages multiple isolated Chrome instances for different agents
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_NAME="${SERVER_NAME:-vm2.junod.dev}"
BASE_PORT="${BASE_PORT:-9222}"
MAX_AGENTS="${MAX_AGENTS:-10}"
DATA_DIR="${DATA_DIR:-$HOME/.chrome-agents}"
LOG_DIR="${LOG_DIR:-$DATA_DIR/logs}"
PID_DIR="${PID_DIR:-$DATA_DIR/pids}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Initialize directories
init() {
    mkdir -p "$DATA_DIR" "$LOG_DIR" "$PID_DIR"
    log_success "Initialized multi-agent browser server"
    log_info "Data directory: $DATA_DIR"
    log_info "Port range: $BASE_PORT-$((BASE_PORT + MAX_AGENTS - 1))"
}

# Find Chrome binary
find_chrome() {
    # Check for Playwright Chrome first
    if [ -f "$HOME/.cache/ms-playwright/chromium-*/chrome-linux64/chrome" ]; then
        ls -t $HOME/.cache/ms-playwright/chromium-*/chrome-linux64/chrome 2>/dev/null | head -1
        return
    fi
    
    # Check common locations
    for chrome in google-chrome chromium chromium-browser; do
        if command -v "$chrome" &> /dev/null; then
            which "$chrome"
            return
        fi
    done
    
    log_error "Chrome not found. Install Chrome or Playwright."
    exit 1
}

# Get available port
get_available_port() {
    local agent_name="${1:-default}"
    local port_file="$PID_DIR/agent_${agent_name}_port"
    
    # Check if agent already has a port assigned
    if [ -f "$port_file" ]; then
        cat "$port_file"
        return
    fi
    
    # Find next available port
    for i in $(seq 0 $((MAX_AGENTS - 1))); do
        local port=$((BASE_PORT + i))
        if ! lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            echo "$port" > "$port_file"
            echo "$port"
            return
        fi
    done
    
    log_error "No available ports. Max agents: $MAX_AGENTS"
    exit 1
}

# Start browser for an agent
start_browser() {
    local agent_name="${1:-default}"
    local port=$(get_available_port "$agent_name")
    local agent_dir="$DATA_DIR/$agent_name"
    local log_file="$LOG_DIR/${agent_name}.log"
    local pid_file="$PID_DIR/${agent_name}.pid"
    local port_file="$PID_DIR/${agent_name}_port"
    
    # Check if already running
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        log_warn "Browser already running for agent '$agent_name' on port $port"
        echo ""
        echo "Connection info:"
        echo "  Port: $port"
        echo "  SSH Command: ssh -N -L ${port}:localhost:${port} ${SERVER_NAME}"
        echo "  CDP URL: http://localhost:${port}"
        return
    fi
    
    # Find Chrome binary
    local chrome_bin=$(find_chrome)
    log_info "Using Chrome: $chrome_bin"
    
    # Create agent profile directory
    mkdir -p "$agent_dir"
    
    # Start Chrome with virtual display if available
    local display_arg=""
    if [ -n "$DISPLAY" ]; then
        display_arg="--ozone-platform=x11"
    else
        display_arg="--headless=new"
    fi
    
    log_info "Starting browser for agent '$agent_name' on port $port..."
    
    nohup "$chrome_bin" \
        --remote-debugging-port="$port" \
        --user-data-dir="$agent_dir" \
        --no-first-run \
        --no-default-browser-check \
        --no-sandbox \
        --disable-setuid-sandbox \
        --disable-dev-shm-usage \
        --disable-features=IsolateOrigins,site-per-process \
        $display_arg \
        --window-size=1280,800 \
        about:blank \
        > "$log_file" 2>&1 &
    
    local pid=$!
    echo "$pid" > "$pid_file"
    echo "$port" > "$port_file"
    
    # Wait for Chrome to start
    sleep 2
    
    # Verify it's running
    if kill -0 "$pid" 2>/dev/null && curl -s "http://localhost:$port/json/version" >/dev/null 2>&1; then
        log_success "Browser started successfully for agent '$agent_name'"
        echo ""
        echo "=================================="
        echo "Agent: $agent_name"
        echo "Port: $port"
        echo "PID: $pid"
        echo "Profile: $agent_dir"
        echo "=================================="
        echo ""
        echo "Connection instructions:"
        echo ""
        echo "1. Create SSH tunnel (run locally):"
        echo "   ssh -N -L ${port}:localhost:${port} ${SERVER_NAME}"
        echo ""
        echo "2. Connect via CDP:"
        echo "   curl http://localhost:${port}/json/version"
        echo ""
        echo "3. Use with Playwright:"
        echo "   chromium.connectOverCDP('http://localhost:${port}')"
        echo ""
        echo "4. Admin monitoring (from server):"
        echo "   ./scripts/admin-monitor.sh view $agent_name"
        echo ""
    else
        log_error "Failed to start browser for agent '$agent_name'"
        rm -f "$pid_file" "$port_file"
        exit 1
    fi
}

# Stop browser for an agent
stop_browser() {
    local agent_name="${1:-}"
    
    if [ -z "$agent_name" ]; then
        log_error "Agent name required"
        echo "Usage: $0 stop <agent-name>"
        exit 1
    fi
    
    local pid_file="$PID_DIR/${agent_name}.pid"
    local port_file="$PID_DIR/${agent_name}_port"
    
    if [ ! -f "$pid_file" ]; then
        log_warn "No browser found for agent '$agent_name'"
        return
    fi
    
    local pid=$(cat "$pid_file")
    
    if kill -0 "$pid" 2>/dev/null; then
        log_info "Stopping browser for agent '$agent_name' (PID: $pid)..."
        kill "$pid" 2>/dev/null || true
        sleep 1
        
        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid" 2>/dev/null || true
        fi
        
        log_success "Browser stopped for agent '$agent_name'"
    else
        log_warn "Browser not running for agent '$agent_name'"
    fi
    
    rm -f "$pid_file" "$port_file"
}

# Stop all browsers
stop_all() {
    log_info "Stopping all agent browsers..."
    
    for pid_file in "$PID_DIR"/*.pid; do
        [ -f "$pid_file" ] || continue
        
        local agent_name=$(basename "$pid_file" .pid)
        stop_browser "$agent_name"
    done
    
    log_success "All browsers stopped"
}

# List all running browsers
list_browsers() {
    log_info "Active agent browsers:"
    echo ""
    printf "%-15s %-8s %-8s %-10s %-20s\n" "AGENT" "PORT" "PID" "STATUS" "CONNECTED"
    echo "--------------------------------------------------------------------------------"
    
    for pid_file in "$PID_DIR"/*.pid; do
        [ -f "$pid_file" ] || continue
        
        local agent_name=$(basename "$pid_file" .pid)
        local pid=$(cat "$pid_file" 2>/dev/null || echo "N/A")
        local port_file="$PID_DIR/${agent_name}_port"
        local port=$(cat "$port_file" 2>/dev/null || echo "N/A")
        local status="stopped"
        local connected="no"
        
        if [ "$pid" != "N/A" ] && kill -0 "$pid" 2>/dev/null; then
            status="running"
            if curl -s "http://localhost:$port/json/version" >/dev/null 2>&1; then
                connected="yes"
            fi
        fi
        
        printf "%-15s %-8s %-8s %-10s %-20s\n" "$agent_name" "$port" "$pid" "$status" "$connected"
    done
    
    echo ""
    echo "To view a browser via VNC (if enabled):"
    echo "  ./scripts/admin-monitor.sh view <agent-name>"
}

# Show status
status() {
    echo ""
    echo "=================================="
    echo "Multi-Agent Browser Server"
    echo "=================================="
    echo "Server: $SERVER_NAME"
    echo "Base Port: $BASE_PORT"
    echo "Max Agents: $MAX_AGENTS"
    echo "Data Directory: $DATA_DIR"
    echo ""
    
    local running_count=$(ls -1 "$PID_DIR"/*.pid 2>/dev/null | wc -l)
    echo "Active browsers: $running_count"
    echo ""
    
    if [ "$running_count" -gt 0 ]; then
        list_browsers
    fi
}

# Main command handler
case "${1:-}" in
    init)
        init
        ;;
    start)
        start_browser "${2:-default}"
        ;;
    stop)
        if [ "${2:-}" = "all" ]; then
            stop_all
        else
            stop_browser "${2:-}"
        fi
        ;;
    list|ls)
        list_browsers
        ;;
    status)
        status
        ;;
    help|--help|-h)
        echo "Multi-Agent Browser Server Manager"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  init                    Initialize server directories"
        echo "  start <agent-name>      Start browser for agent"
        echo "  stop <agent-name>       Stop browser for agent"
        echo "  stop all                Stop all browsers"
        echo "  list                    List all browsers"
        echo "  status                  Show server status"
        echo ""
        echo "Environment Variables:"
        echo "  SERVER_NAME    Server hostname (default: vm2.junod.dev)"
        echo "  BASE_PORT      Starting port number (default: 9222)"
        echo "  MAX_AGENTS     Maximum number of agents (default: 10)"
        echo "  DATA_DIR       Directory for agent profiles"
        echo ""
        echo "Examples:"
        echo "  $0 init"
        echo "  $0 start agent1"
        echo "  $0 start agent2"
        echo "  $0 list"
        echo "  $0 stop agent1"
        echo "  $0 stop all"
        ;;
    *)
        log_error "Unknown command: ${1:-}"
        echo "Run '$0 help' for usage"
        exit 1
        ;;
esac
