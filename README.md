# Remote Playwright Browser via SSH

Remote browser automation setup using Playwright's Chrome DevTools Protocol (CDP) over SSH tunnel. Perfect for running AI agents (like Vercel's `agent-browser`) on a remote machine while keeping your local machine lightweight.

## Architecture

```
┌─────────────────┐      SSH Tunnel      ┌──────────────────┐
│   Your Machine  │ ◄──────────────────► │  Remote Server   │
│  (agent-browser)│   Port 9222          │ (Chrome + CDP)   │
└─────────────────┘                      └──────────────────┘
```

## Quick Start

### 1. Install Dependencies (on both machines)

```bash
# Install agent-browser globally
npm install -g agent-browser

# Install browser binaries
agent-browser install

# On Linux, you may need dependencies
agent-browser install --with-deps
```

### 2. Start Browser on Remote Server

On your remote server (the one with more resources):

```bash
# Option A: Use the provided script
npm run start:server

# Option B: Start Chrome directly
chromium --remote-debugging-port=9222 --headless=new --no-sandbox

# Option C: Persistent profile (saves cookies, logins)
chromium --remote-debugging-port=9222 --user-data-dir=~/.chrome-remote-profile
```

Verify it's working:
```bash
curl http://localhost:9222/json/version
```

### 3. Create SSH Tunnel

On your local machine (where agents run):

```bash
# Option A: Use the helper script
npm run tunnel your-server.com

# Option B: Manual SSH tunnel
ssh -N -L 9222:localhost:9222 your-server.com

# Keep this terminal open! The tunnel runs continuously.
```

### 4. Run Agent Commands

Now you can use `agent-browser` with the remote browser:

```bash
# Take a snapshot (accessibility tree)
agent-browser --cdp 9222 snapshot

# Open a URL
agent-browser --cdp 9222 open https://example.com

# Evaluate JavaScript
agent-browser --cdp 9222 eval "document.title"

# List tabs
agent-browser --cdp 9222 tab

# Use the helper script
npm run agent snapshot
npm run agent open https://example.com
```

## Advanced Usage

### Multiple Browser Instances

For parallel agents, run multiple Chrome instances on different ports:

```bash
# On server - Instance 1
chromium --remote-debugging-port=9222 --user-data-dir=~/.chrome-profile-1

# On server - Instance 2  
chromium --remote-debugging-port=9223 --user-data-dir=~/.chrome-profile-2

# On local - Tunnel both
ssh -N -L 9222:localhost:9222 -L 9223:localhost:9223 your-server.com

# Use different agents with different ports
agent-browser --cdp 9222 snapshot
agent-browser --cdp 9223 snapshot
```

### Programmatic Usage (Node.js)

```javascript
import { chromium } from 'playwright';

// Connect to remote browser via CDP
const browser = await chromium.connectOverCDP('http://localhost:9222');
const page = await browser.newPage();

// Do agent work
await page.goto('https://example.com');
const title = await page.title();
console.log(title);

// Cleanup
await browser.close();
```

### Environment Variables

```bash
# Set default CDP port
export CDP_PORT=9222

# Use with agent-browser
agent-browser --cdp $CDP_PORT snapshot
```

### Cloud/Serverless Deployment

For production use, consider these alternatives to self-managed SSH:

1. **Browserbase** - Managed browser infrastructure
   ```bash
   export BROWSERBASE_API_KEY="..."
   export BROWSERBASE_PROJECT_ID="..."
   agent-browser -p browserbase open https://example.com
   ```

2. **Browser Use** - Another cloud provider
   ```bash
   export BROWSER_USE_API_KEY="..."
   agent-browser -p browseruse open https://example.com
   ```

## Troubleshooting

### Connection Refused

```bash
# Check if Chrome is listening on remote
ssh your-server.com "curl -s http://localhost:9222/json/version"

# If not, Chrome may not have started properly. Check:
# 1. Chrome is installed
# 2. Port 9222 is not already in use
# 3. No firewall blocking localhost:9222
```

### Tunnel Disconnects

Add these SSH options for stability:
```bash
ssh -N -L 9222:localhost:9222 \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -o ExitOnForwardFailure=yes \
    your-server.com
```

### Permission Denied (Linux)

If running on Linux without display:
```bash
# Use headless mode
chromium --remote-debugging-port=9222 --headless=new

# Or use Xvfb for virtual display
xvfb-run chromium --remote-debugging-port=9222
```

### Agent-Browser Not Found

```bash
# Ensure global npm bin is in PATH
export PATH="$PATH:$(npm bin -g)"

# Or use npx
npx agent-browser --cdp 9222 snapshot
```

## Security Considerations

- **Never expose port 9222 to the internet directly** - Always use SSH tunnel or VPN
- CDP provides full browser control - treat it like root access
- Use firewall rules to block external access to port 9222
- Consider using SSH key authentication only (no passwords)
- For production, use dedicated browser services with authentication

## Example Workflows

### Web Scraping Agent

```bash
#!/bin/bash
# scrape.sh

# 1. Start tunnel (in another terminal)
# ssh -N -L 9222:localhost:9222 server.com

# 2. Navigate and extract
agent-browser --cdp 9222 open https://news.ycombinator.com
agent-browser --cdp 9222 snapshot > page.html
agent-browser --cdp 9222 eval "Array.from(document.querySelectorAll('.titleline a')).map(a => a.textContent).slice(0,5)"
```

### CI/CD Integration

```yaml
# .github/workflows/test.yml
- name: Start Remote Browser
  run: |
    ssh server "chromium --remote-debugging-port=9222 --headless=new &"
    ssh -N -L 9222:localhost:9222 server &
    sleep 5

- name: Run Tests
  run: |
    agent-browser --cdp 9222 open http://localhost:3000
    agent-browser --cdp 9222 snapshot
```

## Resources

- [agent-browser docs](https://agent-browser.dev)
- [Playwright CDP docs](https://playwright.dev/docs/api/class-browsertype#browser-type-connect-over-cdp)
- [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/)
