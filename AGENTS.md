# Agent Guide: Remote Browser Automation

This document explains how to use the remote browser server for web automation tasks.

## What This Is

This repository provides a **remote Chrome browser** that you can control via SSH tunnel. Instead of launching a browser locally (which may not be possible or practical), you connect to a browser running on a remote server through an SSH tunnel.

**Architecture:**
```
Your Session → SSH Tunnel → Remote Server → Chrome Browser (CDP port 9222)
```

## Quick Start (For Agents)

### Step 1: Check if SSH tunnel is active

```bash
# Test if you can reach the remote browser
curl -s http://localhost:9222/json/version
```

If this returns JSON with browser version, the tunnel is ready. If not, see "Setting up the tunnel" below.

### Step 2: Use agent-browser

Once connected, you can use any `agent-browser` command:

```bash
# Navigate to a URL
agent-browser --cdp 9222 open https://example.com

# Take a snapshot (accessibility tree for AI)
agent-browser --cdp 9222 snapshot

# Execute JavaScript
agent-browser --cdp 9222 eval "document.title"

# List all tabs
agent-browser --cdp 9222 tab

# Take screenshot
agent-browser --cdp 9222 screenshot

# Click on element by reference
agent-browser --cdp 9222 click --ref=a1

# Fill form field
agent-browser --cdp 9222 type --ref=input1 "search query"
```

## Setting Up the SSH Tunnel

If the tunnel is not active, you need to create it:

```bash
# From your local machine (or ask the user to run this)
ssh -N -L 9222:localhost:9222 user@server-address

# For multiple browser instances
ssh -N -L 9222:localhost:9222 -L 9223:localhost:9223 user@server-address
```

**Keep this terminal open** - the tunnel runs continuously.

Alternative: Use the provided script:
```bash
./scripts/ssh-tunnel.sh user@server-address
```

## Common Agent Workflows

### Web Scraping

```bash
# 1. Navigate to target
agent-browser --cdp 9222 open https://news.ycombinator.com

# 2. Take snapshot to see page structure
agent-browser --cdp 9222 snapshot

# 3. Extract specific data with JavaScript
agent-browser --cdp 9222 eval "
  Array.from(document.querySelectorAll('.titleline a'))
    .slice(0, 5)
    .map(a => ({title: a.textContent, url: a.href}))
"

# 4. Take screenshot for verification
agent-browser --cdp 9222 screenshot --output page.png
```

### Form Interaction

```bash
# Navigate to form page
agent-browser --cdp 9222 open https://example.com/login

# Get snapshot to see element refs
agent-browser --cdp 9222 snapshot

# Fill form (use --ref from snapshot output)
agent-browser --cdp 9222 type --ref=username "myuser"
agent-browser --cdp 9222 type --ref=password "mypassword"

# Submit form
agent-browser --cdp 9222 click --ref=submit

# Wait for navigation and check result
sleep 2
agent-browser --cdp 9222 snapshot
```

### Multi-Step Automation

```bash
#!/bin/bash
# Example: Search and extract results

cdp_port=9222

# Navigate to search page
agent-browser --cdp $cdp_port open https://google.com

# Type search query
agent-browser --cdp $cdp_port type --name=q "playwright automation"

# Submit
agent-browser --cdp $cdp_port eval "document.querySelector('form').submit()"

# Wait for results
sleep 2

# Extract search results
agent-browser --cdp $cdp_port eval "
  Array.from(document.querySelectorAll('h3'))
    .slice(0, 5)
    .map(h => h.textContent)
"
```

## Using Playwright Directly

For more complex automation, use Playwright's `connectOverCDP`:

```javascript
import { chromium } from 'playwright';

// Connect to remote browser
const browser = await chromium.connectOverCDP('http://localhost:9222');
const page = await browser.newPage();

// Navigate and interact
await page.goto('https://example.com');
const title = await page.title();

// Take screenshot
await page.screenshot({ path: 'screenshot.png' });

// Extract data
const data = await page.evaluate(() => {
  return document.querySelector('h1')?.textContent;
});

await browser.close();
```

## Environment Variables

```bash
# Set default CDP port
export CDP_PORT=9222

# Then use without --cdp flag in some scripts
agent-browser snapshot  # uses CDP_PORT
```

## Multi-Agent Parallel Execution

For running multiple agents simultaneously:

```bash
# Server must have Chrome on multiple ports
# Agent 1
agent-browser --cdp 9222 open https://site1.com &

# Agent 2
agent-browser --cdp 9223 open https://site2.com &

# Agent 3
agent-browser --cdp 9224 open https://site3.com &

wait
```

## Troubleshooting

### "Connection refused" Error

```bash
# Check if tunnel is active
curl http://localhost:9222/json/version

# If fails, SSH tunnel may be down. Try reconnecting:
ssh -N -L 9222:localhost:9222 user@server-address

# Or check if Chrome is running on server
ssh user@server-address "curl -s http://localhost:9222/json/version"
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
agent-browser --cdp 9222 eval "Array.from(document.querySelectorAll('.error')).map(e => e.textContent)"

# Try waiting longer
sleep 5
agent-browser --cdp 9222 snapshot
```

### Stuck on Empty Tab

```bash
# List all tabs
agent-browser --cdp 9222 tab

# Switch to a specific tab
agent-browser --cdp 9222 eval "window.location.href = 'https://example.com'"

# Or close and reopen
agent-browser --cdp 9222 close
agent-browser --cdp 9222 open https://example.com
```

## Tips for Agents

1. **Always verify the connection first:** Run `curl http://localhost:9222/json/version` before starting

2. **Use snapshots for navigation:** The accessibility tree with refs makes it easy to identify clickable elements

3. **Add delays for dynamic content:** Use `sleep 2` or `sleep 3` after navigation or form submission

4. **Check JavaScript console for errors:** Use `agent-browser --cdp 9222 eval` to execute debugging code

5. **Screenshots are your friend:** Take screenshots after important steps to verify state

6. **Multiple tabs:** The browser persists between commands, so you can build up state

7. **Session isolation:** Each Chrome instance (port) is isolated - logins/cookies don't leak between ports

## Available Commands Reference

```bash
agent-browser --cdp 9222 <command>

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

## Security Notes

- Never expose port 9222 directly to the internet
- Always use SSH tunnel or VPN
- CDP provides full browser control - treat it like root access
- Clear sensitive data when done: `agent-browser --cdp 9222 eval "localStorage.clear(); sessionStorage.clear()"`

## Getting Help

If something isn't working:

1. Check SSH tunnel: `curl http://localhost:9222/json/version`
2. Check server status: SSH into server and verify Chrome is running
3. Try with `--debug` flag for verbose output
4. Check the main README.md for more detailed setup instructions
