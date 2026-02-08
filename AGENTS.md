# Agent Guide: Remote Browser Automation

This guide covers how to use the browser automation system from **two different setups**:
- **Server-side agents**: You're logged into the server (vm2.junod.dev) where browsers run
- **Client-side agents**: You're on your local machine connecting to browsers on the server

## Quick Reference

**Are you on the server or your local machine?**

```bash
# Check where you are
hostname

# If it shows "vm2.junod.dev" → You're on the SERVER (see Section A)
# If it shows something else → You're on your LOCAL MACHINE (see Section B)
```

---

## Section A: Server-Side Agents (You're on vm2.junod.dev)

Use this if you're SSH'd into the server and want to run automation there.

### Architecture
```
You (on server) → Chrome Browser (localhost:9222)
```

### Quick Start

```bash
# 1. Check if browser is running
curl -s http://localhost:9222/json/version

# 2. If not running, start one (or ask admin)
./scripts/server-manager.sh start myagent

# 3. Use agent-browser directly (no SSH needed!)
agent-browser --cdp 9222 open https://example.com
agent-browser --cdp 9222 snapshot
```

### Available Commands

```bash
# Navigate
agent-browser --cdp 9222 open https://example.com

# Get page structure
agent-browser --cdp 9222 snapshot

# Execute JavaScript
agent-browser --cdp 9222 eval "document.title"

# Take screenshot
agent-browser --cdp 9222 screenshot

# Click element (use ref from snapshot)
agent-browser --cdp 9222 click --ref=e1

# Type in input
agent-browser --cdp 9222 type --ref=input1 "search text"
```

### Finding Your Port

```bash
# List all browsers and their ports
./scripts/server-manager.sh list

# Check your assigned port
cat ~/.chrome-agents/pids/$(whoami)_port

# Use that port number with --cdp
agent-browser --cdp 9223 snapshot  # if your port is 9223
```

### Playwright (Server-Side)

```javascript
import { chromium } from 'playwright';

// Direct connection - no SSH needed!
const port = process.env.CDP_PORT || 9222;
const browser = await chromium.connectOverCDP(`http://localhost:${port}`);

const context = browser.contexts()[0];
const page = context.pages()[0] || await context.newPage();

await page.goto('https://example.com');
console.log(await page.title());

await browser.close();
```

---

## Section B: Client-Side Agents (You're on Your Local Machine)

Use this if you're on your laptop/desktop connecting to browsers on vm2.junod.dev.

### Architecture
```
Your Laptop → SSH Tunnel → Server → Chrome Browser
 (localhost:9222)         (vm2.junod.dev:9222)
```

### Quick Start

```bash
# 1. Connect to your assigned browser
# This creates the SSH tunnel automatically
AGENT_NAME=yourname ./scripts/agent-connect.sh

# 2. In another terminal, use the browser
agent-browser --cdp 9222 open https://example.com
agent-browser --cdp 9222 snapshot
```

### Setting Up SSH Tunnel

The `agent-connect.sh` script does this automatically, but if you need manual control:

```bash
# Create SSH tunnel (keep this terminal open!)
ssh -N -L 9222:localhost:9222 vm2.junod.dev

# For multiple browsers
ssh -N -L 9222:localhost:9222 -L 9223:localhost:9223 vm2.junod.dev
```

### Available Commands (Same as Server-Side)

Once the tunnel is active, commands are identical:

```bash
# Navigate
agent-browser --cdp 9222 open https://example.com

# Get page structure
agent-browser --cdp 9222 snapshot

# Execute JavaScript
agent-browser --cdp 9222 eval "document.title"

# Take screenshot
agent-browser --cdp 9222 screenshot

# Click element
agent-browser --cdp 9222 click --ref=e1

# Type in input
agent-browser --cdp 9222 type --ref=input1 "search text"
```

### Playwright (Client-Side)

```javascript
import { chromium } from 'playwright';

// Connect through SSH tunnel
const CDP_URL = 'http://localhost:9222';
const browser = await chromium.connectOverCDP(CDP_URL);

const context = browser.contexts()[0];
const page = context.pages()[0] || await context.newPage();

await page.goto('https://example.com');
console.log(await page.title());

await browser.close();
```

### Checking Connection

```bash
# Test if tunnel is working
curl -s http://localhost:9222/json/version

# Should return browser version info
# If it fails, your tunnel is not active
```

---

## Common Workflows

### Web Scraping

```bash
#!/bin/bash
# Works on both server and client (adjust port as needed)

PORT=9222

# Navigate
agent-browser --cdp $PORT open https://news.ycombinator.com

# Get structure
agent-browser --cdp $PORT snapshot

# Extract data
agent-browser --cdp $PORT eval "
  Array.from(document.querySelectorAll('.titleline a'))
    .slice(0, 5)
    .map(a => ({title: a.textContent, url: a.href}))
"

# Screenshot
agent-browser --cdp $PORT screenshot --output results.png
```

### Form Interaction

```bash
#!/bin/bash
PORT=9222

# Go to form
agent-browser --cdp $PORT open https://example.com/login

# Get element refs
agent-browser --cdp $PORT snapshot

# Fill form (update refs based on snapshot)
agent-browser --cdp $PORT type --ref=username "myuser"
agent-browser --cdp $PORT type --ref=password "mypassword"

# Submit
agent-browser --cdp $PORT click --ref=submit

# Wait and verify
sleep 3
agent-browser --cdp $PORT snapshot
```

### Multi-Step Automation

```bash
#!/bin/bash
PORT=9222

# Step 1: Search
agent-browser --cdp $PORT open https://google.com
agent-browser --cdp $PORT type --name=q "playwright automation"
agent-browser --cdp $PORT eval "document.querySelector('form').submit()"
sleep 2

# Step 2: Extract results
agent-browser --cdp $PORT eval "
  Array.from(document.querySelectorAll('h3'))
    .slice(0, 5)
    .map(h => h.textContent)
"

# Step 3: Screenshot
agent-browser --cdp $PORT screenshot
```

---

## Multi-Agent Setup

### Server-Side: Managing Multiple Browsers

On the server (vm2.junod.dev):

```bash
# Start browsers for different agents
./scripts/server-manager.sh start alice    # Port 9222
./scripts/server-manager.sh start bob      # Port 9223
./scripts/server-manager.sh start charlie  # Port 9224

# List all browsers
./scripts/server-manager.sh list

# Stop a browser
./scripts/server-manager.sh stop alice
```

### Client-Side: Connecting to Multi-Agent

On your local machine:

```bash
# Each agent connects to their assigned port
# Alice (assigned port 9222)
AGENT_NAME=alice ./scripts/agent-connect.sh

# Bob (assigned port 9223)
AGENT_NAME=bob ./scripts/agent-connect.sh

# Then use their respective ports
agent-browser --cdp 9222 snapshot  # Alice
agent-browser --cdp 9223 snapshot  # Bob
```

### Parallel Execution

```bash
# Server-side (multiple browsers on server)
agent-browser --cdp 9222 open https://site1.com &
agent-browser --cdp 9223 open https://site2.com &
agent-browser --cdp 9224 open https://site3.com &
wait

# Client-side (after setting up multiple tunnels)
# Terminal 1: ssh -N -L 9222:localhost:9222 vm2.junod.dev
# Terminal 2: ssh -N -L 9223:localhost:9223 vm2.junod.dev
agent-browser --cdp 9222 open https://site1.com &
agent-browser --cdp 9223 open https://site2.com &
wait
```

---

## Troubleshooting

### "Connection refused" Error

**Server-side:**
```bash
# Check if browser is running
curl http://localhost:9222/json/version

# If not, start it
./scripts/server-manager.sh start $(whoami)
```

**Client-side:**
```bash
# Check tunnel
curl http://localhost:9222/json/version

# If fails, recreate tunnel
ssh -N -L 9222:localhost:9222 vm2.junod.dev

# Or use the connect script
./scripts/agent-connect.sh
```

### agent-browser Not Found

```bash
# Install globally
npm install -g agent-browser
agent-browser install

# Or use npx
npx agent-browser --cdp 9222 snapshot
```

### Page Not Loading

```bash
# Check current URL
agent-browser --cdp 9222 eval "window.location.href"

# Check for JavaScript errors
agent-browser --cdp 9222 eval "
  Array.from(document.querySelectorAll('.error'))
    .map(e => e.textContent)
"

# Wait longer for dynamic content
sleep 5
agent-browser --cdp 9222 snapshot
```

### Stuck on Empty Tab

```bash
# List all tabs
agent-browser --cdp 9222 tab

# Navigate directly
agent-browser --cdp 9222 open https://example.com

# Or via JavaScript
agent-browser --cdp 9222 eval "window.location.href = 'https://example.com'"
```

### Port Already in Use

**Server-side:**
```bash
# Find what's using it
lsof -Pi :9222 -sTCP:LISTEN

# Stop and restart
./scripts/server-manager.sh stop $(whoami)
./scripts/server-manager.sh start $(whoami)
```

**Client-side:**
```bash
# Find the tunnel
lsof -Pi :9222 -sTCP:LISTEN

# Kill it
kill <pid>

# Recreate
./scripts/agent-connect.sh
```

---

## Tips for Agents

1. **Verify connection first:** Always run `curl http://localhost:9222/json/version` before starting

2. **Use snapshots for navigation:** The accessibility tree with refs makes it easy to identify elements

3. **Add delays:** Use `sleep 2` or `sleep 3` after navigation for dynamic content

4. **Take screenshots:** Verify state after important steps with screenshots

5. **Check console errors:** Use `eval` to execute debugging code

6. **Session persistence:** Browser state persists between commands - you can build up state

7. **Port isolation:** Each Chrome instance (port) is isolated - cookies don't leak between ports

8. **Server vs Client:** 
   - On server: Direct connection to localhost
   - On client: Must have SSH tunnel active

---

## Command Reference

```bash
agent-browser --cdp <port> <command>

Commands:
  open <url>           Navigate to URL
  snapshot             Get accessibility tree with element refs
  click                Click element (--ref, --name, or --text)
  type <text>          Type text into input (--ref, --name)
  eval <js>            Execute JavaScript
  screenshot           Capture screenshot
  tab                  List all tabs
  close                Close browser
  wait-for <selector>  Wait for element
  scroll               Scroll page (--x, --y)
  pdf                  Export page as PDF

Options:
  --cdp <port>         CDP port (default: 9222)
  --headed             Show browser window
  --debug              Show debug output
  --timeout <ms>       Set timeout (default: 30000)
```

---

## Security Notes

- Never expose port 9222 directly to the internet
- Always use SSH tunnel (client-side) or localhost only (server-side)
- CDP provides full browser control - treat it like root access
- Clear sensitive data when done:
  ```bash
  agent-browser --cdp 9222 eval "localStorage.clear(); sessionStorage.clear()"
  ```

## Getting Help

If something isn't working:

1. **Check where you are:** `hostname`
2. **Server-side:** Verify Chrome is running: `curl http://localhost:9222/json/version`
3. **Client-side:** Verify tunnel is active: `curl http://localhost:9222/json/version`
4. **Check server status:** SSH into server and run `./scripts/server-manager.sh list`
5. **Try debug mode:** `agent-browser --cdp 9222 --debug snapshot`
6. **Check main README.md** for detailed setup instructions
