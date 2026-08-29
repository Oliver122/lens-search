use crate::listing::Listing;

pub(crate) const SITE: &str = "vinted";

pub(crate) fn scrape(_search_term: &str) -> Vec<Listing> {
    let _ = SITE;
    Vec::new()
}
