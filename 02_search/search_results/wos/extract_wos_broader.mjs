#!/usr/bin/env node
/**
 * Extract results from the two broader WoS queries
 * The searches have already been run, so we need to navigate to the results pages
 */

import { chromium } from 'playwright';
import { writeFileSync } from 'fs';

const CDP_URL = 'http://127.0.0.1:9222';
const BASE_DIR = '/Users/adrianstier/Detmer-2025-coral-parameters/02_search/search_results/wos';

async function extractResultsFromCurrentPage(page) {
  // Scroll slowly to trigger virtual rendering
  await page.evaluate(async () => {
    const delay = ms => new Promise(r => setTimeout(r, ms));
    const totalHeight = document.documentElement.scrollHeight;
    for (let pos = 0; pos < totalHeight; pos += 400) {
      window.scrollTo(0, pos);
      await delay(200);
    }
    await delay(1000);
    // Scroll back up
    for (let pos = totalHeight; pos >= 0; pos -= 400) {
      window.scrollTo(0, pos);
      await delay(100);
    }
    await delay(500);
  });

  // Extract records
  const records = await page.evaluate(() => {
    const results = [];
    const appRecords = document.querySelectorAll('app-record');

    appRecords.forEach(rec => {
      if (!rec.children || rec.children.length === 0) return;
      const text = rec.innerText?.trim();
      if (!text || text.length < 20) return;

      const titleLink = rec.querySelector('a[data-ta="summary-record-title-link"]');
      const title = titleLink?.textContent?.trim() || '';
      if (!title) return;

      const href = titleLink?.href || '';
      const wosIdMatch = href.match(/WOS:[A-Z0-9]+/);
      const wosId = wosIdMatch ? wosIdMatch[0] : '';

      const authorLinks = rec.querySelectorAll('a[href*="/wos/author/record/"]');
      const authorNames = [];
      authorLinks.forEach(a => {
        const name = a.textContent?.trim();
        if (name) authorNames.push(name);
      });
      const authors = authorNames.join('; ');

      const lines = text.split('\n').map(l => l.trim()).filter(l => l);
      let journal = '';
      let year = '';

      for (const line of lines) {
        // Journal appears with a down arrow
        if (line.includes('arrow_drop_down')) {
          journal = line.replace('arrow_drop_down', '').trim();
        }
        // Date patterns
        const datePatterns = [
          /^(?:[A-Z][a-z]{2,8}\s+(?:\d{1,2}\s+)?)?((?:19|20)\d{2})$/,
          /^((?:19|20)\d{2})$/,
        ];
        for (const dp of datePatterns) {
          if (!year) {
            const ym = line.match(dp);
            if (ym) year = ym[1];
          }
        }
        // Broader year extraction
        if (!year && line.length < 40 && !line.includes('http')) {
          const ym = line.match(/\b((?:19|20)\d{2})\b/);
          if (ym) year = ym[1];
        }
      }

      // Try DOI
      let doi = '';
      const doiLink = rec.querySelector('a[href*="doi.org"]');
      if (doiLink) {
        const doiMatch = doiLink.href?.match(/doi\.org\/(.+)/);
        if (doiMatch) doi = decodeURIComponent(doiMatch[1]);
      }

      // Try to get journal from the source element
      if (!journal) {
        const sourceLink = rec.querySelector('a[href*="/wos/alldb/general-summary/"]');
        if (sourceLink) journal = sourceLink.textContent?.trim() || '';
      }

      results.push({ title, authors, year, journal, doi, wosId });
    });

    return results;
  });

  return records;
}

async function extractAllPages(page, queryId, maxPages = 10) {
  const allResults = [];

  // Get total results and pages from current page
  const totalInfo = await page.evaluate(() => {
    const bodyText = document.body?.innerText || '';
    // Look for "1 of 9" type pagination
    const pageMatch = bodyText.match(/of\s+(\d+)\s*$/m) || bodyText.match(/(\d+)\s+results/i);
    const totalMatch = bodyText.match(/(\d[\d,]*)\s+results?\s+from/i);
    return {
      totalResults: totalMatch ? parseInt(totalMatch[1].replace(/,/g, '')) : null,
      pagination: bodyText.match(/(\d+)\s+of\s+(\d+)/)?.[0]
    };
  });
  console.log(`Total results info:`, totalInfo);

  const totalPages = Math.min(maxPages, Math.ceil((totalInfo.totalResults || 0) / 50));
  console.log(`Will extract up to ${totalPages} pages (50 results each)`);

  // Get the base URL from the current page
  const baseUrl = page.url();
  console.log(`Base URL: ${baseUrl}`);

  for (let pageNum = 1; pageNum <= totalPages; pageNum++) {
    console.log(`\n  Page ${pageNum}/${totalPages}...`);

    if (pageNum > 1) {
      // Navigate to the next page by modifying the URL
      const nextUrl = baseUrl.replace(/\/relevance\/\d+$/, `/relevance/${pageNum}`);
      await page.goto(nextUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
      await page.waitForTimeout(4000);
    }

    const pageResults = await extractResultsFromCurrentPage(page);
    console.log(`  Extracted ${pageResults.length} results from page ${pageNum}`);
    allResults.push(...pageResults);
  }

  // Deduplicate
  const seen = new Set();
  const unique = [];
  for (const r of allResults) {
    const key = r.title.toLowerCase().substring(0, 60);
    if (!seen.has(key)) {
      seen.add(key);
      unique.push(r);
    }
  }

  console.log(`\nTotal: ${allResults.length} raw, ${unique.length} unique`);
  return unique;
}

function saveCSV(records, outputFile) {
  const escape = (s) => `"${(s || '').replace(/"/g, '""')}"`;
  const header = 'title,authors,year,journal,doi,wos_id';
  const rows = records.map(r =>
    [escape(r.title), escape(r.authors), escape(r.year), escape(r.journal),
     escape(r.doi), escape(r.wosId)].join(',')
  );
  const csv = [header, ...rows].join('\n');
  writeFileSync(outputFile, csv, 'utf-8');
  console.log(`Saved ${records.length} records to ${outputFile}`);
}

async function main() {
  console.log('Connecting to Chrome via CDP...');
  const browser = await chromium.connectOverCDP(CDP_URL);
  const context = browser.contexts()[0];
  const pages = context.pages();

  // Find the WoS results page
  let page = null;
  for (const p of pages) {
    const url = p.url();
    if (url.includes('webofscience.com') && url.includes('summary')) {
      page = p;
      break;
    }
  }
  if (!page) {
    for (const p of pages) {
      if (p.url().includes('webofscience.com')) {
        page = p;
        break;
      }
    }
  }
  if (!page) {
    console.log('No WoS page found');
    return;
  }

  console.log(`Using page: ${page.url()}`);

  // First, run query A (broader Acropora Caribbean) and extract
  console.log('\n=== QUERY A: Broader Acropora + Caribbean ===');

  // Navigate to Advanced Search and run query A
  await page.goto('https://www.webofscience.com/wos/woscc/advanced-search', {
    waitUntil: 'domcontentloaded',
    timeout: 30000
  });
  await page.waitForTimeout(4000);

  // Enter and run query
  const textarea = page.locator('#advancedSearchInputArea');
  await textarea.click();
  await page.keyboard.press('Meta+A');
  await page.keyboard.press('Backspace');
  await textarea.type('TS=("Acropora" AND "Caribbean") AND TS=(survival OR mortality OR growth OR recruitment OR restoration)', { delay: 5 });
  await page.waitForTimeout(500);

  const searchBtn = page.locator('button[data-ta="run-search"]');
  await searchBtn.click({ force: true });
  await page.waitForTimeout(8000);

  console.log('Query A results URL:', page.url());

  // Check hit count
  const hitCountA = await page.evaluate(() => {
    const bodyText = document.body?.innerText || '';
    const match = bodyText.match(/(\d[\d,]*)\s+results?\s+from/i);
    return match ? parseInt(match[1].replace(/,/g, '')) : null;
  });
  console.log(`Query A hits: ${hitCountA}`);

  if (hitCountA > 0) {
    // Extract first 5 pages (250 results) from query A
    const resultsA = await extractAllPages(page, 'broader_acropora_caribbean', 9);
    saveCSV(resultsA, `${BASE_DIR}/wos_broader_acropora_caribbean.csv`);

    // Print sample
    console.log('\nFirst 5 results:');
    resultsA.slice(0, 5).forEach((r, i) => {
      console.log(`  ${i+1}. ${r.authors?.substring(0, 30)} (${r.year}) ${r.title.substring(0, 70)}`);
    });
  }

  // Now run query B (threatened coral Caribbean)
  console.log('\n\n=== QUERY B: Threatened/Endangered Coral + Caribbean ===');

  await page.goto('https://www.webofscience.com/wos/woscc/advanced-search', {
    waitUntil: 'domcontentloaded',
    timeout: 30000
  });
  await page.waitForTimeout(4000);

  const textarea2 = page.locator('#advancedSearchInputArea');
  await textarea2.click();
  await page.keyboard.press('Meta+A');
  await page.keyboard.press('Backspace');
  await textarea2.type('TS=("threatened coral" OR "endangered coral" OR "ESA" OR "critically endangered") AND TS=("Caribbean" AND (survival OR mortality))', { delay: 5 });
  await page.waitForTimeout(500);

  const searchBtn2 = page.locator('button[data-ta="run-search"]');
  await searchBtn2.click({ force: true });
  await page.waitForTimeout(8000);

  console.log('Query B results URL:', page.url());

  const hitCountB = await page.evaluate(() => {
    const bodyText = document.body?.innerText || '';
    const match = bodyText.match(/(\d[\d,]*)\s+results?\s+from/i);
    return match ? parseInt(match[1].replace(/,/g, '')) : null;
  });
  console.log(`Query B hits: ${hitCountB}`);

  if (hitCountB > 0) {
    // Extract all pages from query B (should be ~2 pages for 58 results)
    const resultsB = await extractAllPages(page, 'threatened_coral_caribbean', 3);
    saveCSV(resultsB, `${BASE_DIR}/wos_threatened_coral_caribbean.csv`);

    console.log('\nFirst 5 results:');
    resultsB.slice(0, 5).forEach((r, i) => {
      console.log(`  ${i+1}. ${r.authors?.substring(0, 30)} (${r.year}) ${r.title.substring(0, 70)}`);
    });
  }

  console.log('\n\n=== SUMMARY ===');
  console.log(`Query A (Acropora + Caribbean demographics): ${hitCountA} hits`);
  console.log(`Query B (Threatened coral + Caribbean survival): ${hitCountB} hits`);
  console.log('\nDone.');
}

main().catch(console.error);
