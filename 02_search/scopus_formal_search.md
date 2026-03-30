# Scopus Search — PRISMA Documentation

**Date:** 2026-03-28
**Database:** Scopus (Elsevier)
**Institution:** University of California Santa Barbara
**Searcher:** AI (Claude Opus 4.6) via Playwright CDP, supervised by Adrian Stier
**Status:** BLOCKED — authentication required

---

## Planned Search Strategy

**Query A (base):** `TITLE-ABS-KEY("Acropora palmata" OR "elkhorn coral")`

**Query B (broader):** `TITLE-ABS-KEY("Acropora" AND "Caribbean") AND TITLE-ABS-KEY(survival OR mortality OR growth OR restoration OR monitoring)`

---

## Access Barrier

Scopus requires individual Elsevier authentication even when accessed from an institutional network. Unlike Web of Science (which uses IP-based institutional authentication), Scopus uses Elsevier's individual sign-in system.

**Authentication attempts made:**

1. **Direct navigation** to `scopus.com/search/form.uri?display=advanced` — redirected to Elsevier login dialog
2. **"Sign in via your organization"** — navigated to "Find your organization" page. Typing "University of California, Santa Barbara" showed a dropdown with Berkeley, Davis, UCLA, but UCSB was either not listed or below the visible portion of the dropdown
3. **Email-based authentication** — entered `stiera@ucsb.edu` in the organization field. Elsevier recognized UCSB and sent a verification email ("Click the link to confirm that you're from University of California Santa Barbara"). This link must be clicked manually by the user to authenticate the session
4. **UCSB library proxy** — `library.ucsb.edu/databases/web-of-science` returned 404 for Scopus (page moved/renamed)
5. **OpenAthens redirect** — returned 403 ("The redirector is not enabled for the specified customer domain")

**Resolution:** To complete Scopus searches, the user needs to:
1. Check email (stiera@ucsb.edu) for the Elsevier verification link
2. Click the link to authenticate the Chrome session
3. Then re-run the Scopus search scripts

Alternatively, Scopus can be accessed manually through the UCSB library website if the proxy URL has changed.

---

## Expected Overlap with WoS

Scopus and WoS have substantial overlap for marine ecology literature. Scopus typically indexes slightly more conference proceedings and non-English journals, while WoS has stronger coverage of older literature. For coral reef ecology specifically:
- Most key journals (Coral Reefs, MEPS, PLoS ONE, Conservation Biology) are indexed in both
- The ~628 WoS hits for the base query would likely correspond to ~500-700 Scopus hits
- Unique Scopus-only papers would predominantly be: conference proceedings, regional journals, and some newer open-access journals

Given the strong search saturation already demonstrated (Elicit: 298 papers recovering all 16 included published studies; WoS: 628 base + 207 survival-specific; PubMed: 63 papers), Scopus is unlikely to reveal missed *A. palmata* demographic studies but would strengthen the PRISMA documentation.

---

*Authentication attempted via Playwright CDP (Chrome DevTools Protocol)*
*Planned queries ready to execute once Scopus session is authenticated*
*Scripts: `02_search/search_results/scopus/scopus_search.mjs` and related files*
