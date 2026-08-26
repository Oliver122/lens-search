# marketplace-scan-store

Personal local app. Terminal is the interface now. Backend is Rust.

## In scope

- One search term per run. Sites scanned in order: Kleinanzeigen, eBay, Vinted. Public search only (no login).
- Kleinanzeigen only: several places in one run (e.g. Karlsruhe and Rheinfelden). eBay and Vinted: no place filter.
- Fetch until the last page’s last listing. Write each listing to the store as soon as it is fetched.
- If a later site fails, already-saved listings stay. The failure is stored and readable later.
- One listing URL is one row (no duplicates across terms). Recheck of a term deletes listings no longer found.
- Each finding: title, price, URL, site, search term, first-seen and last-seen dates, at least the first product image from the listing page. Keep only listings in a chosen date range.
- Terminal: list findings sorted by price. Read stored fetch failures.

## Out of scope

- Graphical UI / later frontend page.
- Login or session cookies for any site.
- Place filters for eBay or Vinted.
- Several search terms in one run.

## Done when

- A run with one term fetches public listings from the three sites (Kleinanzeigen limited to given places), paginates to the last listing, and persists each row immediately with the fields above.
- URL uniqueness, recheck deletion, date range, price-sorted listing, and stored site-fetch failures all hold as specified in `specified-tests.md`.
