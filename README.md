# Multi-Agent Remote Browser Server

Centralized browser infrastructure for multiple AI agents. Each agent gets their own isolated Chrome instance that runs on a shared server, accessible via SSH tunnel. Perfect for teams where agents need browsers but you want to monitor, assist, and manage them centrally.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Remote Server (vm2.junod.dev)           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Chrome:9222  │  │ Chrome:9223  │  │ Chrome:9224  │      │
│  │ (Agent: dev1)│  │ (Agent: dev2)│  │ (Agent: dev3)│      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Admin Monitor - View/takeover any agent browser    │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              ▲
              SSH Tunnels     │     SSH Tunnels
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
   ┌────▼────┐           ┌────▼────┐           ┌────▼────┐
   │ Agent 1 │           │ Agent 2 │           │ Agent 3 │
   │(dev1)   │           │(dev2)   │           │(dev3)   │
   └─────────┘           └─────────┘           └─────────┘
```

## Quick Start

### 1. Server Setup (One-time)

On the remote server (e.g., `vm2.junod.dev`):

```bash
cd remote-playwright

# Initialize the multi-agent server
./scripts/server-manager.sh init

# Install Playwright (if not already installed)
npm install
npx playwright install chromium
```

### 2. Start Browser for an Agent

As admin on the server:

```bash
# Start a browser for agent "dev1"
./scripts/server-manager.sh start dev1

# Start browsers for multiple agents
./scripts/server-manager.sh start dev2
./scripts/server-manager.sh start dev3

# See all running browsers
./scripts/server-manager.sh list
```

**Output shows:**
- Port assigned to the agent (e.g., 9222)
- SSH command for the agent to connect
- CDP URL for programmatic access

### 3. Agent Connects (Agent's Machine)

Each agent runs on their local machine:

```bash
cd remote-playwright

# Connect using their assigned agent name
AGENT_NAME=dev1 ./scripts/agent-connect.sh

# Or set it in environment
export AGENT_NAME=dev1
./scripts/agent-connect.sh
```

This will:
1. Find their assigned port on the server
2. Create an SSH tunnel to that port
3. Verify the browser connection
4. Keep the tunnel open

### 4. Admin Monitors/Assists (Optional)

As admin, you can view and help any agent:

```bash
# List all agents and their browsers
./scripts/admin-monitor.sh list

# Take a screenshot of dev1's browser
./scripts/admin-monitor.sh screenshot dev1

# View dev1's browser via VNC (if visual display enabled)
./scripts/admin-monitor.sh view dev1

# Execute JavaScript in dev1's browser
./scripts/admin-monitor.sh exec dev1 "document.title"

# Navigate dev1's browser (to help them)
./scripts/admin-monitor.sh navigate dev1 https://example.com

# Interactive menu mode
./scripts/admin-monitor.sh interactive
```

## Use Case: Secure Login Flow

Here's the workflow for agents who need to log into services securely:

### Step 1: Admin starts browser for agent
```bash
# On server
./scripts/server-manager.sh start alice
# Output shows: Port 9222 assigned
```

### Step 2: Agent connects
```bash
# On Alice's machine
AGENT_NAME=alice ./scripts/agent-connect.sh
# Tunnel created, browser accessible at localhost:9222
```

### Step 3: Admin opens login page for agent
```bash
# On server (or via admin-monitor)
./scripts/admin-monitor.sh navigate alice https://auth.openai.com/...
```

### Step 4: Agent views browser via VNC and logs in
```bash
# Alice connects VNC to see the browser
vncviewer vm2.junod.dev:5900
# Enters her credentials (admin cannot see them)
```

### Step 5: Agent continues with automation
```bash
# Alice uses her local tools with the authenticated browser
agent-browser --cdp 9222 snapshot
# Or Playwright, etc.
```

## Detailed Usage

### Server Manager Commands

```bash
./scripts/server-manager.sh <command> [args]

Commands:
  init                    Create directories and setup
  start <agent-name>      Start browser for agent
  stop <agent-name>       Stop browser for agent
  stop all                Stop all browsers
  list                    List all running browsers
  status                  Show server overview

Environment Variables:
  SERVER_NAME    Server hostname (default: vm2.junod.dev)
  BASE_PORT      Starting port (default: 9222)
  MAX_AGENTS     Max concurrent agents (default: 10)
  DATA_DIR       Where agent profiles are stored
```

### Agent Connection

```bash
./scripts/agent-connect.sh [command]

Commands:
  connect    Connect to assigned browser (default)
  check      Quick status check
  help       Show help

Environment Variables:
  SERVER_NAME    Server to connect to
  AGENT_NAME     Your agent identifier
```

### Admin Monitoring

```bash
./scripts/admin-monitor.sh <command> [args]

Commands:
  list                    List all agents
  view <agent>            View browser via VNC
  screenshot <agent>      Take screenshot
  exec <agent> <script>   Execute JavaScript
  navigate <agent> <url>  Navigate to URL
  interactive             Interactive menu
```

## Programmatic Usage

### For Agents (Node.js/Playwright)

```javascript
import { chromium } from 'playwright';

const CDP_PORT = process.env.CDP_PORT || 9222;
const CDP_URL = `http://localhost:${CDP_PORT}`;

async function run() {
  // Connect to your assigned browser
  const browser = await chromium.connectOverCDP(CDP_URL);
  
  // Get the existing page (already authenticated maybe)
  const context = browser.contexts()[0];
  const page = context.pages()[0];
  
  // Do your work
  await page.goto('https://platform.openai.com');
  // ... automation tasks ...
  
  await browser.close();
}
```

### For Admin (Monitoring)

```javascript
import { chromium } from 'playwright';

async function monitorAgent(agentName, agentPort) {
  const browser = await chromium.connectOverCDP(`http://localhost:${agentPort}`);
  const page = browser.contexts()[0]?.pages()[0];
  
  // Take screenshot for monitoring
  await page.screenshot({ path: `monitor-${agentName}.png` });
  
  // Check what they're doing
  const url = page.url();
  const title = await page.title();
  console.log(`${agentName}: ${title} (${url})`);
  
  await browser.close();
}
```

## Configuration

### Environment Variables

Create a `.env` file on the server:

```bash
# Server configuration
SERVER_NAME=vm2.junod.dev
BASE_PORT=9222
MAX_AGENTS=20
DATA_DIR=/opt/chrome-agents

# For agents (on their local machines)
SERVER_NAME=vm2.junod.dev
AGENT_NAME=$(whoami)
```

### SSH Config (Recommended)

Add to `~/.ssh/config` on agent machines:

```
Host vm2.junod.dev
    HostName vm2.junod.dev
    User your-username
    IdentityFile ~/.ssh/id_rsa
    ServerAliveInterval 30
    ServerAliveCountMax 3
```

## Security Best Practices

1. **SSH Key Authentication Only**
   - Disable password auth on the server
   - Use strong SSH keys

2. **Firewall Rules**
   ```bash
   # On server - only allow localhost access to Chrome ports
   sudo iptables -A INPUT -p tcp --dport 9222:9232 -s 127.0.0.1 -j ACCEPT
   sudo iptables -A INPUT -p tcp --dport 9222:9232 -j DROP
   ```

3. **VNC Password Protection**
   ```bash
   # Set VNC password instead of -nopw
   x11vnc -storepasswd MySecurePass ~/.vnc/passwd
   x11vnc -rfbauth ~/.vnc/passwd ...
   ```

4. **Separate Agent Profiles**
   Each agent gets their own Chrome profile (`--user-data-dir`), so:
   - Cookies/logins are isolated
   - Extensions don't leak between agents
   - Storage is separate

5. **Regular Cleanup**
   ```bash
   # Stop inactive browsers
   ./scripts/server-manager.sh stop all
   
   # Clean up old profiles
   rm -rf ~/.chrome-agents/dev1
   ```

## Troubleshooting

### Agent Can't Connect

```bash
# Check if browser is running on server
ssh vm2.junod.dev "curl -s http://localhost:9222/json/version"

# Check if port is assigned to agent
ssh vm2.junod.dev "cat ~/.chrome-agents/pids/dev1_port"

# Check SSH tunnel on agent's machine
lsof -Pi :9222 -sTCP:LISTEN
```

### Admin Can't Monitor

```bash
# Verify you're on the server
hostname  # Should show vm2.junod.dev

# Check if agent's browser is running
./scripts/admin-monitor.sh list

# Test direct connection
curl http://localhost:9222/json/version
```

### Port Already in Use

```bash
# Find what's using the port
lsof -Pi :9222 -sTCP:LISTEN

# Kill it or use a different port for the agent
./scripts/server-manager.sh stop dev1
./scripts/server-manager.sh start dev1  # Will get next available port
```

### VNC Connection Issues

```bash
# Check if VNC is running
netstat -tlnp | grep 5900

# Restart VNC
pkill x11vnc
x11vnc -display :99 -forever -shared -nopw -rfbport 5900
```

## Advanced Features

### Automatic Port Assignment

The system automatically finds the next available port:

```bash
# dev1 gets 9222
./scripts/server-manager.sh start dev1

# dev2 gets 9223
./scripts/server-manager.sh start dev2

# dev3 gets 9224
./scripts/server-manager.sh start dev3
```

### Persistent Profiles

Agent data persists across restarts:

```bash
# Alice's browser with all her logins
./scripts/server-manager.sh start alice
# She logs in...
./scripts/server-manager.sh stop alice

# Later - her session is still there
./scripts/server-manager.sh start alice
# Still logged in!
```

### Multi-Server Setup

For very large teams, run multiple servers:

```bash
# Server 1: Ports 9222-9231
SERVER_NAME=browser1.company.com MAX_AGENTS=10 ./scripts/server-manager.sh init

# Server 2: Ports 9232-9241
SERVER_NAME=browser2.company.com BASE_PORT=9232 MAX_AGENTS=10 ./scripts/server-manager.sh init
```

## Example Workflows

### Daily Standup Check

```bash
# Admin checks all agent browsers
./scripts/admin-monitor.sh list

# Quick screenshot of each
for agent in dev1 dev2 dev3; do
    ./scripts/admin-monitor.sh screenshot $agent
    echo "Screenshot saved for $agent"
done
```

### Helping an Agent Debug

```bash
# Agent says: "Something weird is happening"

# Admin views their browser
./scripts/admin-monitor.sh view dev1

# Or takes a screenshot to see what's wrong
./scripts/admin-monitor.sh screenshot dev1

# Can even navigate for them to a working page
./scripts/admin-monitor.sh navigate dev1 https://working-site.com
```

### Onboarding New Agent

```bash
# 1. Admin creates browser
./scripts/server-manager.sh start newdev

# 2. Share connection info with newdev
# Port: 9225
# SSH: ssh -N -L 9225:localhost:9225 vm2.junod.dev

# 3. Newdev runs on their machine
AGENT_NAME=newdev ./scripts/agent-connect.sh

# 4. Newdev uses the browser!
agent-browser --cdp 9225 open https://example.com
```

## Migration from Single Browser

If you're currently using a single shared browser:

```bash
# 1. Stop the old shared browser
pkill -f 'chrome.*9222'

# 2. Initialize multi-agent system
./scripts/server-manager.sh init

# 3. Start individual browsers for each user
./scripts/server-manager.sh start alice
./scripts/server-manager.sh start bob
./scripts/server-manager.sh start charlie

# 4. Each person connects with their own tunnel
# Alice: AGENT_NAME=alice ./scripts/agent-connect.sh
# Bob: AGENT_NAME=bob ./scripts/agent-connect.sh
# etc.
```

## Credits

Built with:
- [Playwright](https://playwright.dev) - Browser automation
- [agent-browser](https://agent-browser.dev) - CLI tool for browser control
- Chrome DevTools Protocol (CDP) - Remote debugging interface
