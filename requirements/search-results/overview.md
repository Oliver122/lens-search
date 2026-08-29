# search-results

Listings from public site scrapes reach the backend through one shared interface. Each site is its own implementation, selected by enum.

## Catalog

### group

fix-results

### slices

backend

### defs

scrape-interface

## In scope

- Shared scrape interface (`scrape-interface`): Rust, under `scraper-components`, `Scraper::{Ebay, Kleinanzeigen, Vinted}`.
- Separate implementation per variant. Callers assign which scraper runs.
- A search term in; one or two listings per variant delivered to the backend (not a full-site crawl).
- Common listing fields on every delivered row (see `scrape-interface`).
- Live checks with common terms `bike` and `pencil` so the term appears on the data and each subcomponent is proven.
- Kleinanzeigen: no place filter.

## Out of scope

- Terminal listing or any UI.
- Pagination to the last listing.
- Place filters.
- Store rules already specified in marketplace-scan-store (URL uniqueness, recheck deletion, date range, stored site-fetch failures).
- Login or session cookies.

## Done when

- Each `Scraper` variant, through the shared interface, delivers one or two real listings for `bike` and for `pencil` to the backend, with the common fields and the search term on each row.
