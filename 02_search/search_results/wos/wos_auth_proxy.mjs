#!/usr/bin/env node
/**
 * Try to access WoS through UCSB library proxy for authentication
 * UCSB typically uses EZProxy or OpenAthens
 */

import { chromium } from 'playwright';

const CDP_URL = 'http://127.0.0.1:9222';

async function main() {
  console.log('Connecting to Chrome via CDP...');
  const browser = await chromium.connectOverCDP(CDP_URL);
  const context = browser.contexts()[0];

  // Open new tab
  const page = await context.newPage();

  // Strategy 1: UCSB Library WoS link
  // UCSB library typically provides a proxied link
  console.log('Strategy 1: Try UCSB Library link to WoS...');

  try {
    // Common UCSB library proxy patterns
    const proxyUrls = [
      'https://ucsb.idm.oclc.org/login?url=https://www.webofscience.com',
      'https://www-webofscience-com.proxy.library.ucsb.edu/wos/woscc/advanced-search',
      'https://www.library.ucsb.edu/databases/web-of-science',
    ];

    for (const url of proxyUrls) {
      console.log(`\nTrying: ${url}`);
      try {
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 15000 });
        await page.waitForTimeout(3000);
        const currentUrl = page.url();
        const title = await page.title();
        console.log(`  URL: ${currentUrl}`);
        console.log(`  Title: ${title}`);

        // Check if we're on WoS or a login page
        if (currentUrl.includes('webofscience.com')) {
          console.log('  SUCCESS: Reached WoS!');

          // Check if authenticated
          const authStatus = await page.evaluate(() => {
            const body = document.body?.innerText || '';
            const hasSignIn = body.includes('Sign In') || body.includes('Sign in');
            const hasSignOut = body.includes('Sign Out') || body.includes('Logout') || body.includes('Sign out');
            const hasInstitution = body.includes('UCSB') || body.includes('University of California');
            return { hasSignIn, hasSignOut, hasInstitution };
          });
          console.log('  Auth status:', authStatus);

          await page.screenshot({ path: '/tmp/wos_proxy_result.png', fullPage: false });

          if (authStatus.hasSignOut || authStatus.hasInstitution) {
            console.log('  AUTHENTICATED!');
            break;
          }
        } else if (currentUrl.includes('ucsb.edu') || currentUrl.includes('shibboleth') || currentUrl.includes('idm.oclc.org')) {
          console.log('  Got UCSB login page');
          await page.screenshot({ path: '/tmp/wos_ucsb_login.png', fullPage: false });

          // Check for SSO redirect or login form
          const pageText = await page.evaluate(() => document.body?.innerText?.substring(0, 500));
          console.log('  Page text:', pageText?.substring(0, 300));
        }
      } catch (e) {
        console.log(`  Error: ${e.message.substring(0, 100)}`);
      }
    }
  } catch (e) {
    console.log('Strategy 1 error:', e.message);
  }

  // Strategy 2: Try WoS with institution parameter
  console.log('\n\nStrategy 2: Try WoS with institution parameter...');
  try {
    await page.goto('https://www.webofscience.com/wos/woscc/advanced-search?SID=&inst=UCSB', {
      waitUntil: 'domcontentloaded',
      timeout: 15000
    });
    await page.waitForTimeout(3000);
    console.log('URL:', page.url());
    console.log('Title:', await page.title());

    // Check for WAYFless URL
    await page.goto('https://www.webofscience.com/wos/?mode=Nextgen&New=1&SID=USW2EC0EACUCSB', {
      waitUntil: 'domcontentloaded',
      timeout: 15000
    });
    await page.waitForTimeout(3000);
    console.log('WAYFless URL:', page.url());
  } catch (e) {
    console.log('Strategy 2 error:', e.message);
  }

  // Strategy 3: Check if the WoS API/Smart Search works without auth
  // Smart Search might be more permissive
  console.log('\n\nStrategy 3: Try Smart Search...');
  try {
    await page.goto('https://www.webofscience.com/wos/woscc/basic-search', {
      waitUntil: 'domcontentloaded',
      timeout: 15000
    });
    await page.waitForTimeout(3000);
    console.log('URL:', page.url());
    console.log('Title:', await page.title());
    await page.screenshot({ path: '/tmp/wos_basic_search.png', fullPage: false });

    const bodyText = await page.evaluate(() => document.body?.innerText?.substring(0, 500));
    console.log('Body:', bodyText?.substring(0, 300));
  } catch (e) {
    console.log('Strategy 3 error:', e.message);
  }

  console.log('\nDone.');
}

main().catch(console.error);
