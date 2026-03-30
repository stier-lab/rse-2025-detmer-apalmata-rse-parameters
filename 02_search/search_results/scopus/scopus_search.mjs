#!/usr/bin/env node
/**
 * Scopus search via Playwright CDP
 * Connects to authenticated Chrome session to access Scopus via UCSB institutional access
 *
 * Task 1: Run two queries and extract results
 * Query A: TITLE-ABS-KEY("Acropora palmata" OR "elkhorn coral")
 * Query B: TITLE-ABS-KEY("Acropora" AND "Caribbean") AND TITLE-ABS-KEY(survival OR mortality OR growth OR restoration OR monitoring)
 */

import { chromium } from 'playwright';
import { writeFileSync } from 'fs';

const CDP_URL = 'http://127.0.0.1:9222';
const BASE_DIR = '/Users/adrianstier/Detmer-2025-coral-parameters/02_search/search_results/scopus';

async function main() {
  console.log('Connecting to Chrome via CDP...');
  const browser = await chromium.connectOverCDP(CDP_URL);
  const context = browser.contexts()[0];

  // Open a new tab for Scopus
  const page = await context.newPage();

  console.log('\n=== TASK 1: Scopus Search ===\n');

  // Navigate to Scopus
  console.log('Navigating to Scopus...');
  try {
    await page.goto('https://www.scopus.com/search/form.uri?display=advanced', {
      waitUntil: 'domcontentloaded',
      timeout: 30000
    });
    await page.waitForTimeout(5000);

    const currentUrl = page.url();
    console.log('Current URL:', currentUrl);

    // Take a screenshot to understand the page layout
    await page.screenshot({ path: '/tmp/scopus_initial.png', fullPage: false });
    console.log('Screenshot saved to /tmp/scopus_initial.png');

    // Check if we're on Scopus or redirected (e.g., login page)
    const pageTitle = await page.title();
    console.log('Page title:', pageTitle);

    // Check for common access patterns
    const pageText = await page.evaluate(() => document.body?.innerText?.substring(0, 2000));
    console.log('Page text preview:', pageText?.substring(0, 500));

  } catch (e) {
    console.log('Navigation error:', e.message);
  }

  console.log('\nDone with initial navigation. Check /tmp/scopus_initial.png');
}

main().catch(console.error);
