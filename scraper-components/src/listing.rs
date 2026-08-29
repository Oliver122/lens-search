use std::time::SystemTime;

/// Common listing fields delivered to the backend from every `Scraper` variant.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Listing {
    pub title: String,
    pub price: String,
    pub url: String,
    pub site: String,
    pub search_term: String,
    pub first_seen: SystemTime,
    pub last_seen: SystemTime,
    /// At least the first product image from the listing’s page.
    pub product_image_urls: Vec<String>,
}
