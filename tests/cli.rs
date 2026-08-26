use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

use lens_search::{
    encode_listing_line, parse_failure_line, parse_listing_line, FetchFailure, Listing,
};

fn bin() -> Command {
    Command::new(env!("CARGO_BIN_EXE_lens-search"))
}

fn stub_bin() -> Command {
    let mut cmd = bin();
    cmd.env("LENS_SEARCH_STUB", "1");
    cmd
}

fn unique_store() -> std::path::PathBuf {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    std::env::temp_dir().join(format!(
        "lens-search-failures-{}-{}",
        std::process::id(),
        nanos
    ))
}

#[test]
fn terminal_run_accepts_one_term_and_scans_sites_in_order() {
    let output = stub_bin()
        .args(["run", "Fahrrad"])
        .output()
        .expect("run binary");
    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    let stdout = String::from_utf8_lossy(&output.stdout);
    let lines: Vec<&str> = stdout.lines().collect();
    assert_eq!(lines.len(), 3);
    assert!(lines[0].starts_with("Kleinanzeigen "));
    assert!(lines[1].starts_with("eBay "));
    assert!(lines[2].starts_with("Vinted "));
    assert!(!stdout.to_lowercase().contains("login"));
}

#[test]
fn terminal_run_rejects_two_terms() {
    let output = stub_bin()
        .args(["run", "Fahrrad", "Lampe"])
        .output()
        .expect("run binary");
    assert!(!output.status.success());
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(stderr.contains("exactly one search term"));
}

#[test]
fn terminal_run_rejects_missing_term() {
    let output = stub_bin().args(["run"]).output().expect("run binary");
    assert!(!output.status.success());
}

#[test]
fn terminal_run_accepts_places_only_for_kleinanzeigen() {
    let output = stub_bin()
        .args(["run", "Fahrrad", "--places", "Karlsruhe", "Rheinfelden"])
        .output()
        .expect("run binary");
    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    let stdout = String::from_utf8_lossy(&output.stdout);
    let lines: Vec<&str> = stdout.lines().collect();
    assert_eq!(lines.len(), 3);
    assert!(lines[0].starts_with("Kleinanzeigen "));
    assert!(lines[0].contains("Karlsruhe"), "one Kleinanzeigen scan includes Karlsruhe");
    assert!(
        lines[0].contains("Rheinfelden"),
        "one Kleinanzeigen scan includes Rheinfelden"
    );
    assert!(lines[1].starts_with("eBay "));
    assert!(!lines[1].contains("Karlsruhe"));
    assert!(!lines[1].contains("Rheinfelden"));
    assert!(lines[2].starts_with("Vinted "));
    assert!(!lines[2].contains("Karlsruhe"));
    assert!(!lines[2].contains("Rheinfelden"));
}

#[test]
fn terminal_reads_stored_site_fetch_failure_after_run() {
    let store = unique_store();
    let _ = std::fs::remove_file(&store);

    let run_output = stub_bin()
        .args(["run", "Fahrrad"])
        .env("LENS_SEARCH_STORE", &store)
        .env("LENS_SEARCH_FAIL_SITE", "eBay")
        .output()
        .expect("run binary");
    assert!(
        !run_output.status.success(),
        "a failed site fetch should fail the run"
    );

    let failures = bin()
        .args(["failures"])
        .env("LENS_SEARCH_STORE", &store)
        .output()
        .expect("failures command");
    assert!(
        failures.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&failures.stderr)
    );
    let stdout = String::from_utf8_lossy(&failures.stdout);
    let line = stdout
        .lines()
        .next()
        .expect("terminal should print the stored failure");
    let parts: Vec<&str> = line.split_whitespace().collect();
    assert!(
        parts.len() >= 3,
        "failure line must include site, term, and run: {line}"
    );
    assert_eq!(parts[0], "eBay");
    assert_eq!(parts[1], "Fahrrad");
    assert!(!parts[2].is_empty(), "run id must be present");

    let _ = std::fs::remove_file(&store);
}

fn unique_findings() -> std::path::PathBuf {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    std::env::temp_dir().join(format!(
        "lens-search-findings-{}-{}",
        std::process::id(),
        nanos
    ))
}

fn stored_finding(title: &str, price: &str, url: &str) -> Listing {
    Listing {
        title: title.to_string(),
        price: price.to_string(),
        url: url.to_string(),
        site: "Kleinanzeigen".to_string(),
        search_term: "Fahrrad".to_string(),
        first_seen: "2024-06-01".to_string(),
        last_seen: "2024-06-01".to_string(),
        product_images: vec![format!("{url}/photo.jpg")],
    }
}

#[test]
fn terminal_lists_stored_findings_sorted_by_price() {
    let store = unique_findings();
    let _ = std::fs::remove_file(&store);

    let lines = [
        encode_listing_line(&stored_finding(
            "mid",
            "120 €",
            "https://example.com/mid",
        )),
        encode_listing_line(&stored_finding(
            "high",
            "200 €",
            "https://example.com/high",
        )),
        encode_listing_line(&stored_finding(
            "low",
            "40 €",
            "https://example.com/low",
        )),
    ];
    std::fs::write(&store, lines.join("\n") + "\n").expect("write findings");

    let output = bin()
        .args(["list"])
        .env("LENS_SEARCH_FINDINGS", &store)
        .output()
        .expect("list binary");
    assert!(
        output.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    let stdout = String::from_utf8_lossy(&output.stdout);
    let printed: Vec<&str> = stdout.lines().collect();
    assert_eq!(printed.len(), 3, "stdout: {stdout}");
    assert!(
        printed[0].contains("https://example.com/low"),
        "cheapest first: {}",
        printed[0]
    );
    assert!(
        printed[1].contains("https://example.com/mid"),
        "middle price second: {}",
        printed[1]
    );
    assert!(
        printed[2].contains("https://example.com/high"),
        "highest last: {}",
        printed[2]
    );
    let low_at = stdout.find("https://example.com/low").expect("low url");
    let mid_at = stdout.find("https://example.com/mid").expect("mid url");
    let high_at = stdout.find("https://example.com/high").expect("high url");
    assert!(low_at < mid_at && mid_at < high_at, "must be sorted by price");

    let _ = std::fs::remove_file(&store);
}

fn is_real_marketplace_url(url: &str) -> bool {
    let host_ok = url.contains("kleinanzeigen.de")
        || url.contains("ebay.")
        || url.contains("vinted.");
    host_ok
        && !url.contains("example.com")
        && (url.contains("/s-anzeige/") || url.contains("/itm/") || url.contains("/items/"))
}

#[test]
fn live_run_persists_real_listings_or_stored_failures() {
    let failures_path = unique_store();
    let findings_path = unique_findings();
    let _ = std::fs::remove_file(&failures_path);
    let _ = std::fs::remove_file(&findings_path);

    let output = bin()
        .args(["run", "Fahrrad", "--places", "Karlsruhe", "Rheinfelden"])
        .env("LENS_SEARCH_STORE", &failures_path)
        .env("LENS_SEARCH_FINDINGS", &findings_path)
        .env("LENS_SEARCH_MAX_PAGES", "1")
        .env("LENS_SEARCH_MAX_LISTINGS", "1")
        .output()
        .expect("live run");

    let findings_text = std::fs::read_to_string(&findings_path).unwrap_or_default();
    let failures_text = std::fs::read_to_string(&failures_path).unwrap_or_default();
    let listings: Vec<Listing> = findings_text
        .lines()
        .filter_map(parse_listing_line)
        .collect();
    let failures: Vec<FetchFailure> = failures_text
        .lines()
        .filter_map(parse_failure_line)
        .collect();

    for listing in &listings {
        assert!(
            is_real_marketplace_url(&listing.url),
            "must persist a real listing URL, not a locally invented row: {}",
            listing.url
        );
        assert!(
            !listing.title.starts_with("title for "),
            "must not persist locally invented titles: {}",
            listing.title
        );
    }

    for site in ["Kleinanzeigen", "eBay", "Vinted"] {
        let has_listing = listings
            .iter()
            .any(|listing| listing.site == site && is_real_marketplace_url(&listing.url));
        let has_failure = failures
            .iter()
            .any(|failure| failure.site == site && failure.term == "Fahrrad");
        assert!(
            has_listing || has_failure,
            "{site} must persist a real listing or a stored fetch failure; listings={:?} failures={:?} status={:?} stderr={}",
            listings
                .iter()
                .map(|listing| (listing.site.as_str(), listing.url.as_str()))
                .collect::<Vec<_>>(),
            failures,
            output.status,
            String::from_utf8_lossy(&output.stderr)
        );
    }

    let _ = std::fs::remove_file(&failures_path);
    let _ = std::fs::remove_file(&findings_path);
}
