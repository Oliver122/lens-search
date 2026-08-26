# Specified tests — marketplace-scan-store

Each item is an observable check. A coder treats an unmet item as a gap (`GAPS.md`), not as a license to widen the spec.

1. From the terminal, a run accepts exactly one search term and then scans Kleinanzeigen, then eBay, then Vinted, without requiring login.
2. The same run accepts a list of places used only for Kleinanzeigen. eBay and Vinted in that run are not filtered by those places. Two places (e.g. Karlsruhe and Rheinfelden) are accepted in one Kleinanzeigen scan.
3. A site scan continues until the last page’s last listing for that term (and for Kleinanzeigen, those places). It does not stop after the first listing.
4. Each listing is in the store as soon as it is fetched. If eBay or Vinted then fails, Kleinanzeigen (and any earlier successful site) listings from that run remain readable.
5. When a site fetch fails, a failure record for that site, term, and run is stored and can be read from the terminal after the run.
6. Each stored finding has title, price, URL, site, search term, first-seen date, last-seen date, and at least the first product image from that listing’s page.
7. Two fetches that share the same listing URL produce one stored row, even if the search terms differ.
8. A recheck of a term removes stored findings for that term whose URLs are not in the new fetch. URLs still found stay, with last-seen updated.
9. A chosen date range is applied: findings whose dates fall outside that range are not kept.
10. The terminal can list stored findings sorted by price.
11. Live fetch works: a real run against Kleinanzeigen, eBay, and Vinted persists real listings (or a stored failure if a site fetch fails), not only locally invented rows.
