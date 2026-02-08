#!/bin/bash
#
# Admin Monitoring Script
# View and monitor any agent's browser
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_NAME="${SERVER_NAME:-vm2.junod.dev}"
DATA_DIR="${DATA_DIR:-$HOME/.chrome-agents}"
PID_DIR="${PID_DIR:-$DATA_DIR/pids}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# List all agents and their status
list_agents() {
    echo ""
    echo "=================================="
    echo "Agent Browser Monitor"
    echo "=================================="
    echo ""
    
    local count=0
    for port_file in "$PID_DIR"/*_port; do
        [ -f "$port_file" ] || continue
        ((count++))
        
        local agent_name=$(basename "$port_file" _port)
        local port=$(cat "$port_file" 2>/dev/null || echo "N/A")
        local pid_file="$PID_DIR/${agent_name}.pid"
        local pid=$(cat "$pid_file" 2>/dev/null || echo "N/A")
        local status="stopped"
        local url="N/A"
        
        if [ "$pid" != "N/A" ] && kill -0 "$pid" 2>/dev/null; then
            status="running"
            # Get current URL
            url=$(curl -s "http://localhost:$port/json/list" 2>/dev/null | grep -o '"url": "[^"]*"' | head -1 | cut -d'"' -f4 || echo "unknown")
            [ -z "$url" ] && url="(blank or loading)"
        fi
        
        echo -e "${CYAN}Agent:${NC} $agent_name"
        echo "  Port: $port"
        echo "  PID: $pid"
        echo "  Status: $status"
        echo "  Current URL: $url"
        echo ""
    done
    
    if [ "$count" -eq 0 ]; then
        log_warn "No agent browsers found"
        echo "Start browsers with: ./scripts/server-manager.sh start <agent-name>"
    else
        echo "Total agents: $count"
    fi
    echo ""
}

# Take screenshot of agent's browser
screenshot() {
    local agent_name="${1:-}"
    
    if [ -z "$agent_name" ]; then
        log_error "Agent name required"
        echo "Usage: $0 screenshot <agent-name> [output-file]"
        exit 1
    fi
    
    local port_file="$PID_DIR/${agent_name}_port"
    if [ ! -f "$port_file" ]; then
        log_error "No browser found for agent '$agent_name'"
        exit 1
    fi
    
    local port=$(cat "$port_file")
    local output="${2:-/tmp/screenshot-${agent_name}-$(date +%Y%m%d-%H%M%S).png}"
    
    log_info "Taking screenshot of $agent_name's browser..."
    
    # Use agent-browser or Playwright to take screenshot
    if command -v agent-browser &> /dev/null; then
        agent-browser --cdp "$port" screenshot --output "$output" 2>/dev/null || {
            # Fallback to Playwright
            node -e "
                const { chromium } = require('playwright');
                (async () => {
                    const browser = await chromium.connectOverCDP('http://localhost:$port');
                    const page = browser.contexts()[0]?.pages()[0];
                    if (page) await page.screenshot({ path: '$output' });
                    await browser.close();
                })();
            " 2>/dev/null
        }
    else
        # Use curl to Chrome's screenshot API
        curl -s "http://localhost:$port/json/list" | \
            python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'] if d else '')" | \
            xargs -I {} curl -s "http://localhost:$port/screenshot/{}" > "$output" 2>/dev/null || {
            log_error "Screenshot failed. Install agent-browser or Playwright."
            exit 1
        }
    fi
    
    if [ -f "$output" ]; then
        log_success "Screenshot saved: $output"
        echo ""
        echo "To view:"
        echo "  macOS: open $output"
        echo "  Linux: xdg-open $output"
    else
        log_error "Screenshot failed"
    fi
}

# View browser via VNC (if running with display)
view_vnc() {
    local agent_name="${1:-}"
    
    if [ -z "$agent_name" ]; then
        log_error "Agent name required"
        echo "Usage: $0 view <agent-name>"
        exit 1
    fi
    
    # Check if VNC is running
    local vnc_port=$(netstat -tlnp 2>/dev/null | grep x11vnc | awk '{print $4}' | cut -d: -f2 | head -1)
    
    if [ -z "$vnc_port" ]; then
        log_warn "VNC not running. Starting VNC server..."
        
        # Check if Chrome has a display
        local port_file="$PID_DIR/${agent_name}_port"
        local port=$(cat "$port_file" 2>/dev/null || echo "")
        
        if [ -z "$port" ]; then
            log_error "No browser found for agent '$agent_name'"
            exit 1
        fi
        
        # Try to find Chrome's display
        local chrome_pid=$(cat "$PID_DIR/${agent_name}.pid" 2>/dev/null)
        local display=$(ps -p "$chrome_pid" -o cmd= 2>/dev/null | grep -o 'DISPLAY=[^ ]*' | cut -d= -f2 || echo ":99")
        
        # Start VNC
        x11vnc -display "$display" -forever -shared -nopw -rfbport 5900 > /tmp/x11vnc.log 2>&1 &
        sleep 2
        vnc_port=5900
        
        log_success "VNC started on port $vnc_port"
    fi
    
    echo ""
    echo "=================================="
    echo "VNC Connection Info"
    echo "=================================="
    echo ""
    echo "VNC Server running on port: $vnc_port"
    echo ""
    echo "Connection options:"
    echo ""
    echo "Option 1 - Direct (if firewall allows):"
    echo "  vncviewer $SERVER_NAME:$vnc_port"
    echo ""
    echo "Option 2 - SSH Tunnel (recommended):"
    echo "  ssh -L 5900:localhost:$vnc_port $SERVER_NAME"
    echo "  vncviewer localhost:5900"
    echo ""
    echo "Option 3 - From this server (if you have GUI):"
    echo "  vncviewer localhost:$vnc_port"
    echo ""
    echo "Password: (none - set with: x11vnc -storepasswd <password> ~/.vnc/passwd)"
    echo ""
}

# Execute JavaScript in agent's browser
execute() {
    local agent_name="${1:-}"
    local script="${2:-}"
    
    if [ -z "$agent_name" ] || [ -z "$script" ]; then
        log_error "Agent name and script required"
        echo "Usage: $0 exec <agent-name> '<javascript-code>'"
        echo "Example: $0 exec dev1 'document.title'"
        exit 1
    fi
    
    local port_file="$PID_DIR/${agent_name}_port"
    if [ ! -f "$port_file" ]; then
        log_error "No browser found for agent '$agent_name'"
        exit 1
    fi
    
    local port=$(cat "$port_file")
    
    log_info "Executing script in $agent_name's browser..."
    
    if command -v agent-browser &> /dev/null; then
        agent-browser --cdp "$port" eval "$script"
    else
        # Use Playwright
        node -e "
            const { chromium } = require('playwright');
            (async () => {
                const browser = await chromium.connectOverCDP('http://localhost:$port');
                const page = browser.contexts()[0]?.pages()[0];
                if (page) {
                    const result = await page.evaluate(() => { $script });
                    console.log(result);
                }
                await browser.close();
            })();
        "
    fi
}

# Navigate agent's browser
navigate() {
    local agent_name="${1:-}"
    local url="${2:-}"
    
    if [ -z "$agent_name" ] || [ -z "$url" ]; then
        log_error "Agent name and URL required"
        echo "Usage: $0 navigate <agent-name> <url>"
        exit 1
    fi
    
    local port_file="$PID_DIR/${agent_name}_port"
    if [ ! -f "$port_file" ]; then
        log_error "No browser found for agent '$agent_name'"
        exit 1
    fi
    
    local port=$(cat "$port_file")
    
    log_info "Navigating $agent_name's browser to $url..."
    
    if command -v agent-browser &> /dev/null; then
        agent-browser --cdp "$port" open "$url"
    else
        # Use curl to navigate
        curl -s "http://localhost:$port/json/new?$url" > /dev/null
        log_success "Navigation complete"
    fi
}

# Interactive menu
interactive() {
    while true; do
        echo ""
        echo "=================================="
        echo "Admin Browser Monitor"
        echo "=================================="
        echo ""
        echo "1. List all agents"
        echo "2. View agent browser (VNC)"
        echo "3. Take screenshot"
        echo "4. Execute JavaScript"
        echo "5. Navigate to URL"
        echo "6. Start browser for agent"
        echo "7. Stop browser for agent"
        echo "0. Exit"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1)
                list_agents
                ;;
            2)
                read -p "Agent name: " agent
                view_vnc "$agent"
                ;;
            3)
                read -p "Agent name: " agent
                screenshot "$agent"
                ;;
            4)
                read -p "Agent name: " agent
                read -p "JavaScript code: " script
                execute "$agent" "$script"
                ;;
            5)
                read -p "Agent name: " agent
                read -p "URL: " url
                navigate "$agent" "$url"
                ;;
            6)
                read -p "Agent name: " agent
                ./scripts/server-manager.sh start "$agent"
                ;;
            7)
                read -p "Agent name: " agent
                ./scripts/server-manager.sh stop "$agent"
                ;;
            0)
                exit 0
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
    done
}

# Show help
help() {
    echo "Admin Browser Monitor"
    echo ""
    echo "Usage: $0 <command> [args]"
    echo ""
    echo "Commands:"
    echo "  list                    List all agents and their browsers"
    echo "  view <agent>            View browser via VNC"
    echo "  screenshot <agent>      Take screenshot of agent's browser"
    echo "  exec <agent> <script>   Execute JavaScript in agent's browser"
    echo "  navigate <agent> <url>  Navigate agent's browser to URL"
    echo "  interactive             Interactive menu mode"
    echo "  help                    Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 view dev1"
    echo "  $0 screenshot dev1"
    echo "  $0 exec dev1 'document.title'"
    echo "  $0 navigate dev1 https://example.com"
    echo ""
}

# Main
case "${1:-}" in
    list|ls|"")
        list_agents
        ;;
    view)
        view_vnc "${2:-}"
        ;;
    screenshot|shot)
        screenshot "${2:-}" "${3:-}"
        ;;
    exec|execute|eval)
        execute "${2:-}" "${3:-}"
        ;;
    navigate|nav|open)
        navigate "${2:-}" "${3:-}"
        ;;
    interactive|menu)
        interactive
        ;;
    help|--help|-h)
        help
        ;;
    *)
        log_error "Unknown command: $1"
        help
        exit 1
        ;;
esac
