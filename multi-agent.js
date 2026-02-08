#!/usr/bin/env node
/**
 * Multi-Agent Example - Parallel Browser Automation
 * 
 * Shows how to run multiple agents concurrently with different browser ports.
 */

import { chromium } from 'playwright';

const AGENTS = [
  { name: 'Agent-1', port: 9222, url: 'https://example.com' },
  { name: 'Agent-2', port: 9223, url: 'https://httpbin.org' },
  { name: 'Agent-3', port: 9224, url: 'https://news.ycombinator.com' }
];

async function runAgent(agent) {
  const cdpUrl = `http://localhost:${agent.port}`;
  console.log(`[${agent.name}] Starting...`);
  
  try {
    const browser = await chromium.connectOverCDP(cdpUrl);
    const context = browser.contexts()[0] || await browser.newContext();
    const page = context.pages()[0] || await context.newPage();
    
    await page.goto(agent.url);
    const title = await page.title();
    const screenshot = await page.screenshot({ type: 'jpeg', quality: 80 });
    
    console.log(`[${agent.name}] ✓ Completed: ${title}`);
    
    await browser.close();
    return { agent: agent.name, title, screenshotSize: screenshot.length };
    
  } catch (error) {
    console.error(`[${agent.name}] ✗ Error: ${error.message}`);
    throw error;
  }
}

async function main() {
  console.log('Multi-Agent Parallel Execution');
  console.log('==============================\n');
  
  console.log('Make sure you have:');
  console.log('1. Chrome running on ports 9222, 9223, 9224 on remote server');
  console.log('2. SSH tunnels for all ports:');
  console.log('   ssh -N -L 9222:localhost:9222 -L 9223:localhost:9223 -L 9224:localhost:9224 server\n');
  
  const startTime = Date.now();
  
  // Run all agents in parallel
  const results = await Promise.allSettled(
    AGENTS.map(agent => runAgent(agent))
  );
  
  const duration = Date.now() - startTime;
  
  console.log('\n==============================');
  console.log('Results:');
  results.forEach((result, i) => {
    if (result.status === 'fulfilled') {
      console.log(`✓ ${AGENTS[i].name}: ${result.value.title}`);
    } else {
      console.log(`✗ ${AGENTS[i].name}: Failed`);
    }
  });
  
  console.log(`\nTotal time: ${duration}ms`);
  console.log('Parallel speedup: ~3x vs sequential');
}

main().catch(console.error);
