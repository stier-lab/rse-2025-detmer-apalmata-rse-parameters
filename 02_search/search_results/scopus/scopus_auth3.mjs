#!/usr/bin/env node
/**
 * Scopus auth - try scrolling dropdown or email domain approach
 */

import { chromium } from 'playwright';

const CDP_URL = 'http://127.0.0.1:9222';

async function main() {
  console.log('Connecting to Chrome via CDP...');
  const browser = await chromium.connectOverCDP(CDP_URL);
  const context = browser.contexts()[0];
  const pages = context.pages();

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

  // First, get the full list of dropdown options by scrolling
  const firstInput = page.locator('input').first();
  await firstInput.click({ clickCount: 3 });
  await firstInput.fill('');
  await page.waitForTimeout(300);

  // Approach 1: Use email to trigger Shibboleth
  console.log('Approach 1: Try email address...');
  await firstInput.type('stiera@ucsb.edu', { delay: 30 });
  await page.waitForTimeout(2000);

  // Look for UCSB in suggestions
  const emailSuggestions = await page.evaluate(() => {
    const container = document.querySelector('[role="listbox"], .autocomplete, .suggestions, .dropdown-menu');
    if (container) {
      return { text: container.innerText, height: container.offsetHeight };
    }
    return null;
  });
  console.log('Email suggestions:', emailSuggestions);
  await page.screenshot({ path: '/tmp/scopus_email.png', fullPage: false });

  // Click Submit
  const submitBtn = page.locator('button:has-text("Submit")');
  if (await submitBtn.count() > 0) {
    await submitBtn.first().click();
    await page.waitForTimeout(8000);
    console.log('After email submit, URL:', page.url());
    await page.screenshot({ path: '/tmp/scopus_email_submit.png', fullPage: false });

    const title = await page.title();
    console.log('Page title:', title);

    const bodyText = await page.evaluate(() => document.body?.innerText?.substring(0, 1500));
    console.log('Body text:', bodyText?.substring(0, 800));

    // Check if we're at UCSB SSO
    const url = page.url();
    if (url.includes('ucsb.edu') || url.includes('sso') || url.includes('shibboleth') || url.includes('idp')) {
      console.log('Redirected to SSO! This requires user interaction for login.');
    }

    // Check if we got back to Scopus search
    if (url.includes('scopus.com/search') || url.includes('scopus.com/results')) {
      console.log('SUCCESS: Redirected to Scopus search!');
    }
  }

  console.log('\nDone.');
}

main().catch(console.error);
