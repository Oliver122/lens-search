use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

fn bin() -> Command {
    Command::new(env!("CARGO_BIN_EXE_lens-search"))
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
    let output = bin()
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
    let output = bin()
        .args(["run", "Fahrrad", "Lampe"])
        .output()
        .expect("run binary");
    assert!(!output.status.success());
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(stderr.contains("exactly one search term"));
}

#[test]
fn terminal_run_rejects_missing_term() {
    let output = bin().args(["run"]).output().expect("run binary");
    assert!(!output.status.success());
}

#[test]
fn terminal_run_accepts_places_only_for_kleinanzeigen() {
    let output = bin()
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

    let run_output = bin()
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
