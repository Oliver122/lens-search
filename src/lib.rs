//! Terminal run: one search term, then public scans in site order.

pub const SITES_IN_ORDER: [&str; 3] = ["Kleinanzeigen", "eBay", "Vinted"];

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ScanRequest {
    pub site: String,
    pub term: String,
    pub url: String,
    /// Empty for public search. Login cookies or Authorization must not appear.
    pub headers: Vec<(String, String)>,
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
}

impl std::fmt::Display for RunError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            RunError::MissingTerm => write!(f, "a run needs exactly one search term"),
            RunError::ExtraTerms => write!(f, "a run accepts exactly one search term"),
            RunError::EmptyTerm => write!(f, "search term must not be empty"),
        }
    }
}

impl std::error::Error for RunError {}

/// Parse `run <term>` from argv after the program name.
pub fn parse_run_term(args: &[String]) -> Result<String, RunError> {
    let mut rest = args.iter();
    match rest.next().map(String::as_str) {
        Some("run") => {}
        None | Some(_) => return Err(RunError::MissingTerm),
    }
    let term = rest.next().cloned().ok_or(RunError::MissingTerm)?;
    if rest.next().is_some() {
        return Err(RunError::ExtraTerms);
    }
    if term.is_empty() {
        return Err(RunError::EmptyTerm);
    }
    Ok(term)
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

pub fn scan_requests(term: &str) -> Vec<ScanRequest> {
    SITES_IN_ORDER
        .iter()
        .map(|site| ScanRequest {
            site: (*site).to_string(),
            term: term.to_string(),
            url: public_search_url(site, term),
            headers: Vec::new(),
        })
        .collect()
}

pub trait SiteScanner {
    fn scan(&mut self, request: &ScanRequest) -> Result<(), String>;
}

/// Scan Kleinanzeigen, then eBay, then Vinted. Public search only (no login).
pub fn run(term: &str, scanner: &mut impl SiteScanner) -> Result<(), String> {
    if term.is_empty() {
        return Err(RunError::EmptyTerm.to_string());
    }
    for request in scan_requests(term) {
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
        assert_eq!(parse_run_term(&args(&["run", "Fahrrad"])).unwrap(), "Fahrrad");
        assert_eq!(parse_run_term(&args(&["run"])), Err(RunError::MissingTerm));
        assert_eq!(
            parse_run_term(&args(&["run", "a", "b"])),
            Err(RunError::ExtraTerms)
        );
    }

    #[test]
    fn run_scans_kleinanzeigen_then_ebay_then_vinted_without_login() {
        let mut scanner = RecordingScanner::default();
        run("Fahrrad", &mut scanner).unwrap();

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
}
