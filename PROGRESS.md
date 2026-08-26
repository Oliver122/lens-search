# Progress — marketplace-scan-store

States: `todo` | `in-progress` | `done` | `gap`

Live board on `auto-feature/marketplace-scan-store`. Do not edit `requirements/marketplace-scan-store/` to record status.

| # | specified test | state |
|---|---|---|
| 1 | From the terminal, a run accepts exactly one search term and then scans Kleinanzeigen, then eBay, then Vinted, without requiring login. | done |
| 2 | The same run accepts a list of places used only for Kleinanzeigen. eBay and Vinted in that run are not filtered by those places. Two places (e.g. Karlsruhe and Rheinfelden) are accepted in one Kleinanzeigen scan. | todo |
| 3 | A site scan continues until the last page’s last listing for that term (and for Kleinanzeigen, those places). It does not stop after the first listing. | todo |
| 4 | Each listing is in the store as soon as it is fetched. If eBay or Vinted then fails, Kleinanzeigen (and any earlier successful site) listings from that run remain readable. | todo |
| 5 | When a site fetch fails, a failure record for that site, term, and run is stored and can be read from the terminal after the run. | todo |
| 6 | Each stored finding has title, price, URL, site, search term, first-seen date, last-seen date, and at least the first product image from that listing’s page. | todo |
| 7 | Two fetches that share the same listing URL produce one stored row, even if the search terms differ. | todo |
| 8 | A recheck of a term removes stored findings for that term whose URLs are not in the new fetch. URLs still found stay, with last-seen updated. | todo |
| 9 | A chosen date range is applied: findings whose dates fall outside that range are not kept. | todo |
| 10 | The terminal can list stored findings sorted by price. | todo |
| 11 | Live fetch works: a real run against Kleinanzeigen, eBay, and Vinted persists real listings (or a stored failure if a site fetch fails), not only locally invented rows. | todo |
