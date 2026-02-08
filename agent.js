#!/usr/bin/env node
/**
 * Example Agent Script - Remote Browser Automation
 * 
 * This shows how to use Playwright directly to connect to a remote browser
 * via SSH tunnel and perform automation tasks.
 */

import { chromium } from 'playwright';

const CDP_URL = process.env.CDP_URL || 'http://localhost:9222';

async function main() {
  console.log('Connecting to remote browser at:', CDP_URL);
  
  try {
    // Connect to the remote browser via CDP
    const browser = await chromium.connectOverCDP(CDP_URL);
    console.log('✓ Connected successfully');
    console.log('Browser version:', await browser.version());
    
    // Get the default context or create a new one
    let context = browser.contexts()[0];
    if (!context) {
      context = await browser.newContext();
      console.log('✓ Created new browser context');
    }
    
    // Get existing page or create new one
    let page = context.pages()[0];
    if (!page) {
      page = await context.newPage();
      console.log('✓ Created new page');
    }
    
    // Example: Navigate to a page
    console.log('\nNavigating to example.com...');
    await page.goto('https://example.com');
    console.log('✓ Page loaded');
    
    // Example: Extract information
    const title = await page.title();
    const heading = await page.locator('h1').textContent();
    console.log('\nPage Info:');
    console.log('  Title:', title);
    console.log('  Heading:', heading);
    
    // Example: Take screenshot
    await page.screenshot({ path: 'example.png' });
    console.log('✓ Screenshot saved to example.png');
    
    // Example: Evaluate JavaScript
    const stats = await page.evaluate(() => {
      return {
        url: window.location.href,
        links: document.querySelectorAll('a').length,
        images: document.querySelectorAll('img').length
      };
    });
    console.log('\nPage Stats:', stats);
    
    // Keep browser open for inspection (optional)
    // await new Promise(resolve => setTimeout(resolve, 5000));
    
    console.log('\n✓ Done! Closing connection...');
    await browser.close();
    
  } catch (error) {
    console.error('✗ Error:', error.message);
    console.error('\nTroubleshooting:');
    console.error('1. Is the SSH tunnel running? (npm run tunnel)');
    console.error('2. Is Chrome running on the remote server? (npm run start:server)');
    console.error('3. Check connection: curl http://localhost:9222/json/version');
    process.exit(1);
  }
}

main();
