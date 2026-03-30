#!/usr/bin/env node
/**
 * Complete Scopus institutional authentication - try email domain approach
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

  // Type the UCSB email domain to trigger institutional recognition
  const inputSelector = 'input';
  const inputs = page.locator(inputSelector);
  const inputCount = await inputs.count();
  console.log(`Found ${inputCount} inputs`);

  // Try approach 1: Type full name slowly to trigger autocomplete
  const firstInput = inputs.first();
  await firstInput.click({ clickCount: 3 });
  await firstInput.fill('');
  await page.waitForTimeout(300);

  // Type slowly character by character
  await firstInput.type('University of California, Santa Barbara', { delay: 50 });
  await page.waitForTimeout(3000);

  await page.screenshot({ path: '/tmp/scopus_fullname.png', fullPage: false });
  console.log('Screenshot after typing full name saved');

  // Check for dropdown
  const dropdownVisible = await page.evaluate(() => {
    const lists = document.querySelectorAll('[role="listbox"], .autocomplete, .suggestions, ul.results, .dropdown-menu');
    const visible = [];
    lists.forEach(l => {
      if (l.offsetHeight > 0) {
        visible.push({ tag: l.tagName, text: l.innerText?.substring(0, 300), children: l.children.length });
      }
    });
    // Also check for any list items
    const lis = document.querySelectorAll('li');
    const visibleLi = [];
    lis.forEach(li => {
      if (li.offsetHeight > 0 && li.innerText?.includes('University')) {
        visibleLi.push(li.innerText.substring(0, 150));
      }
    });
    return { lists: visible, listItems: visibleLi };
  });
  console.log('Dropdown check:', JSON.stringify(dropdownVisible, null, 2));

  // Try clicking Submit button directly with the text in the field
  console.log('\nTrying Submit and continue...');
  const submitBtn = page.locator('button:has-text("Submit"), input[type="submit"]');
  const submitCount = await submitBtn.count();
  console.log(`Found ${submitCount} submit buttons`);

  if (submitCount > 0) {
    await submitBtn.first().click();
    await page.waitForTimeout(5000);
    console.log('After submit, URL:', page.url());
    await page.screenshot({ path: '/tmp/scopus_after_submit2.png', fullPage: false });

    const pageText = await page.evaluate(() => document.body?.innerText?.substring(0, 1000));
    console.log('Page text:', pageText?.substring(0, 500));

    // Check if we got redirected to UCSB SSO or Scopus
    const url = page.url();
    if (url.includes('sso') || url.includes('shibboleth') || url.includes('ucsb') || url.includes('scopus.com/search')) {
      console.log('Possible SSO redirect detected!');
      await page.waitForTimeout(5000);
      console.log('URL after waiting:', page.url());
      await page.screenshot({ path: '/tmp/scopus_sso.png', fullPage: false });
    }
  }

  console.log('\nDone.');
}

main().catch(console.error);
