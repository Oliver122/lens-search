//! Terminal run: one search term, then public scans in site order.

mod live;

pub use live::LivePageSource;

use std::cell::RefCell;
use std::collections::HashSet;
use std::rc::Rc;
use std::time::{SystemTime, UNIX_EPOCH};

pub const SITES_IN_ORDER: [&str; 3] = ["Kleinanzeigen", "eBay", "Vinted"];

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ScanRequest {
    pub site: String,
    pub term: String,
    pub url: String,
    /// Empty for public search. Login cookies or Authorization must not appear.
    pub headers: Vec<(String, String)>,
    /// Used only for Kleinanzeigen. Always empty for eBay and Vinted.
    pub places: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RunArgs {
    pub term: String,
    pub places: Vec<String>,
}

impl ScanRequest {
    pub fn requires_login(&self) -> bool {
        self.headers.iter().any(|(name, _)| {
            name.eq_ignore_ascii_case("authorization") || name.eq_ignore_ascii_case("cookie")
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RunError {
    MissingTerm,
    ExtraTerms,
    EmptyTerm,
    EmptyPlaces,
}

impl std::fmt::Display for RunError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            RunError::MissingTerm => write!(f, "a run needs exactly one search term"),
            RunError::ExtraTerms => write!(f, "a run accepts exactly one search term"),
            RunError::EmptyTerm => write!(f, "search term must not be empty"),
            RunError::EmptyPlaces => write!(f, "--places needs at least one place"),
        }
    }
}

impl std::error::Error for RunError {}

/// Parse `run <term> [--places PLACE ...]` from argv after the program name.
pub fn parse_run_args(args: &[String]) -> Result<RunArgs, RunError> {
    let mut rest = args.iter();
    match rest.next().map(String::as_str) {
        Some("run") => {}
        None | Some(_) => return Err(RunError::MissingTerm),
    }
    let term = rest.next().cloned().ok_or(RunError::MissingTerm)?;
    if term.is_empty() {
        return Err(RunError::EmptyTerm);
    }
    let places = match rest.next().map(String::as_str) {
        None => Vec::new(),
        Some("--places") => {
            let places: Vec<String> = rest.cloned().collect();
            if places.is_empty() {
                return Err(RunError::EmptyPlaces);
            }
            places
        }
        Some(_) => return Err(RunError::ExtraTerms),
    };
    Ok(RunArgs { term, places })
}

pub fn public_search_url(site: &str, term: &str) -> String {
    let q = urlencode(term);
    match site {
        "Kleinanzeigen" => format!("https://www.kleinanzeigen.de/s-{}/k0", q),
        "eBay" => format!("https://www.ebay.de/sch/i.html?_nkw={q}"),
        "Vinted" => format!("https://www.vinted.de/catalog?search_text={q}"),
        other => panic!("unknown site {other}"),
    }
}

pub(crate) fn urlencode(s: &str) -> String {
    let mut out = String::new();
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(b as char);
            }
            b' ' => out.push('+'),
            _ => {
                out.push('%');
                out.push(nibble(b >> 4));
                out.push(nibble(b & 0xf));
            }
        }
    }
    out
}

fn nibble(n: u8) -> char {
    b"0123456789ABCDEF"[n as usize] as char
}

pub fn scan_requests(term: &str, places: &[String]) -> Vec<ScanRequest> {
    SITES_IN_ORDER
        .iter()
        .map(|site| {
            let site_places = if *site == "Kleinanzeigen" {
                places.to_vec()
            } else {
                Vec::new()
            };
            ScanRequest {
                site: (*site).to_string(),
                term: term.to_string(),
                url: public_search_url(site, term),
                headers: Vec::new(),
                places: site_places,
            }
        })
        .collect()
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Listing {
    pub title: String,
    pub price: String,
    pub url: String,
    pub site: String,
    pub search_term: String,
    pub first_seen: String,
    pub last_seen: String,
    /// Image URLs taken from the listing page, first image first.
    pub product_images: Vec<String>,
}

/// Inclusive first-seen / last-seen window. Dates are `YYYY-MM-DD`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DateRange {
    pub start: String,
    pub end: String,
}

pub fn finding_dates_in_range(listing: &Listing, range: &DateRange) -> bool {
    date_in_range(&listing.first_seen, range) && date_in_range(&listing.last_seen, range)
}

fn date_in_range(date: &str, range: &DateRange) -> bool {
    date >= range.start.as_str() && date <= range.end.as_str()
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ListingPage {
    pub title: String,
    pub price: String,
    pub product_images: Vec<String>,
}

pub fn utc_ymd(secs: u64) -> String {
    // Howard Hinnant civil-from-days (Unix epoch).
    let z = (secs / 86400) as i64 + 719468;
    let era = if z >= 0 { z } else { z - 146096 } / 146097;
    let doe = (z - era * 146097) as u64;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe as i64 + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 36524);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };
    format!("{y:04}-{m:02}-{d:02}")
}

pub fn today_date() -> String {
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    utc_ymd(secs)
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FetchFailure {
    pub site: String,
    pub term: String,
    pub run_id: String,
}

pub fn new_run_id() -> String {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos().to_string())
        .unwrap_or_else(|_| "0".to_string())
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SearchPage {
    pub listings: Vec<Listing>,
    pub is_last: bool,
}

pub trait PageSource {
    fn fetch_page(&mut self, request: &ScanRequest, page: u32) -> Result<SearchPage, String>;
    fn fetch_listing_page(&mut self, url: &str) -> Result<ListingPage, String>;
}

/// In-memory listing store. Saves are visible immediately to other handles.
#[derive(Clone, Default)]
pub struct MemoryStore {
    listings: Rc<RefCell<Vec<Listing>>>,
    failures: Rc<RefCell<Vec<FetchFailure>>>,
    fetched_urls: Rc<RefCell<HashSet<String>>>,
    date_range: Rc<RefCell<Option<DateRange>>>,
}

impl MemoryStore {
    pub fn set_date_range(&self, range: DateRange) {
        *self.date_range.borrow_mut() = Some(range);
        self.drop_outside_date_range();
    }

    fn drop_outside_date_range(&self) {
        let range = self.date_range.borrow().clone();
        let Some(range) = range else {
            return;
        };
        self.listings
            .borrow_mut()
            .retain(|listing| finding_dates_in_range(listing, &range));
    }

    pub fn save(&self, listing: Listing) {
        {
            let mut listings = self.listings.borrow_mut();
            if let Some(existing) = listings.iter_mut().find(|row| row.url == listing.url) {
                existing.title = listing.title;
                existing.price = listing.price;
                existing.site = listing.site;
                existing.search_term = listing.search_term;
                existing.last_seen = listing.last_seen;
                existing.product_images = listing.product_images;
            } else {
                listings.push(listing);
            }
        }
        self.drop_outside_date_range();
    }

    pub fn listings(&self) -> Vec<Listing> {
        self.listings.borrow().clone()
    }

    pub fn save_failure(&self, failure: FetchFailure) {
        self.failures.borrow_mut().push(failure);
    }

    pub fn failures(&self) -> Vec<FetchFailure> {
        self.failures.borrow().clone()
    }

    pub fn begin_fetch(&self) {
        self.fetched_urls.borrow_mut().clear();
    }

    pub fn note_fetched(&self, url: String) {
        self.fetched_urls.borrow_mut().insert(url);
    }

    /// Drop stored findings for `term` whose URLs were not in the fetch just recorded.
    pub fn remove_unseen_for_term(&self, term: &str) {
        let fetched = self.fetched_urls.borrow();
        self.listings.borrow_mut().retain(|listing| {
            listing.search_term != term || fetched.contains(&listing.url)
        });
        self.drop_outside_date_range();
    }
}

pub fn listings_sorted_by_price(listings: &[Listing]) -> Vec<Listing> {
    let mut out = listings.to_vec();
    out.sort_by(|a, b| price_sort_key(&a.price).cmp(&price_sort_key(&b.price)));
    out
}

fn price_sort_key(price: &str) -> i64 {
    let digits: String = price.chars().filter(|c| c.is_ascii_digit()).take(18).collect();
    if digits.is_empty() {
        i64::MAX
    } else {
        digits.parse().unwrap_or(i64::MAX)
    }
}

pub fn encode_listing_line(listing: &Listing) -> String {
    format!(
        "{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}",
        listing.title,
        listing.price,
        listing.url,
        listing.site,
        listing.search_term,
        listing.first_seen,
        listing.last_seen,
        listing.product_images.join("|")
    )
}

pub fn parse_listing_line(line: &str) -> Option<Listing> {
    let mut parts = line.splitn(8, '\t');
    let title = parts.next()?.to_string();
    let price = parts.next()?.to_string();
    let url = parts.next()?.to_string();
    let site = parts.next()?.to_string();
    let search_term = parts.next()?.to_string();
    let first_seen = parts.next()?.to_string();
    let last_seen = parts.next()?.to_string();
    let images = parts.next()?;
    if url.is_empty() {
        return None;
    }
    let product_images = if images.is_empty() {
        Vec::new()
    } else {
        images.split('|').map(str::to_string).collect()
    };
    Some(Listing {
        title,
        price,
        url,
        site,
        search_term,
        first_seen,
        last_seen,
        product_images,
    })
}

pub fn encode_failure_line(failure: &FetchFailure) -> String {
    format!("{}\t{}\t{}", failure.run_id, failure.site, failure.term)
}

pub fn parse_failure_line(line: &str) -> Option<FetchFailure> {
    let mut parts = line.splitn(3, '\t');
    let run_id = parts.next()?.to_string();
    let site = parts.next()?.to_string();
    let term = parts.next()?.to_string();
    if run_id.is_empty() || site.is_empty() {
        return None;
    }
    Some(FetchFailure {
        site,
        term,
        run_id,
    })
}

/// Fetch every page for one site request until the last page’s last listing.
/// Each listing is written to the store as soon as its page is fetched.
pub fn collect_listings(
    request: &ScanRequest,
    source: &mut impl PageSource,
    store: &MemoryStore,
) -> Result<(), String> {
    let mut page = 1u32;
    loop {
        let search_page = source.fetch_page(request, page)?;
        let done = search_page.is_last || search_page.listings.is_empty();
        let seen = today_date();
        for listing in search_page.listings {
            let page = source.fetch_listing_page(&listing.url)?;
            if page.product_images.is_empty() {
                return Err(format!("listing page {} has no product image", listing.url));
            }
            store.save(Listing {
                title: page.title,
                price: page.price,
                url: listing.url.clone(),
                site: listing.site,
                search_term: request.term.clone(),
                first_seen: seen.clone(),
                last_seen: seen.clone(),
                product_images: page.product_images,
            });
            store.note_fetched(listing.url);
        }
        if done {
            break;
        }
        page += 1;
    }
    Ok(())
}

pub struct PaginatingScanner<S> {
    pub source: S,
    pub store: MemoryStore,
}

impl<S: PageSource> PaginatingScanner<S> {
    pub fn new(source: S) -> Self {
        Self {
            source,
            store: MemoryStore::default(),
        }
    }

    pub fn listings_for(&self, site: &str) -> Vec<Listing> {
        self.store
            .listings()
            .into_iter()
            .filter(|listing| listing.site == site)
            .collect()
    }
}

impl<S: PageSource> SiteScanner for PaginatingScanner<S> {
    fn scan(&mut self, request: &ScanRequest) -> Result<(), String> {
        collect_listings(request, &mut self.source, &self.store)
    }

    fn note_failure(&mut self, failure: FetchFailure) {
        self.store.save_failure(failure);
    }

    fn fetch_failures(&self) -> Vec<FetchFailure> {
        self.store.failures()
    }

    fn begin_run(&mut self) {
        self.store.begin_fetch();
    }

    fn finish_run(&mut self, term: &str) {
        self.store.remove_unseen_for_term(term);
    }
}

pub trait SiteScanner {
    fn scan(&mut self, request: &ScanRequest) -> Result<(), String>;

    fn note_failure(&mut self, _failure: FetchFailure) {}

    fn fetch_failures(&self) -> Vec<FetchFailure> {
        Vec::new()
    }

    fn begin_run(&mut self) {}

    fn finish_run(&mut self, _term: &str) {}
}

/// Scan Kleinanzeigen, then eBay, then Vinted. Public search only (no login).
pub fn run(term: &str, places: &[String], scanner: &mut impl SiteScanner) -> Result<(), String> {
    run_sites(term, places, scanner, true)
}

/// Scan every site even if an earlier site fetch fails. Already-saved listings stay.
pub fn run_scanning_all_sites(
    term: &str,
    places: &[String],
    scanner: &mut impl SiteScanner,
) -> Result<(), String> {
    run_sites(term, places, scanner, false)
}

fn run_sites(
    term: &str,
    places: &[String],
    scanner: &mut impl SiteScanner,
    stop_on_failure: bool,
) -> Result<(), String> {
    if term.is_empty() {
        return Err(RunError::EmptyTerm.to_string());
    }
    let run_id = new_run_id();
    scanner.begin_run();
    let mut first_err = None;
    for request in scan_requests(term, places) {
        if request.requires_login() {
            return Err(format!("{} scan must not require login", request.site));
        }
        if let Err(err) = scanner.scan(&request) {
            scanner.note_failure(FetchFailure {
                site: request.site.clone(),
                term: request.term.clone(),
                run_id: run_id.clone(),
            });
            if stop_on_failure {
                return Err(err);
            }
            if first_err.is_none() {
                first_err = Some(err);
            }
        }
    }
    if first_err.is_none() {
        scanner.finish_run(term);
    }
    match first_err {
        Some(err) => Err(err),
        None => Ok(()),
    }
}

#[derive(Default)]
pub struct RecordingScanner {
    pub calls: Vec<ScanRequest>,
}

impl SiteScanner for RecordingScanner {
    fn scan(&mut self, request: &ScanRequest) -> Result<(), String> {
        self.calls.push(request.clone());
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn args(parts: &[&str]) -> Vec<String> {
        parts.iter().map(|s| (*s).to_string()).collect()
    }

    #[test]
    fn run_accepts_exactly_one_search_term() {
        let parsed = parse_run_args(&args(&["run", "Fahrrad"])).unwrap();
        assert_eq!(parsed.term, "Fahrrad");
        assert!(parsed.places.is_empty());
        assert_eq!(parse_run_args(&args(&["run"])), Err(RunError::MissingTerm));
        assert_eq!(
            parse_run_args(&args(&["run", "a", "b"])),
            Err(RunError::ExtraTerms)
        );
    }

    #[test]
    fn run_scans_kleinanzeigen_then_ebay_then_vinted_without_login() {
        let mut scanner = RecordingScanner::default();
        run("Fahrrad", &[], &mut scanner).unwrap();

        let sites: Vec<&str> = scanner.calls.iter().map(|c| c.site.as_str()).collect();
        assert_eq!(sites, ["Kleinanzeigen", "eBay", "Vinted"]);

        for call in &scanner.calls {
            assert_eq!(call.term, "Fahrrad");
            assert!(!call.requires_login(), "{} must be public search", call.site);
            assert!(
                call.url.starts_with("https://"),
                "public search URL for {}",
                call.site
            );
        }
    }

    #[test]
    fn run_accepts_two_places_only_for_kleinanzeigen() {
        let parsed = parse_run_args(&args(&[
            "run",
            "Fahrrad",
            "--places",
            "Karlsruhe",
            "Rheinfelden",
        ]))
        .unwrap();
        assert_eq!(parsed.term, "Fahrrad");
        assert_eq!(parsed.places, ["Karlsruhe", "Rheinfelden"]);

        let mut scanner = RecordingScanner::default();
        run(&parsed.term, &parsed.places, &mut scanner).unwrap();

        let kleinanzeigen: Vec<&ScanRequest> = scanner
            .calls
            .iter()
            .filter(|c| c.site == "Kleinanzeigen")
            .collect();
        assert_eq!(kleinanzeigen.len(), 1, "two places in one Kleinanzeigen scan");
        assert_eq!(
            kleinanzeigen[0].places,
            ["Karlsruhe", "Rheinfelden"]
        );

        for call in &scanner.calls {
            if call.site == "eBay" || call.site == "Vinted" {
                assert!(
                    call.places.is_empty(),
                    "{} must not be filtered by places",
                    call.site
                );
                assert!(
                    !call.url.contains("Karlsruhe") && !call.url.contains("Rheinfelden"),
                    "{} URL must not include places",
                    call.site
                );
            }
        }
    }

    #[derive(Default)]
    struct FakePageSource {
        pages: std::collections::HashMap<(String, u32), SearchPage>,
        listing_pages: std::collections::HashMap<String, ListingPage>,
        fetches: Vec<(String, u32, Vec<String>)>,
    }

    impl FakePageSource {
        fn add(&mut self, site: &str, page: u32, is_last: bool, urls: &[&str]) {
            self.pages.insert(
                (site.to_string(), page),
                SearchPage {
                    listings: urls
                        .iter()
                        .map(|url| Listing {
                            title: String::new(),
                            price: String::new(),
                            url: (*url).to_string(),
                            site: site.to_string(),
                            search_term: String::new(),
                            first_seen: String::new(),
                            last_seen: String::new(),
                            product_images: Vec::new(),
                        })
                        .collect(),
                    is_last,
                },
            );
            for url in urls {
                self.listing_pages.entry((*url).to_string()).or_insert_with(|| {
                    ListingPage {
                        title: format!("title for {url}"),
                        price: "1".to_string(),
                        product_images: vec![format!("{url}/photo.jpg")],
                    }
                });
            }
        }

        fn set_listing_page(&mut self, url: &str, page: ListingPage) {
            self.listing_pages.insert(url.to_string(), page);
        }
    }

    impl PageSource for FakePageSource {
        fn fetch_page(
            &mut self,
            request: &ScanRequest,
            page: u32,
        ) -> Result<SearchPage, String> {
            self.fetches
                .push((request.site.clone(), page, request.places.clone()));
            self.pages
                .get(&(request.site.clone(), page))
                .cloned()
                .ok_or_else(|| format!("missing page {page} for {}", request.site))
        }

        fn fetch_listing_page(&mut self, url: &str) -> Result<ListingPage, String> {
            self.listing_pages
                .get(url)
                .cloned()
                .ok_or_else(|| format!("missing listing page for {url}"))
        }
    }

    #[test]
    fn site_scan_continues_until_last_page_last_listing() {
        let mut source = FakePageSource::default();
        source.add(
            "Kleinanzeigen",
            1,
            false,
            &["https://ka.example/1", "https://ka.example/2"],
        );
        source.add("Kleinanzeigen", 2, true, &["https://ka.example/3"]);
        source.add("eBay", 1, false, &["https://eb.example/1"]);
        source.add("eBay", 2, true, &["https://eb.example/2"]);
        source.add(
            "Vinted",
            1,
            true,
            &["https://vi.example/1", "https://vi.example/2"],
        );

        let places = vec!["Karlsruhe".to_string(), "Rheinfelden".to_string()];
        let mut scanner = PaginatingScanner::new(source);
        run("Fahrrad", &places, &mut scanner).unwrap();

        let ka: Vec<String> = scanner
            .listings_for("Kleinanzeigen")
            .into_iter()
            .map(|l| l.url)
            .collect();
        assert_eq!(
            ka,
            [
                "https://ka.example/1",
                "https://ka.example/2",
                "https://ka.example/3"
            ],
            "Kleinanzeigen must not stop after the first listing"
        );

        let eb: Vec<String> = scanner
            .listings_for("eBay")
            .into_iter()
            .map(|l| l.url)
            .collect();
        assert_eq!(eb, ["https://eb.example/1", "https://eb.example/2"]);

        let vi: Vec<String> = scanner
            .listings_for("Vinted")
            .into_iter()
            .map(|l| l.url)
            .collect();
        assert_eq!(vi, ["https://vi.example/1", "https://vi.example/2"]);

        let fetches = &scanner.source.fetches;
        let ka_fetches: Vec<&(String, u32, Vec<String>)> = fetches
            .iter()
            .filter(|(site, _, _)| site == "Kleinanzeigen")
            .collect();
        assert_eq!(
            ka_fetches.len(),
            2,
            "Kleinanzeigen must fetch through the last page"
        );
        for (_, _, fetched_places) in ka_fetches {
            assert_eq!(
                fetched_places,
                &places,
                "Kleinanzeigen pagination uses those places"
            );
        }
        for (site, _, fetched_places) in fetches {
            if site == "eBay" || site == "Vinted" {
                assert!(
                    fetched_places.is_empty(),
                    "{site} pagination must not use places"
                );
            }
        }
        assert!(
            fetches
                .iter()
                .any(|(site, page, _)| site == "eBay" && *page == 2),
            "eBay must continue past page 1"
        );
    }

    struct StoreAwarePageSource {
        inner: FakePageSource,
        store: MemoryStore,
        urls_in_store_before_fetch: Vec<Vec<String>>,
        fail_site: Option<String>,
    }

    impl PageSource for StoreAwarePageSource {
        fn fetch_page(
            &mut self,
            request: &ScanRequest,
            page: u32,
        ) -> Result<SearchPage, String> {
            self.urls_in_store_before_fetch.push(
                self.store
                    .listings()
                    .iter()
                    .map(|listing| listing.url.clone())
                    .collect(),
            );
            if self.fail_site.as_deref() == Some(request.site.as_str()) {
                return Err(format!("{} fetch failed", request.site));
            }
            self.inner.fetch_page(request, page)
        }

        fn fetch_listing_page(&mut self, url: &str) -> Result<ListingPage, String> {
            self.inner.fetch_listing_page(url)
        }
    }

    #[test]
    fn listings_are_stored_immediately_and_remain_if_later_site_fails() {
        let mut inner = FakePageSource::default();
        inner.add(
            "Kleinanzeigen",
            1,
            false,
            &["https://ka.example/1", "https://ka.example/2"],
        );
        inner.add("Kleinanzeigen", 2, true, &["https://ka.example/3"]);
        inner.add("eBay", 1, true, &["https://eb.example/1"]);

        let store = MemoryStore::default();
        let source = StoreAwarePageSource {
            inner,
            store: store.clone(),
            urls_in_store_before_fetch: Vec::new(),
            fail_site: Some("eBay".to_string()),
        };
        let mut scanner = PaginatingScanner {
            source,
            store: store.clone(),
        };

        let err = run("Fahrrad", &[], &mut scanner).unwrap_err();
        assert!(
            err.contains("eBay"),
            "run should surface the later site failure: {err}"
        );

        let before = &scanner.source.urls_in_store_before_fetch;
        assert_eq!(
            before[0],
            [] as [String; 0],
            "store starts empty before the first fetch"
        );
        assert_eq!(
            before[1],
            ["https://ka.example/1", "https://ka.example/2"],
            "page 1 listings must already be in the store before the next fetch"
        );
        assert_eq!(
            before[2],
            [
                "https://ka.example/1",
                "https://ka.example/2",
                "https://ka.example/3"
            ],
            "all Kleinanzeigen listings must be in the store before eBay is fetched"
        );

        let readable: Vec<String> = store
            .listings()
            .into_iter()
            .map(|listing| listing.url)
            .collect();
        assert_eq!(
            readable,
            [
                "https://ka.example/1",
                "https://ka.example/2",
                "https://ka.example/3"
            ],
            "Kleinanzeigen listings from this run remain readable after eBay fails"
        );
        assert!(
            store
                .listings()
                .iter()
                .all(|listing| listing.site == "Kleinanzeigen"),
            "failed eBay must not leave listings"
        );
    }

    #[test]
    fn earlier_sites_remain_readable_if_vinted_fails() {
        let mut inner = FakePageSource::default();
        inner.add("Kleinanzeigen", 1, true, &["https://ka.example/1"]);
        inner.add("eBay", 1, true, &["https://eb.example/1"]);
        inner.add("Vinted", 1, true, &["https://vi.example/1"]);

        let store = MemoryStore::default();
        let source = StoreAwarePageSource {
            inner,
            store: store.clone(),
            urls_in_store_before_fetch: Vec::new(),
            fail_site: Some("Vinted".to_string()),
        };
        let mut scanner = PaginatingScanner {
            source,
            store: store.clone(),
        };

        assert!(run("Fahrrad", &[], &mut scanner).is_err());

        let readable: Vec<(String, String)> = store
            .listings()
            .into_iter()
            .map(|listing| (listing.site, listing.url))
            .collect();
        assert_eq!(
            readable,
            [
                (
                    "Kleinanzeigen".to_string(),
                    "https://ka.example/1".to_string()
                ),
                ("eBay".to_string(), "https://eb.example/1".to_string())
            ],
            "Kleinanzeigen and eBay listings remain readable after Vinted fails"
        );
    }

    #[test]
    fn site_fetch_failure_is_stored_with_site_term_and_run() {
        let mut inner = FakePageSource::default();
        inner.add("Kleinanzeigen", 1, true, &["https://ka.example/1"]);
        inner.add("eBay", 1, true, &["https://eb.example/1"]);

        let store = MemoryStore::default();
        let source = StoreAwarePageSource {
            inner,
            store: store.clone(),
            urls_in_store_before_fetch: Vec::new(),
            fail_site: Some("eBay".to_string()),
        };
        let mut scanner = PaginatingScanner {
            source,
            store: store.clone(),
        };

        let err = run("Fahrrad", &[], &mut scanner).unwrap_err();
        assert!(err.contains("eBay"), "run should surface the site failure: {err}");

        let failures = store.failures();
        assert_eq!(failures.len(), 1, "exactly one failure record for the failed site");
        assert_eq!(failures[0].site, "eBay");
        assert_eq!(failures[0].term, "Fahrrad");
        assert!(
            !failures[0].run_id.is_empty(),
            "failure record must identify the run"
        );
    }

    #[test]
    fn stored_finding_has_title_price_url_site_term_dates_and_listing_page_image() {
        let mut source = FakePageSource::default();
        source.add("Kleinanzeigen", 1, true, &["https://ka.example/listing-1"]);
        source.add("eBay", 1, true, &["https://eb.example/listing-1"]);
        source.add("Vinted", 1, true, &["https://vi.example/listing-1"]);
        source.set_listing_page(
            "https://ka.example/listing-1",
            ListingPage {
                title: "City bike".to_string(),
                price: "120 €".to_string(),
                product_images: vec![
                    "https://ka.example/listing-1/img-1.jpg".to_string(),
                    "https://ka.example/listing-1/img-2.jpg".to_string(),
                ],
            },
        );
        source.set_listing_page(
            "https://eb.example/listing-1",
            ListingPage {
                title: "Road bike".to_string(),
                price: "200 €".to_string(),
                product_images: vec!["https://eb.example/listing-1/photo.jpg".to_string()],
            },
        );
        source.set_listing_page(
            "https://vi.example/listing-1",
            ListingPage {
                title: "Kids bike".to_string(),
                price: "40 €".to_string(),
                product_images: vec!["https://vi.example/listing-1/cover.jpg".to_string()],
            },
        );

        let mut scanner = PaginatingScanner::new(source);
        run("Fahrrad", &[], &mut scanner).unwrap();

        let findings = scanner.store.listings();
        assert_eq!(findings.len(), 3);

        let ka = findings
            .iter()
            .find(|f| f.url == "https://ka.example/listing-1")
            .expect("Kleinanzeigen finding");
        assert_eq!(ka.title, "City bike");
        assert_eq!(ka.price, "120 €");
        assert_eq!(ka.site, "Kleinanzeigen");
        assert_eq!(ka.search_term, "Fahrrad");
        assert_eq!(ka.first_seen, today_date());
        assert_eq!(ka.last_seen, ka.first_seen);
        assert_eq!(
            ka.product_images[0],
            "https://ka.example/listing-1/img-1.jpg",
            "first product image must come from the listing page"
        );

        for finding in &findings {
            assert!(!finding.title.is_empty(), "title required");
            assert!(!finding.price.is_empty(), "price required");
            assert!(!finding.url.is_empty(), "URL required");
            assert!(!finding.site.is_empty(), "site required");
            assert_eq!(finding.search_term, "Fahrrad");
            assert!(
                finding.first_seen.len() == 10 && finding.first_seen.chars().nth(4) == Some('-'),
                "first-seen must be a date: {}",
                finding.first_seen
            );
            assert_eq!(finding.last_seen, finding.first_seen);
            assert!(
                !finding.product_images.is_empty(),
                "at least the first product image from the listing page"
            );
        }
    }

    #[test]
    fn two_fetches_same_listing_url_produce_one_row_even_when_terms_differ() {
        let mut source = FakePageSource::default();
        source.add("Kleinanzeigen", 1, true, &["https://example.com/shared"]);
        source.add("eBay", 1, true, &[]);
        source.add("Vinted", 1, true, &[]);

        let store = MemoryStore::default();
        let mut scanner = PaginatingScanner {
            source,
            store: store.clone(),
        };

        run("Fahrrad", &[], &mut scanner).unwrap();
        run("Lampe", &[], &mut scanner).unwrap();

        let listings = store.listings();
        assert_eq!(
            listings.len(),
            1,
            "the same listing URL must be one stored row"
        );
        assert_eq!(listings[0].url, "https://example.com/shared");
        let matching: Vec<&Listing> = listings
            .iter()
            .filter(|listing| listing.url == "https://example.com/shared")
            .collect();
        assert_eq!(matching.len(), 1);
    }

    #[test]
    fn recheck_of_term_drops_missing_urls_and_updates_last_seen() {
        let mut source = FakePageSource::default();
        source.add(
            "Kleinanzeigen",
            1,
            true,
            &["https://ka.example/keep", "https://ka.example/drop"],
        );
        source.add("eBay", 1, true, &[]);
        source.add("Vinted", 1, true, &[]);

        let store = MemoryStore::default();
        let mut scanner = PaginatingScanner {
            source,
            store: store.clone(),
        };

        run("Fahrrad", &[], &mut scanner).unwrap();

        store.save(Listing {
            title: "other".to_string(),
            price: "9".to_string(),
            url: "https://ka.example/other-term".to_string(),
            site: "Kleinanzeigen".to_string(),
            search_term: "Lampe".to_string(),
            first_seen: "2019-06-01".to_string(),
            last_seen: "2019-06-01".to_string(),
            product_images: vec!["https://ka.example/other-term/photo.jpg".to_string()],
        });

        let kept_first_seen = store
            .listings()
            .into_iter()
            .find(|listing| listing.url == "https://ka.example/keep")
            .expect("keep url from first fetch")
            .first_seen;
        store.save(Listing {
            title: "kept bike".to_string(),
            price: "10".to_string(),
            url: "https://ka.example/keep".to_string(),
            site: "Kleinanzeigen".to_string(),
            search_term: "Fahrrad".to_string(),
            first_seen: kept_first_seen.clone(),
            last_seen: "2020-01-01".to_string(),
            product_images: vec!["https://ka.example/keep/photo.jpg".to_string()],
        });

        scanner.source.pages.clear();
        scanner.source.add("Kleinanzeigen", 1, true, &["https://ka.example/keep"]);
        scanner.source.add("eBay", 1, true, &[]);
        scanner.source.add("Vinted", 1, true, &[]);

        run("Fahrrad", &[], &mut scanner).unwrap();

        let listings = store.listings();
        let urls: Vec<&str> = listings.iter().map(|listing| listing.url.as_str()).collect();
        assert!(
            !urls.contains(&"https://ka.example/drop"),
            "recheck must remove findings for the term whose URLs are not in the new fetch"
        );
        assert!(
            urls.contains(&"https://ka.example/keep"),
            "URLs still found must stay"
        );
        assert!(
            urls.contains(&"https://ka.example/other-term"),
            "findings for other terms must stay"
        );

        let kept = listings
            .iter()
            .find(|listing| listing.url == "https://ka.example/keep")
            .expect("kept listing");
        assert_eq!(kept.search_term, "Fahrrad");
        assert_eq!(kept.first_seen, kept_first_seen, "first-seen stays on recheck");
        assert_eq!(
            kept.last_seen,
            today_date(),
            "last-seen must update for URLs still found"
        );
        assert_ne!(kept.last_seen, "2020-01-01");
    }

    fn listing_with_dates(url: &str, first_seen: &str, last_seen: &str) -> Listing {
        Listing {
            title: url.to_string(),
            price: "1".to_string(),
            url: url.to_string(),
            site: "Kleinanzeigen".to_string(),
            search_term: "Fahrrad".to_string(),
            first_seen: first_seen.to_string(),
            last_seen: last_seen.to_string(),
            product_images: vec![format!("{url}/photo.jpg")],
        }
    }

    #[test]
    fn chosen_date_range_does_not_keep_findings_outside_range() {
        let store = MemoryStore::default();
        store.save(listing_with_dates(
            "https://example.com/in",
            "2024-06-01",
            "2024-06-10",
        ));
        store.save(listing_with_dates(
            "https://example.com/before",
            "2023-12-31",
            "2023-12-31",
        ));
        store.save(listing_with_dates(
            "https://example.com/after",
            "2025-01-01",
            "2025-01-01",
        ));

        store.set_date_range(DateRange {
            start: "2024-01-01".to_string(),
            end: "2024-12-31".to_string(),
        });

        let urls: Vec<String> = store.listings().into_iter().map(|listing| listing.url).collect();
        assert_eq!(
            urls,
            ["https://example.com/in"],
            "findings whose dates fall outside the chosen range must not be kept"
        );

        store.save(listing_with_dates(
            "https://example.com/also-outside",
            "2022-01-01",
            "2022-01-02",
        ));
        let urls: Vec<String> = store.listings().into_iter().map(|listing| listing.url).collect();
        assert_eq!(
            urls,
            ["https://example.com/in"],
            "a later save outside the range must not be kept"
        );

        let mut source = FakePageSource::default();
        source.add("Kleinanzeigen", 1, true, &["https://ka.example/today"]);
        source.add("eBay", 1, true, &[]);
        source.add("Vinted", 1, true, &[]);
        let fetch_store = MemoryStore::default();
        fetch_store.set_date_range(DateRange {
            start: "2000-01-01".to_string(),
            end: "2000-01-02".to_string(),
        });
        let mut scanner = PaginatingScanner {
            source,
            store: fetch_store.clone(),
        };
        run("Fahrrad", &[], &mut scanner).unwrap();
        assert!(
            fetch_store.listings().is_empty(),
            "a fetch whose dates fall outside the chosen range must not be kept"
        );
    }

    #[test]
    fn listings_are_sorted_by_price() {
        let listings = vec![
            listing_with_dates("https://example.com/mid", "2024-01-01", "2024-01-01"),
            listing_with_dates("https://example.com/high", "2024-01-01", "2024-01-01"),
            listing_with_dates("https://example.com/low", "2024-01-01", "2024-01-01"),
        ];
        let mut listings = listings;
        listings[0].price = "120 €".to_string();
        listings[1].price = "200 €".to_string();
        listings[2].price = "40 €".to_string();

        let sorted = listings_sorted_by_price(&listings);
        let urls: Vec<&str> = sorted.iter().map(|listing| listing.url.as_str()).collect();
        assert_eq!(
            urls,
            [
                "https://example.com/low",
                "https://example.com/mid",
                "https://example.com/high"
            ]
        );
        assert_eq!(sorted[0].price, "40 €");
        assert_eq!(sorted[1].price, "120 €");
        assert_eq!(sorted[2].price, "200 €");
    }
}
