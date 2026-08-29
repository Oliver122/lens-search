use crate::listing::Listing;

pub(crate) const SITE: &str = "ebay";

pub(crate) fn scrape(_search_term: &str) -> Vec<Listing> {
    let _ = SITE;
    Vec::new()
}
