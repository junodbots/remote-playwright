# Multi-Agent Browser Setup - Quick Start

Get multiple agents sharing browser infrastructure in 5 minutes.

## Overview

```
┌─────────────────┐         ┌──────────────────┐
│   Your Agents   │◄───────►│  Shared Server   │
│  (Local Machines│  SSH     │ (vm2.junod.dev)  │
│   Port 9222)    │ Tunnels  │  Chrome Instances│
└─────────────────┘         └──────────────────┘
         │                           │
         └──────────► Admin can view ◄──────────┘
                      any browser
```

## 1. Server Setup (Admin)

On `vm2.junod.dev`:

```bash
cd remote-playwright
./scripts/server-manager.sh init
```

## 2. Create Browser for Agent

```bash
# Create browser for "alice"
./scripts/server-manager.sh start alice

# Output:
# ==================================
# Agent: alice
# Port: 9222
# ...
# SSH Command: ssh -N -L 9222:localhost:9222 vm2.junod.dev
# ==================================
```

## 3. Agent Connects

On Alice's machine:

```bash
cd remote-playwright
AGENT_NAME=alice ./scripts/agent-connect.sh

# Or:
export AGENT_NAME=alice
./scripts/agent-connect.sh
```

This creates an SSH tunnel and keeps it open. Alice can now use the browser!

## 4. Agent Uses Browser

```bash
# Take snapshot
agent-browser --cdp 9222 snapshot

# Open a page
agent-browser --cdp 9222 open https://platform.openai.com

# Or use Playwright
node -e "
  const { chromium } = require('playwright');
  (async () => {
    const browser = await chromium.connectOverCDP('http://localhost:9222');
    const page = browser.contexts()[0].pages()[0];
    await page.goto('https://example.com');
    console.log(await page.title());
    await browser.close();
  })();
"
```

## 5. Admin Monitors (Optional)

Back on the server:

```bash
# See all agents
./scripts/admin-monitor.sh list

# Take screenshot of alice's browser
./scripts/admin-monitor.sh screenshot alice

# View live (VNC)
./scripts/admin-monitor.sh view alice

# Execute JavaScript
./scripts/admin-monitor.sh exec alice "document.title"

# Navigate for them
./scripts/admin-monitor.sh navigate alice https://google.com

# Interactive menu
./scripts/admin-monitor.sh interactive
```

## Common Commands

### Admin (Server)

```bash
# Start browser for agent
./scripts/server-manager.sh start <agent-name>

# Stop browser
./scripts/server-manager.sh stop <agent-name>

# Stop all browsers
./scripts/server-manager.sh stop all

# List all browsers
./scripts/server-manager.sh list

# Check status
./scripts/server-manager.sh status
```

### Agent (Local)

```bash
# Connect to assigned browser
./scripts/agent-connect.sh

# Check connection status
./scripts/agent-connect.sh check

# The script will output the port to use
# Then use: agent-browser --cdp <port> <command>
```

## Use Case: Secure Login

Alice needs to log into a service without sharing credentials:

```bash
# 1. Admin starts browser
./scripts/server-manager.sh start alice

# 2. Alice connects
AGENT_NAME=alice ./scripts/agent-connect.sh

# 3. Admin opens login page
./scripts/admin-monitor.sh navigate alice https://auth.service.com/login

# 4. Alice views via VNC and logs in
vncviewer vm2.junod.dev:5900
# (Types credentials - admin cannot see them)

# 5. Alice uses authenticated browser for automation
agent-browser --cdp 9222 open https://service.com/dashboard
```

## Environment Variables

### Server

```bash
SERVER_NAME=vm2.junod.dev    # Server hostname
BASE_PORT=9222               # Starting port
MAX_AGENTS=10                # Max concurrent browsers
DATA_DIR=~/.chrome-agents    # Where profiles are stored
```

### Agent

```bash
SERVER_NAME=vm2.junod.dev    # Server to connect to
AGENT_NAME=$(whoami)         # Your agent identifier
```

## Troubleshooting

**Agent can't connect:**
```bash
# Check if browser is running on server
ssh vm2.junod.dev "curl -s http://localhost:9222/json/version"

# Check tunnel
lsof -Pi :9222 -sTCP:LISTEN

# Restart tunnel
kill <tunnel-pid>
AGENT_NAME=alice ./scripts/agent-connect.sh
```

**Port already in use:**
```bash
# On server - stop and restart
./scripts/server-manager.sh stop alice
./scripts/server-manager.sh start alice  # Gets next available port
```

**Admin can't view:**
```bash
# Make sure you're on the server, not local
hostname  # Should show vm2.junod.dev

# Check browser is running
./scripts/admin-monitor.sh list
```

## Next Steps

- Read full documentation: [README.md](README.md)
- Check out example scripts in `agent.js`
- Configure SSH keys for easier connections
- Set up VNC passwords for security
