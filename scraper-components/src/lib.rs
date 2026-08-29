//! Shared scrape contract. Callers pick a [`Scraper`] variant; each site is a
//! separate implementation under this crate.

mod ebay;
mod kleinanzeigen;
mod listing;
mod vinted;

pub use listing::Listing;

/// Site scraper selected by callers. Each variant uses the same interface:
/// a search term in, listings out to the backend.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Scraper {
    Ebay,
    Kleinanzeigen,
    Vinted,
}

impl Scraper {
    /// Run this site’s scraper. Implementations live in separate modules.
    pub fn scrape(&self, search_term: &str) -> Vec<Listing> {
        match self {
            Scraper::Ebay => ebay::scrape(search_term),
            Scraper::Kleinanzeigen => kleinanzeigen::scrape(search_term),
            Scraper::Vinted => vinted::scrape(search_term),
        }
    }
}

#[cfg(test)]
mod specified_test_1 {
    use super::Scraper;
    use std::mem::discriminant;
    use std::path::Path;

    #[test]
    fn scraper_enum_has_ebay_kleinanzeigen_and_vinted() {
        let variants = [Scraper::Ebay, Scraper::Kleinanzeigen, Scraper::Vinted];
        assert_eq!(variants.len(), 3);
        assert_ne!(discriminant(&variants[0]), discriminant(&variants[1]));
        assert_ne!(discriminant(&variants[1]), discriminant(&variants[2]));
        assert_ne!(discriminant(&variants[0]), discriminant(&variants[2]));
    }

    #[test]
    fn all_variants_share_search_term_in_listings_out_interface() {
        let term = "interface-check";
        for scraper in [Scraper::Ebay, Scraper::Kleinanzeigen, Scraper::Vinted] {
            let listings: Vec<crate::Listing> = scraper.scrape(term);
            let _ = listings;
        }
    }

    #[test]
    fn implementations_are_separate_modules_under_scraper_components() {
        let crate_root = Path::new(env!("CARGO_MANIFEST_DIR"));
        assert!(crate_root.ends_with("scraper-components"));
        for name in ["ebay.rs", "kleinanzeigen.rs", "vinted.rs"] {
            let path = crate_root.join("src").join(name);
            assert!(path.is_file(), "missing separate implementation {path:?}");
        }
        assert_eq!(crate::ebay::SITE, "ebay");
        assert_eq!(crate::kleinanzeigen::SITE, "kleinanzeigen");
        assert_eq!(crate::vinted::SITE, "vinted");
    }
}
