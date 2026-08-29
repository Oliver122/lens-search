# scrape-interface

Shared Rust scrape contract. Site implementations are separate; callers pick which one runs.

- Lives under `scraper-components`.
- One enum: `Scraper` with variants `Ebay`, `Kleinanzeigen`, `Vinted` (e.g. `Scraper::Ebay`).
- Same interface for every variant: a search term in; listings out to the backend.
- Each listing has the same fields: title, price, URL, site, search term, first-seen date, last-seen date, at least the first product image from that listing’s page.
