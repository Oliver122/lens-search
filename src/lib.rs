//! Terminal run: one search term, then public scans in site order.

use std::cell::RefCell;
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

fn urlencode(s: &str) -> String {
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
    pub site: String,
    pub url: String,
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
}

/// In-memory listing store. Saves are visible immediately to other handles.
#[derive(Clone, Default)]
pub struct MemoryStore {
    listings: Rc<RefCell<Vec<Listing>>>,
    failures: Rc<RefCell<Vec<FetchFailure>>>,
}

impl MemoryStore {
    pub fn save(&self, listing: Listing) {
        self.listings.borrow_mut().push(listing);
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
        for listing in search_page.listings {
            store.save(listing);
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
}

pub trait SiteScanner {
    fn scan(&mut self, request: &ScanRequest) -> Result<(), String>;

    fn note_failure(&mut self, _failure: FetchFailure) {}

    fn fetch_failures(&self) -> Vec<FetchFailure> {
        Vec::new()
    }
}

/// Scan Kleinanzeigen, then eBay, then Vinted. Public search only (no login).
pub fn run(term: &str, places: &[String], scanner: &mut impl SiteScanner) -> Result<(), String> {
    if term.is_empty() {
        return Err(RunError::EmptyTerm.to_string());
    }
    let run_id = new_run_id();
    for request in scan_requests(term, places) {
        if request.requires_login() {
            return Err(format!("{} scan must not require login", request.site));
        }
        if let Err(err) = scanner.scan(&request) {
            scanner.note_failure(FetchFailure {
                site: request.site.clone(),
                term: request.term.clone(),
                run_id,
            });
            return Err(err);
        }
    }
    Ok(())
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
                            site: site.to_string(),
                            url: (*url).to_string(),
                        })
                        .collect(),
                    is_last,
                },
            );
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
}
