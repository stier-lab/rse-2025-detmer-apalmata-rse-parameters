#!/usr/bin/env node
/**
 * Task 2: Run broader WoS queries via Advanced Search
 *
 * Query A: TS=("Acropora" AND "Caribbean") AND TS=(survival OR mortality OR growth OR recruitment OR restoration)
 * Query B: TS=("threatened coral" OR "endangered coral" OR "ESA" OR "critically endangered") AND TS=("Caribbean" AND (survival OR mortality))
 */

import { chromium } from 'playwright';
import { writeFileSync } from 'fs';

const CDP_URL = 'http://127.0.0.1:9222';
const BASE_DIR = '/Users/adrianstier/Detmer-2025-coral-parameters/02_search/search_results/wos';

const QUERIES = [
  {
    id: 'broader_acropora_caribbean',
    query: 'TS=("Acropora" AND "Caribbean") AND TS=(survival OR mortality OR growth OR recruitment OR restoration)',
    description: 'Broader Acropora + Caribbean demographic terms'
  },
  {
    id: 'threatened_coral_caribbean',
    query: 'TS=("threatened coral" OR "endangered coral" OR "ESA" OR "critically endangered") AND TS=("Caribbean" AND (survival OR mortality))',
    description: 'Threatened/endangered coral + Caribbean survival/mortality'
  }
];

async function runQuery(page, queryObj) {
  console.log(`\n=== Running query: ${queryObj.id} ===`);
  console.log(`Query: ${queryObj.query}`);

  // Navigate to advanced search fresh each time
  await page.goto('https://www.webofscience.com/wos/woscc/advanced-search', {
    waitUntil: 'domcontentloaded',
    timeout: 30000
  });
  await page.waitForTimeout(4000);

  // Clear any existing query and enter our query
  const textarea = page.locator('#advancedSearchInputArea');
  await textarea.click();
  await page.waitForTimeout(500);

  // Clear the textarea
  await page.evaluate(() => {
    const ta = document.getElementById('advancedSearchInputArea');
    if (ta) {
      ta.value = '';
      ta.dispatchEvent(new Event('input', { bubbles: true }));
    }
  });
  await page.waitForTimeout(500);

  // Type the query
  await textarea.fill(queryObj.query);
  await page.waitForTimeout(1000);

  // Verify the query was entered
  const enteredQuery = await page.evaluate(() => {
    const ta = document.getElementById('advancedSearchInputArea');
    return ta?.value;
  });
  console.log(`Entered query: ${enteredQuery}`);

  // Click the Search button
  console.log('Clicking Search...');
  const searchBtn = page.locator('button:has-text("Search")').first();
  await searchBtn.click();
  await page.waitForTimeout(8000);

  // Check if we got results
  const resultUrl = page.url();
  console.log('Result URL:', resultUrl);

  // Take a screenshot
  await page.screenshot({ path: `/tmp/wos_${queryObj.id}.png`, fullPage: false });
  console.log(`Screenshot saved to /tmp/wos_${queryObj.id}.png`);

  // Extract hit count
  const hitInfo = await page.evaluate(() => {
    // WoS shows result count in various places
    const bodyText = document.body?.innerText || '';

    // Look for patterns like "207 results" or "Results: 207" or "1-50 of 207"
    const patterns = [
      /(\d{1,6})\s+results?/i,
      /Results?:?\s*(\d{1,6})/i,
      /of\s+(\d{1,6})/i,
      /(\d{1,6})\s+record/i,
      /Showing\s+\d+-\d+\s+of\s+(\d{1,6})/i,
    ];

    for (const p of patterns) {
      const match = bodyText.match(p);
      if (match) {
        const num = parseInt(match[1]);
        if (num > 0 && num < 100000) return { count: num, source: p.toString() };
      }
    }

    // Also try to find the result count in a specific element
    const countElements = document.querySelectorAll('.brand-blue, .results-count, [data-ta="search-count"], span.value');
    const counts = [];
    countElements.forEach(el => {
      const text = el.textContent?.trim();
      if (text && /^\d+$/.test(text.replace(/,/g, ''))) {
        counts.push({ text, class: el.className?.substring(0, 50) });
      }
    });

    // Check for "No results found" or similar
    if (bodyText.includes('No results') || bodyText.includes('0 results') || bodyText.includes('no documents')) {
      return { count: 0, source: 'no results text' };
    }

    return { count: null, source: 'not found', counts, bodySnippet: bodyText.substring(0, 500) };
  });

  console.log('Hit info:', JSON.stringify(hitInfo, null, 2));

  return hitInfo;
}

async function main() {
  console.log('Connecting to Chrome via CDP...');
  const browser = await chromium.connectOverCDP(CDP_URL);
  const context = browser.contexts()[0];
  const pages = context.pages();

  // Find WoS tab
  let page = null;
  for (const p of pages) {
    if (p.url().includes('webofscience.com')) {
      page = p;
      break;
    }
  }
  if (!page) {
    // Use the last opened page or create a new one
    page = pages[pages.length - 1];
    if (!page || page.url() === 'about:blank') {
      page = await context.newPage();
    }
  }

  console.log('Using page:', page.url());

  const results = {};

  for (const q of QUERIES) {
    try {
      results[q.id] = await runQuery(page, q);
    } catch (e) {
      console.log(`Error running query ${q.id}:`, e.message);
      results[q.id] = { count: null, error: e.message };
    }
  }

  // Summary
  console.log('\n\n=== WoS BROADER QUERY RESULTS ===');
  for (const q of QUERIES) {
    const r = results[q.id];
    console.log(`\n${q.description}`);
    console.log(`  Query: ${q.query}`);
    console.log(`  Hits: ${r?.count ?? 'unknown'}`);
  }

  console.log('\nDone.');
}

main().catch(console.error);
