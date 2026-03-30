#!/usr/bin/env node
/**
 * Try to authenticate to Scopus via UCSB institutional access
 */

import { chromium } from 'playwright';

const CDP_URL = 'http://127.0.0.1:9222';

async function main() {
  console.log('Connecting to Chrome via CDP...');
  const browser = await chromium.connectOverCDP(CDP_URL);
  const context = browser.contexts()[0];
  const pages = context.pages();

  // Find Scopus tab
  let page = null;
  for (const p of pages) {
    const url = p.url();
    if (url.includes('scopus') || url.includes('elsevier')) {
      page = p;
      break;
    }
  }
  if (!page) {
    console.log('No Scopus tab found, opening new one');
    page = await context.newPage();
  }

  console.log('Current URL:', page.url());

  // Strategy 1: Try the UCSB library proxy URL for Scopus
  console.log('\nStrategy 1: Try UCSB proxy URL for Scopus...');
  try {
    // UCSB uses EZProxy for off-campus access — try a direct Scopus search URL
    await page.goto('https://www.scopus.com/search/form.uri?display=advanced', {
      waitUntil: 'domcontentloaded',
      timeout: 30000
    });
    await page.waitForTimeout(3000);

    const url = page.url();
    console.log('After navigation, URL:', url);

    if (url.includes('authorization.oauth2') || url.includes('id.elsevier.com')) {
      console.log('Still at login page. Looking for "Sign in via your organization"...');

      // Scroll down to see the full login dialog
      await page.evaluate(() => {
        const modal = document.querySelector('.dialog-content, .modal-content, [role="dialog"]');
        if (modal) modal.scrollTo(0, modal.scrollHeight);
        else window.scrollTo(0, 500);
      });
      await page.waitForTimeout(1000);

      // Look for "Sign in via your organization" link
      const orgLink = page.locator('a:has-text("Sign in via your organization"), a:has-text("your organization"), a:has-text("institution"), button:has-text("your organization")');
      const orgLinkCount = await orgLink.count();
      console.log(`Found ${orgLinkCount} "organization" links`);

      if (orgLinkCount > 0) {
        await orgLink.first().click();
        await page.waitForTimeout(3000);
        console.log('After clicking org link, URL:', page.url());
        await page.screenshot({ path: '/tmp/scopus_org_login.png', fullPage: false });
        console.log('Screenshot saved to /tmp/scopus_org_login.png');

        // Look for UCSB or "University of California" in the organization list
        const pageText = await page.evaluate(() => document.body?.innerText?.substring(0, 3000));
        console.log('Page text:', pageText?.substring(0, 500));

        // Try typing UCSB in the search box
        const searchBox = page.locator('input[type="text"], input[type="search"], input[placeholder*="institution"], input[placeholder*="organization"], input[placeholder*="search"]');
        const searchBoxCount = await searchBox.count();
        console.log(`Found ${searchBoxCount} search inputs`);

        if (searchBoxCount > 0) {
          await searchBox.first().fill('University of California Santa Barbara');
          await page.waitForTimeout(2000);
          await page.screenshot({ path: '/tmp/scopus_org_search.png', fullPage: false });
          console.log('Typed UCSB, screenshot saved');

          // Look for UCSB in results
          const ucsbOption = page.locator('text=Santa Barbara, text=UCSB').first();
          try {
            if (await ucsbOption.isVisible({ timeout: 3000 })) {
              await ucsbOption.click();
              await page.waitForTimeout(3000);
              console.log('Clicked UCSB option, URL:', page.url());
              await page.screenshot({ path: '/tmp/scopus_ucsb_sso.png', fullPage: false });
            }
          } catch (e) {
            console.log('UCSB option not found in dropdown');
          }
        }
      }

      // Strategy 2: Close the dialog and try the "X" close button, then check if Scopus loads
      console.log('\nStrategy 2: Try closing the login dialog...');
      const closeBtn = page.locator('button[aria-label="Close"], .close-button, button:has-text("×"), [aria-label="close"]');
      const closeBtnCount = await closeBtn.count();
      console.log(`Found ${closeBtnCount} close buttons`);

      if (closeBtnCount > 0) {
        await closeBtn.first().click();
        await page.waitForTimeout(2000);
        console.log('After closing, URL:', page.url());
        await page.screenshot({ path: '/tmp/scopus_after_close.png', fullPage: false });
      }
    }

    // Check final state
    const finalUrl = page.url();
    const finalTitle = await page.title();
    console.log(`\nFinal state — URL: ${finalUrl}`);
    console.log(`Title: ${finalTitle}`);

    // Check if we can see the advanced search form
    const searchForm = await page.evaluate(() => {
      const textarea = document.querySelector('textarea, input[name="searchterm"], #searchterm');
      return textarea ? 'Found search input' : 'No search input found';
    });
    console.log('Search form:', searchForm);

  } catch (e) {
    console.log('Error:', e.message);
  }

  console.log('\nDone.');
}

main().catch(console.error);
