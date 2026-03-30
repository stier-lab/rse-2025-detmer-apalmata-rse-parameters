#!/usr/bin/env node
/**
 * Task 2: Run broader WoS queries - v2
 * Navigate to Advanced Search, use the Query Builder textarea, and search
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
  console.log(`\n${'='.repeat(60)}`);
  console.log(`Running: ${queryObj.id}`);
  console.log(`Query: ${queryObj.query}`);
  console.log('='.repeat(60));

  // Navigate to advanced search
  await page.goto('https://www.webofscience.com/wos/woscc/advanced-search', {
    waitUntil: 'domcontentloaded',
    timeout: 30000
  });
  await page.waitForTimeout(5000);

  // Screenshot to see the current state
  await page.screenshot({ path: `/tmp/wos_${queryObj.id}_before.png`, fullPage: false });

  // Make sure we're on the QUERY BUILDER tab (not FIELDED SEARCH)
  try {
    const queryBuilderTab = page.locator('text=QUERY BUILDER, text=Query Builder').first();
    if (await queryBuilderTab.isVisible({ timeout: 3000 })) {
      await queryBuilderTab.click();
      await page.waitForTimeout(1000);
      console.log('Clicked QUERY BUILDER tab');
    }
  } catch (e) {
    console.log('Could not find QUERY BUILDER tab, may already be active');
  }

  // Find and fill the textarea
  const textarea = page.locator('#advancedSearchInputArea');
  if (await textarea.isVisible({ timeout: 5000 })) {
    // Clear and fill using JavaScript
    await page.evaluate((query) => {
      const ta = document.getElementById('advancedSearchInputArea');
      if (ta) {
        // Clear
        ta.value = '';
        ta.dispatchEvent(new Event('input', { bubbles: true }));
        ta.dispatchEvent(new Event('change', { bubbles: true }));

        // Set value
        ta.value = query;
        ta.dispatchEvent(new Event('input', { bubbles: true }));
        ta.dispatchEvent(new Event('change', { bubbles: true }));

        // Also try Angular's ngModel update
        const ngModel = ta.__ngContext__ || ta.getAttribute('ng-model');
        console.log('Angular context:', !!ta.__ngContext__);
      }
    }, queryObj.query);

    await page.waitForTimeout(500);

    // Also type into it to trigger Angular bindings
    await textarea.click();
    await page.keyboard.press('Control+A');
    await page.keyboard.press('Backspace');
    await page.waitForTimeout(300);
    await textarea.type(queryObj.query, { delay: 5 });
    await page.waitForTimeout(1000);

    // Verify content
    const value = await textarea.inputValue();
    console.log(`Textarea value: ${value.substring(0, 100)}...`);

    // Now find and click the correct Search button
    // The Advanced Search page has a Search button near the textarea
    // It might be a mat-button or button element
    console.log('Looking for Search button...');

    // List all buttons on the page
    const buttons = await page.evaluate(() => {
      const btns = document.querySelectorAll('button');
      const info = [];
      btns.forEach(b => {
        const text = b.textContent?.trim();
        const visible = b.offsetHeight > 0 && b.offsetWidth > 0;
        if (visible && text.length < 50) {
          info.push({
            text,
            class: b.className?.substring(0, 80),
            id: b.id,
            ariaLabel: b.getAttribute('aria-label'),
            dataTa: b.getAttribute('data-ta'),
          });
        }
      });
      return info;
    });
    console.log('Visible buttons:', JSON.stringify(buttons, null, 2));

    // Try to find the search button specifically
    // Common patterns: data-ta="run-search", class containing "search-button"
    const searchButton = page.locator('button[data-ta="run-search"], button.search-button, button:has(span:text("Search"))').first();
    let searchClicked = false;

    try {
      if (await searchButton.isVisible({ timeout: 2000 })) {
        console.log('Found search button via data-ta/class selector');
        await searchButton.click();
        searchClicked = true;
      }
    } catch (e) {
      console.log('Could not find search button via data-ta/class');
    }

    if (!searchClicked) {
      // Try finding the button by its icon or the search icon (magnifying glass)
      const searchBtns = page.locator('button').filter({ hasText: 'Search' });
      const count = await searchBtns.count();
      console.log(`Found ${count} buttons with "Search" text`);

      // The correct button should be near the textarea, not in the nav
      for (let i = 0; i < count; i++) {
        const btn = searchBtns.nth(i);
        const text = await btn.textContent();
        const bbox = await btn.boundingBox();
        console.log(`  Button ${i}: "${text.trim()}" at y=${bbox?.y}`);

        // The search button for the query is likely in the main content area (y > 200)
        if (bbox && bbox.y > 200 && text.trim().includes('Search')) {
          console.log(`  -> Clicking this button`);
          await btn.click();
          searchClicked = true;
          break;
        }
      }
    }

    if (!searchClicked) {
      console.log('Could not find the right search button. Trying keyboard Enter...');
      await textarea.click();
      await page.keyboard.press('Enter');
    }

    // Wait for results page to load
    console.log('Waiting for results...');
    await page.waitForTimeout(8000);

    const resultUrl = page.url();
    console.log('Result URL:', resultUrl);

    // Screenshot the results
    await page.screenshot({ path: `/tmp/wos_${queryObj.id}_results.png`, fullPage: false });
    console.log(`Screenshot saved: /tmp/wos_${queryObj.id}_results.png`);

    // Extract hit count
    const hitInfo = await page.evaluate(() => {
      const bodyText = document.body?.innerText || '';

      // Try various patterns
      const patterns = [
        /(\d{1,6})\s+results?/i,
        /Results?:?\s*(\d{1,6})/i,
        /of\s+(\d{1,6})\b/i,
        /(\d{1,6})\s+record/i,
        /Showing\s+\d+-\d+\s+of\s+(\d{1,6})/i,
        /(\d[\d,]*)\s+result/i,
      ];

      for (const p of patterns) {
        const match = bodyText.match(p);
        if (match) {
          const num = parseInt(match[1].replace(/,/g, ''));
          if (num > 0 && num < 100000) return { count: num, pattern: p.toString() };
        }
      }

      // Check for the specific WoS result count element
      const countEl = document.querySelector('[data-ta="search-count"]');
      if (countEl) {
        return { count: parseInt(countEl.textContent?.replace(/,/g, '')), source: 'data-ta' };
      }

      // Check history table for results
      const historyRows = document.querySelectorAll('table tr, app-search-history-row');
      const historyInfo = [];
      historyRows.forEach(row => {
        const text = row.innerText?.trim();
        if (text && text.length > 10) {
          historyInfo.push(text.substring(0, 200));
        }
      });

      return {
        count: null,
        bodySnippet: bodyText.substring(0, 800),
        historyRows: historyInfo.slice(0, 5),
      };
    });

    console.log('Hit info:', JSON.stringify(hitInfo, null, 2));
    return hitInfo;
  } else {
    console.log('ERROR: Textarea not visible');
    return { count: null, error: 'textarea not visible' };
  }
}

async function main() {
  console.log('Connecting to Chrome via CDP...');
  const browser = await chromium.connectOverCDP(CDP_URL);
  const context = browser.contexts()[0];
  const pages = context.pages();

  // Find the WoS tab
  let page = null;
  for (const p of pages) {
    if (p.url().includes('webofscience.com')) {
      page = p;
      break;
    }
  }
  if (!page) {
    page = await context.newPage();
  }

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
  console.log('\n\n' + '='.repeat(60));
  console.log('WoS BROADER QUERY RESULTS SUMMARY');
  console.log('='.repeat(60));
  for (const q of QUERIES) {
    const r = results[q.id];
    console.log(`\n${q.description}`);
    console.log(`  Query: ${q.query}`);
    console.log(`  Hits: ${r?.count ?? 'unknown'}`);
  }

  console.log('\nDone.');
}

main().catch(console.error);
