diff --git a/requirements/search-results/overview.md b/requirements/search-results/overview.md
new file mode 100644
index 0000000..3855b2c
--- /dev/null
+++ b/requirements/search-results/overview.md
@@ -0,0 +1,38 @@
+# search-results
+
+Listings from public site scrapes reach the backend through one shared interface. Each site is its own implementation, selected by enum.
+
+## Catalog
+
+### group
+
+fix-results
+
+### slices
+
+backend
+
+### defs
+
+scrape-interface
+
+## In scope
+
+- Shared scrape interface (`scrape-interface`): Rust, under `scraper-components`, `Scraper::{Ebay, Kleinanzeigen, Vinted}`.
+- Separate implementation per variant. Callers assign which scraper runs.
+- A search term in; one or two listings per variant delivered to the backend (not a full-site crawl).
+- Common listing fields on every delivered row (see `scrape-interface`).
+- Live checks with common terms `bike` and `pencil` so the term appears on the data and each subcomponent is proven.
+- Kleinanzeigen: no place filter.
+
+## Out of scope
+
+- Terminal listing or any UI.
+- Pagination to the last listing.
+- Place filters.
+- Store rules already specified in marketplace-scan-store (URL uniqueness, recheck deletion, date range, stored site-fetch failures).
+- Login or session cookies.
+
+## Done when
+
+- Each `Scraper` variant, through the shared interface, delivers one or two real listings for `bike` and for `pencil` to the backend, with the common fields and the search term on each row.
diff --git a/requirements/search-results/specified-tests.md b/requirements/search-results/specified-tests.md
new file mode 100644
index 0000000..37b0030
--- /dev/null
+++ b/requirements/search-results/specified-tests.md
@@ -0,0 +1,8 @@
+# Specified tests — search-results
+
+Each item is an observable check. A coder treats an unmet item as a gap (`GAPS.md`), not as a license to widen the spec.
+
+1. [backend] Site scrapers live under `scraper-components` and are selected through one Rust enum `Scraper` with variants `Ebay`, `Kleinanzeigen`, and `Vinted`. All three implement the same `scrape-interface` (search term in; listings to the backend). Implementations are separate.
+2. [backend] `Scraper::Kleinanzeigen` with term `bike` delivers one or two listings to the backend, and again with term `pencil`. No place filter. Each listing’s search term matches the term used. Each listing has title, price, URL, site, search term, first-seen date, last-seen date, and at least the first product image from that listing’s page.
+3. [backend] `Scraper::Ebay` with term `bike` delivers one or two listings to the backend, and again with term `pencil`. Each listing’s search term matches the term used. Each listing has title, price, URL, site, search term, first-seen date, last-seen date, and at least the first product image from that listing’s page.
+4. [backend] `Scraper::Vinted` with term `bike` delivers one or two listings to the backend, and again with term `pencil`. Each listing’s search term matches the term used. Each listing has title, price, URL, site, search term, first-seen date, last-seen date, and at least the first product image from that listing’s page.
