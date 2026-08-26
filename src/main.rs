use lens_search::{parse_run_term, run, RecordingScanner};

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let term = match parse_run_term(&args) {
        Ok(term) => term,
        Err(err) => {
            eprintln!("{err}");
            eprintln!("usage: lens-search run <search-term>");
            std::process::exit(1);
        }
    };

    let mut scanner = RecordingScanner::default();
    if let Err(err) = run(&term, &mut scanner) {
        eprintln!("{err}");
        std::process::exit(1);
    }

    for call in scanner.calls {
        println!("{} {}", call.site, call.url);
    }
}
