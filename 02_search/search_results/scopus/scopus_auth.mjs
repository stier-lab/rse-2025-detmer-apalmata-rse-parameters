#!/usr/bin/env node
/**
 * Complete Scopus institutional authentication via UCSB
 */

import { chromium } from 'playwright';

const CDP_URL = 'http://127.0.0.1:9222';

async function main() {
  console.log('Connecting to Chrome via CDP...');
  const browser = await chromium.connectOverCDP(CDP_URL);
  const context = browser.contexts()[0];
  const pages = context.pages();

  // Find the Scopus/Elsevier tab
  let page = null;
  for (const p of pages) {
    const url = p.url();
    if (url.includes('elsevier') || url.includes('scopus')) {
      page = p;
      break;
    }
  }
  if (!page) {
    console.log('No Scopus tab found');
    return;
  }

  console.log('Current URL:', page.url());

  // We're on the "Find your organization" page
  // The input already has "University of California Santa Barbara" typed
  // Need to scroll down in the dropdown to find UCSB

  // First, let's see what options are available
  const options = await page.evaluate(() => {
    const items = document.querySelectorAll('[role="option"], li, .suggestion, .autocomplete-item, a[class*="suggestion"]');
    const texts = [];
    items.forEach(item => {
      const text = item.textContent?.trim();
      if (text && text.includes('University') || text && text.includes('Santa Barbara')) {
        texts.push(text.substring(0, 150));
      }
    });
    return texts;
  });
  console.log('Dropdown options:', options);

  // Clear and re-type to get better results
  const inputSelector = 'input[type="text"], input[type="search"], input[name*="org"], input[id*="org"]';
  const inputs = page.locator(inputSelector);
  const inputCount = await inputs.count();
  console.log(`Found ${inputCount} inputs`);

  if (inputCount > 0) {
    // Try clearing and typing just "UCSB"
    await inputs.first().click({ clickCount: 3 }); // Select all
    await inputs.first().fill('');
    await page.waitForTimeout(500);
    await inputs.first().fill('UCSB');
    await page.waitForTimeout(2000);

    await page.screenshot({ path: '/tmp/scopus_ucsb.png', fullPage: false });
    console.log('Typed "UCSB", screenshot saved');

    // Check dropdown options again
    const options2 = await page.evaluate(() => {
      const allElements = document.querySelectorAll('*');
      const matches = [];
      allElements.forEach(el => {
        const text = el.textContent?.trim();
        if (text && text.length < 200 && (text.includes('Santa Barbara') || text.includes('UCSB'))) {
          if (el.tagName === 'LI' || el.tagName === 'A' || el.getAttribute('role') === 'option'
              || el.classList.contains('option') || el.classList.contains('suggestion')
              || el.tagName === 'BUTTON' || el.tagName === 'DIV') {
            matches.push({ tag: el.tagName, text: text.substring(0, 150), class: el.className?.substring(0, 80) });
          }
        }
      });
      return matches;
    });
    console.log('UCSB options:', JSON.stringify(options2, null, 2));

    // Now try scrolling the dropdown list and clicking on any UCSB match
    const ucsbLink = page.locator('text=Santa Barbara').first();
    try {
      if (await ucsbLink.isVisible({ timeout: 3000 })) {
        console.log('Found Santa Barbara option, clicking...');
        await ucsbLink.click();
        await page.waitForTimeout(2000);
        console.log('After click, URL:', page.url());
        await page.screenshot({ path: '/tmp/scopus_after_ucsb.png', fullPage: false });
      }
    } catch (e) {
      console.log('Could not click Santa Barbara option:', e.message);

      // Try the submit button
      const submitBtn = page.locator('button:has-text("Submit"), button:has-text("continue")');
      const submitCount = await submitBtn.count();
      console.log(`Found ${submitCount} submit buttons`);
      if (submitCount > 0) {
        await submitBtn.first().click();
        await page.waitForTimeout(5000);
        console.log('After submit, URL:', page.url());
        await page.screenshot({ path: '/tmp/scopus_after_submit.png', fullPage: false });
      }
    }
  }

  // Final check
  const finalUrl = page.url();
  console.log('Final URL:', finalUrl);
  const pageText = await page.evaluate(() => document.body?.innerText?.substring(0, 1000));
  console.log('Page text:', pageText?.substring(0, 500));

  console.log('\nDone.');
}

main().catch(console.error);
