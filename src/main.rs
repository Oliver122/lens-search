use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::PathBuf;

use lens_search::{
    encode_failure_line, parse_failure_line, parse_run_args, run, scan_requests, FetchFailure,
    PageSource, PaginatingScanner, ScanRequest, SearchPage, SiteScanner,
};

struct CliPageSource {
    fail_site: Option<String>,
}

impl PageSource for CliPageSource {
    fn fetch_page(
        &mut self,
        request: &ScanRequest,
        _page: u32,
    ) -> Result<SearchPage, String> {
        if self.fail_site.as_deref() == Some(request.site.as_str()) {
            return Err(format!("{} fetch failed", request.site));
        }
        Ok(SearchPage {
            listings: Vec::new(),
            is_last: true,
        })
    }
}

fn store_path() -> PathBuf {
    std::env::var_os("LENS_SEARCH_STORE")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("lens-search-failures"))
}

fn persist_failures(failures: &[FetchFailure]) -> Result<(), String> {
    if failures.is_empty() {
        return Ok(());
    }
    let path = store_path();
    if let Some(parent) = path.parent() {
        if !parent.as_os_str().is_empty() {
            fs::create_dir_all(parent).map_err(|err| err.to_string())?;
        }
    }
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
        .map_err(|err| err.to_string())?;
    for failure in failures {
        writeln!(file, "{}", encode_failure_line(failure)).map_err(|err| err.to_string())?;
    }
    Ok(())
}

fn load_failures() -> Result<Vec<FetchFailure>, String> {
    let path = store_path();
    let text = match fs::read_to_string(&path) {
        Ok(text) => text,
        Err(err) if err.kind() == std::io::ErrorKind::NotFound => return Ok(Vec::new()),
        Err(err) => return Err(err.to_string()),
    };
    Ok(text.lines().filter_map(parse_failure_line).collect())
}

fn print_failures() {
    match load_failures() {
        Ok(failures) => {
            for failure in failures {
                println!("{} {} {}", failure.site, failure.term, failure.run_id);
            }
        }
        Err(err) => {
            eprintln!("{err}");
            std::process::exit(1);
        }
    }
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.first().map(String::as_str) == Some("failures") {
        print_failures();
        return;
    }

    let parsed = match parse_run_args(&args) {
        Ok(parsed) => parsed,
        Err(err) => {
            eprintln!("{err}");
            eprintln!("usage: lens-search run <search-term> [--places PLACE ...]");
            std::process::exit(1);
        }
    };

    let fail_site = std::env::var("LENS_SEARCH_FAIL_SITE").ok().filter(|s| !s.is_empty());
    let mut scanner = PaginatingScanner::new(CliPageSource { fail_site });
    let run_result = run(&parsed.term, &parsed.places, &mut scanner);
    if let Err(err) = persist_failures(&scanner.fetch_failures()) {
        eprintln!("{err}");
        std::process::exit(1);
    }

    if let Err(err) = run_result {
        eprintln!("{err}");
        std::process::exit(1);
    }

    for call in scan_requests(&parsed.term, &parsed.places) {
        if call.places.is_empty() {
            println!("{} {}", call.site, call.url);
        } else {
            println!("{} {} {}", call.site, call.url, call.places.join(" "));
        }
    }
}
