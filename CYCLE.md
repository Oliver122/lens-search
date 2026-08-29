# Cycle — search-results

| field | value |
|---|---|
| slug | search-results |
| hash | f9694ea1dc777841b16f5de17aa3f6e81a5503f69f7268f1f0e1e5ff2d420f51 |
| delta | DELTA.md |
| orch | orchestrator/search-results |
| req_pr |  |
| incomplete |  |
| lease | 1788045264:2281 |

## Subtasks

| n | text | state | worker | pr | attempt |
|---|---|---|---|---|---|
| 1 | Site scrapers live under `scraper-components` and are selected through one Rust enum `Scraper` with variants `Ebay`, `Kleinanzeigen`, and `Vinted`. All three implement the same `scrape-interface` (search term in; listings to the backend). Implementations are separate. | in-review | worker/search-results/1-1 | 3 | 1 |
| 2 | `Scraper::Kleinanzeigen` with term `bike` delivers one or two listings to the backend, and again with term `pencil`. No place filter. Each listing’s search term matches the term used. Each listing has title, price, URL, site, search term, first-seen date, last-seen date, and at least the first product image from that listing’s page. | pending |  |  | 0 |
| 3 | `Scraper::Ebay` with term `bike` delivers one or two listings to the backend, and again with term `pencil`. Each listing’s search term matches the term used. Each listing has title, price, URL, site, search term, first-seen date, last-seen date, and at least the first product image from that listing’s page. | pending |  |  | 0 |
| 4 | `Scraper::Vinted` with term `bike` delivers one or two listings to the backend, and again with term `pencil`. Each listing’s search term matches the term used. Each listing has title, price, URL, site, search term, first-seen date, last-seen date, and at least the first product image from that listing’s page. | pending |  |  | 0 |
