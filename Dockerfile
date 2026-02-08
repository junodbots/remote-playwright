FROM node:20-slim

# Install Chrome dependencies and Chrome
RUN apt-get update && apt-get install -y \
    chromium \
    chromium-driver \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set Chrome path
ENV CHROME_BIN=/usr/bin/chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy scripts
COPY scripts/ ./scripts/
COPY *.js ./

# Make scripts executable
RUN chmod +x scripts/*.sh

# Expose Chrome DevTools Protocol port
EXPOSE 9222

# Start script that launches Chrome with CDP
CMD ["./scripts/start-browser-server.sh", "9222", "/data/chrome-profile"]
