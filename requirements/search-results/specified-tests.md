# Specified tests — search-results

Each item is an observable check. A coder treats an unmet item as a gap (`GAPS.md`), not as a license to widen the spec.

1. [backend] Site scrapers live under `scraper-components` and are selected through one Rust enum `Scraper` with variants `Ebay`, `Kleinanzeigen`, and `Vinted`. All three implement the same `scrape-interface` (search term in; listings to the backend). Implementations are separate.
2. [backend] `Scraper::Kleinanzeigen` with term `bike` delivers one or two listings to the backend, and again with term `pencil`. No place filter. Each listing’s search term matches the term used. Each listing has title, price, URL, site, search term, first-seen date, last-seen date, and at least the first product image from that listing’s page.
3. [backend] `Scraper::Ebay` with term `bike` delivers one or two listings to the backend, and again with term `pencil`. Each listing’s search term matches the term used. Each listing has title, price, URL, site, search term, first-seen date, last-seen date, and at least the first product image from that listing’s page.
4. [backend] `Scraper::Vinted` with term `bike` delivers one or two listings to the backend, and again with term `pencil`. Each listing’s search term matches the term used. Each listing has title, price, URL, site, search term, first-seen date, last-seen date, and at least the first product image from that listing’s page.
