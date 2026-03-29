#!/usr/bin/env node
/**
 * v4: Two strategies:
 * 1. Scroll through each page to trigger virtual rendering, then extract
 * 2. If that fails, use WoS Export button
 */

import { chromium } from 'playwright';
import { writeFileSync } from 'fs';

const CDP_URL = 'http://127.0.0.1:9222';
const OUTPUT_FILE = '/Users/adrianstier/Detmer-2025-coral-parameters/02_search/search_results/wos/wos_search1_survival_mortality.csv';

async function main() {
  console.log('Connecting to Chrome via CDP...');
  const browser = await chromium.connectOverCDP(CDP_URL);
  const context = browser.contexts()[0];
  const pages = context.pages();

  let page = null;
  for (const p of pages) {
    if (p.url().includes('webofscience.com')) { page = p; break; }
  }
  if (!page) page = pages[0];
  console.log('Page URL:', page.url());

  // Navigate to page 1
  const baseUrl = page.url().replace(/\/relevance\/\d+$/, '/relevance/1');
  console.log('Navigating to page 1...');
  await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
  await page.waitForTimeout(4000);

  const allResults = [];

  async function scrollAndExtract() {
    // Scroll down slowly to trigger lazy loading of all records
    console.log('  Scrolling to load all records...');

    // First, scroll all the way down in increments
    const scrollResult = await page.evaluate(async () => {
      const delay = ms => new Promise(r => setTimeout(r, ms));

      // Find the scrollable container (might be main, or a specific div)
      const scrollContainer = document.querySelector('app-records-list')?.closest('.scrollable-container')
        || document.querySelector('.search-results-container')
        || document.scrollingElement
        || document.documentElement;

      let lastHeight = 0;
      let attempts = 0;

      // Scroll in increments
      for (let pos = 0; pos < 50000; pos += 500) {
        window.scrollTo(0, pos);
        await delay(100);
      }

      // Wait for any lazy loading to finish
      await delay(1000);

      // Scroll back to top
      window.scrollTo(0, 0);
      await delay(500);

      // Now count rendered records
      const rendered = document.querySelectorAll('app-record');
      let nonEmpty = 0;
      rendered.forEach(r => {
        if (r.children && r.children.length > 0 && r.innerText?.trim().length > 20) {
          nonEmpty++;
        }
      });

      return { total: rendered.length, nonEmpty };
    });

    console.log(`  After scrolling: ${scrollResult.total} total records, ${scrollResult.nonEmpty} non-empty`);

    // Now extract
    const results = await page.evaluate(() => {
      const records = [];
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
          if (line.includes('arrow_drop_down')) {
            journal = line.replace('arrow_drop_down', '').trim();
          }
          const yearMatch = line.match(/^(?:[A-Z][a-z]{2}\s+(?:\d{1,2}\s+)?)?((?:19|20)\d{2})$/);
          if (yearMatch) year = yearMatch[1];
          if (!year && line.length < 30 && !line.includes('http')) {
            const ym = line.match(/\b((?:19|20)\d{2})\b/);
            if (ym) year = ym[1];
          }
        }

        let doi = '';
        const doiLink = rec.querySelector('a[href*="doi.org"]');
        if (doiLink) {
          const doiMatch = doiLink.href?.match(/doi\.org\/(.+)/);
          if (doiMatch) doi = decodeURIComponent(doiMatch[1]);
        }

        records.push({ title, authors, year, journal, doi, wosId });
      });

      return records;
    });

    return results;
  }

  // Try scrolling approach for all pages
  const totalPages = 5;
  for (let pageNum = 1; pageNum <= totalPages; pageNum++) {
    if (pageNum > 1) {
      const pageUrl = baseUrl.replace(/\/relevance\/\d+$/, `/relevance/${pageNum}`);
      console.log(`\nNavigating to page ${pageNum}...`);
      await page.goto(pageUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
      await page.waitForTimeout(4000);
    }

    console.log(`\nPage ${pageNum}:`);
    const pageResults = await scrollAndExtract();
    console.log(`  Extracted ${pageResults.length} results`);
    allResults.push(...pageResults);
  }

  console.log(`\n=== Scroll approach total: ${allResults.length} results ===`);

  // If scroll approach got less than 50 results, try export approach
  if (allResults.length < 50) {
    console.log('\nScroll approach insufficient. Trying WoS Export...');

    // Navigate back to page 1
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForTimeout(4000);

    // Look for the Export dropdown/button
    // From the screenshot, I can see "Export" button with a dropdown arrow
    try {
      console.log('Looking for Export button...');

      // Click the Export dropdown button
      const exportBtn = page.locator('button:has-text("Export")').first();
      if (await exportBtn.isVisible({ timeout: 5000 })) {
        await exportBtn.click();
        await page.waitForTimeout(2000);
        await page.screenshot({ path: '/tmp/wos_export_dropdown.png', fullPage: false });
        console.log('Clicked Export, screenshot saved');

        // Look for export options in the dropdown
        // Common options: "Excel", "Tab delimited file", "Other file format", "BibTeX"
        const exportOptions = await page.evaluate(() => {
          const buttons = document.querySelectorAll('button, a, mat-option, [role="menuitem"], [role="option"]');
          const options = [];
          buttons.forEach(b => {
            const text = b.textContent?.trim();
            if (text && (text.includes('Excel') || text.includes('Tab') || text.includes('BibTeX') ||
                text.includes('Plain') || text.includes('CSV') || text.includes('file') ||
                text.includes('RIS') || text.includes('Other'))) {
              options.push({
                text: text.substring(0, 100),
                tag: b.tagName,
                class: b.className?.substring(0, 50),
              });
            }
          });
          return options;
        });
        console.log('Export options found:', JSON.stringify(exportOptions, null, 2));

        // Try "Tab delimited file" or "Excel" for structured data
        for (const optionText of ['Tab delimited file', 'Plain text file', 'Excel', 'BibTeX', 'RIS']) {
          const opt = page.locator(`button:has-text("${optionText}"), [role="menuitem"]:has-text("${optionText}"), a:has-text("${optionText}")`).first();
          try {
            if (await opt.isVisible({ timeout: 1000 })) {
              console.log(`Found "${optionText}" option, clicking...`);
              await opt.click();
              await page.waitForTimeout(3000);
              await page.screenshot({ path: '/tmp/wos_export_config.png', fullPage: false });
              console.log('Export config screenshot saved');
              break;
            }
          } catch (e) {
            continue;
          }
        }
      }
    } catch (e) {
      console.log('Export attempt error:', e.message);
    }
  }

  // If we still have few results, try a completely different approach:
  // Use the WoS "Analyze Results" or "Citation Report" to get a summary
  if (allResults.length < 50) {
    console.log('\nTrying alternative: extract via page text parsing...');

    // Navigate back to page 1 with 10 results per page (default, less virtual scrolling issues)
    // Actually, let's try changing display format

    // Navigate to page 1
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForTimeout(4000);

    // Try to get the page HTML and parse more aggressively
    for (let pageNum = 1; pageNum <= totalPages; pageNum++) {
      if (pageNum > 1) {
        const pageUrl = baseUrl.replace(/\/relevance\/\d+$/, `/relevance/${pageNum}`);
        await page.goto(pageUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
        await page.waitForTimeout(4000);
      }

      // Scroll very slowly through the entire page
      console.log(`\nPage ${pageNum}: slow scrolling...`);
      const slowResults = await page.evaluate(async () => {
        const delay = ms => new Promise(r => setTimeout(r, ms));

        // Get the total page height
        const totalHeight = document.documentElement.scrollHeight;
        let currentPosition = 0;
        const step = 300; // scroll 300px at a time

        while (currentPosition < totalHeight) {
          window.scrollTo(0, currentPosition);
          await delay(200); // Wait 200ms between scrolls to allow rendering
          currentPosition += step;
        }

        // Final wait at bottom
        await delay(500);

        // Now scroll back up slowly
        currentPosition = totalHeight;
        while (currentPosition > 0) {
          window.scrollTo(0, currentPosition);
          await delay(100);
          currentPosition -= step;
        }

        await delay(500);

        // Now extract everything
        const records = [];
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
            if (line.includes('arrow_drop_down')) {
              journal = line.replace('arrow_drop_down', '').trim();
            }
            if (!year && line.length < 30 && !line.includes('http')) {
              const ym = line.match(/\b((?:19|20)\d{2})\b/);
              if (ym) year = ym[1];
            }
          }

          let doi = '';
          const doiLink = rec.querySelector('a[href*="doi.org"]');
          if (doiLink) {
            const doiMatch = doiLink.href?.match(/doi\.org\/(.+)/);
            if (doiMatch) doi = decodeURIComponent(doiMatch[1]);
          }

          records.push({ title, authors, year, journal, doi, wosId });
        });

        return records;
      });

      console.log(`  Slow scroll extracted: ${slowResults.length} results`);

      // Deduplicate by WoS ID before adding
      for (const r of slowResults) {
        if (!allResults.some(existing => existing.wosId === r.wosId && existing.title === r.title)) {
          allResults.push(r);
        }
      }
    }

    console.log(`\nAfter slow scroll: ${allResults.length} unique results`);
  }

  // Save whatever we have
  if (allResults.length > 0) {
    // Deduplicate by title
    const seen = new Set();
    const unique = [];
    for (const r of allResults) {
      const key = r.title.toLowerCase().substring(0, 50);
      if (!seen.has(key)) {
        seen.add(key);
        unique.push(r);
      }
    }

    const escape = (s) => `"${(s || '').replace(/"/g, '""')}"`;
    const csvHeader = 'title,authors,year,journal,doi,wos_id';
    const csvRows = unique.map(r =>
      [escape(r.title), escape(r.authors), escape(r.year), escape(r.journal),
       escape(r.doi), escape(r.wosId)].join(',')
    );
    const csv = [csvHeader, ...csvRows].join('\n');
    writeFileSync(OUTPUT_FILE, csv, 'utf-8');
    console.log(`\nSaved ${unique.length} unique results to ${OUTPUT_FILE}`);

    // Summary
    console.log('\nFirst 10 results:');
    unique.slice(0, 10).forEach((r, i) => {
      console.log(`  ${i + 1}. ${r.authors?.substring(0, 40)} (${r.year}) ${r.title.substring(0, 70)}...`);
    });
  }

  console.log('\nDone.');
}

main().catch(console.error);
