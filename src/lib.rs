//! Terminal run: one search term, then public scans in site order.

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

pub trait SiteScanner {
    fn scan(&mut self, request: &ScanRequest) -> Result<(), String>;
}

/// Scan Kleinanzeigen, then eBay, then Vinted. Public search only (no login).
pub fn run(term: &str, places: &[String], scanner: &mut impl SiteScanner) -> Result<(), String> {
    if term.is_empty() {
        return Err(RunError::EmptyTerm.to_string());
    }
    for request in scan_requests(term, places) {
        if request.requires_login() {
            return Err(format!("{} scan must not require login", request.site));
        }
        scanner.scan(&request)?;
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
}
