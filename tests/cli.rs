use std::process::Command;

fn bin() -> Command {
    Command::new(env!("CARGO_BIN_EXE_lens-search"))
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
