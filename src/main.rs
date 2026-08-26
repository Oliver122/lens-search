use lens_search::{parse_run_args, run, RecordingScanner};

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let parsed = match parse_run_args(&args) {
        Ok(parsed) => parsed,
        Err(err) => {
            eprintln!("{err}");
            eprintln!("usage: lens-search run <search-term> [--places PLACE ...]");
            std::process::exit(1);
        }
    };

    let mut scanner = RecordingScanner::default();
    if let Err(err) = run(&parsed.term, &parsed.places, &mut scanner) {
        eprintln!("{err}");
        std::process::exit(1);
    }

    for call in scanner.calls {
        if call.places.is_empty() {
            println!("{} {}", call.site, call.url);
        } else {
            println!("{} {} {}", call.site, call.url, call.places.join(" "));
        }
    }
}
