//! Public HTTP fetch for Kleinanzeigen, eBay, and Vinted search pages.

use std::time::Duration;

use crate::{urlencode, Listing, ListingPage, PageSource, ScanRequest, SearchPage};

const USER_AGENT: &str = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

pub struct LivePageSource {
    agent: ureq::Agent,
    max_pages: Option<u32>,
    max_listings: Option<usize>,
}

impl LivePageSource {
    pub fn new() -> Self {
        Self::with_limits(None, None)
    }

    pub fn with_limits(max_pages: Option<u32>, max_listings: Option<usize>) -> Self {
        let agent = ureq::AgentBuilder::new()
            .timeout(Duration::from_secs(25))
            .user_agent(USER_AGENT)
            .build();
        Self {
            agent,
            max_pages,
            max_listings,
        }
    }

    fn get(&self, url: &str) -> Result<String, String> {
        let response = self
            .agent
            .get(url)
            .set("Accept", "text/html,application/xhtml+xml")
            .set("Accept-Language", "de-DE,de;q=0.9,en;q=0.8")
            .call()
            .map_err(|err| format!("GET {url}: {err}"))?;
        let status = response.status();
        if !(200..300).contains(&status) {
            return Err(format!("GET {url}: HTTP {status}"));
        }
        response
            .into_string()
            .map_err(|err| format!("GET {url}: {err}"))
    }
}

impl Default for LivePageSource {
    fn default() -> Self {
        Self::new()
    }
}

impl PageSource for LivePageSource {
    fn fetch_page(&mut self, request: &ScanRequest, page: u32) -> Result<SearchPage, String> {
        if let Some(max) = self.max_pages {
            if page > max {
                return Ok(SearchPage {
                    listings: Vec::new(),
                    is_last: true,
                });
            }
        }
        let (html, is_last) = match request.site.as_str() {
            "Kleinanzeigen" => fetch_kleinanzeigen_page(self, request, page)?,
            "eBay" => fetch_ebay_page(self, request, page)?,
            "Vinted" => fetch_vinted_page(self, request, page)?,
            other => return Err(format!("unknown site {other}")),
        };
        let mut listings = parse_search_listings(&request.site, &html);
        if let Some(max) = self.max_listings {
            listings.truncate(max);
        }
        let is_last = is_last || self.max_pages == Some(page) || listings.is_empty();
        Ok(SearchPage { listings, is_last })
    }

    fn fetch_listing_page(&mut self, url: &str) -> Result<ListingPage, String> {
        let html = self.get(url)?;
        parse_listing_page(url, &html)
    }
}

fn fetch_kleinanzeigen_page(
    source: &LivePageSource,
    request: &ScanRequest,
    page: u32,
) -> Result<(String, bool), String> {
    if request.places.is_empty() {
        let url = kleinanzeigen_url(&request.term, None, page);
        let html = source.get(&url)?;
        let next = kleinanzeigen_url(&request.term, None, page + 1);
        let is_last = !html.contains(&format!("seite:{}", page + 1)) && !html.contains(&next);
        Ok((html, is_last))
    } else {
        let mut combined = String::new();
        let mut all_last = true;
        for place in &request.places {
            let url = kleinanzeigen_url(&request.term, Some(place), page);
            let html = source.get(&url)?;
            let has_next = html.contains(&format!("seite:{}", page + 1));
            if has_next {
                all_last = false;
            }
            combined.push_str(&html);
        }
        Ok((combined, all_last))
    }
}

fn kleinanzeigen_url(term: &str, place: Option<&str>, page: u32) -> String {
    let q = urlencode(term);
    match (place, page) {
        (None, 1) => format!("https://www.kleinanzeigen.de/s-{q}/k0"),
        (None, n) => format!("https://www.kleinanzeigen.de/s-seite:{n}/{q}/k0"),
        (Some(place), 1) => {
            format!("https://www.kleinanzeigen.de/s-{}/{q}/k0", place_slug(place))
        }
        (Some(place), n) => format!(
            "https://www.kleinanzeigen.de/s-{}/seite:{n}/{q}/k0",
            place_slug(place)
        ),
    }
}

fn place_slug(place: &str) -> String {
    place.trim().to_lowercase().replace(' ', "-")
}

fn fetch_ebay_page(
    source: &LivePageSource,
    request: &ScanRequest,
    page: u32,
) -> Result<(String, bool), String> {
    let q = urlencode(&request.term);
    let url = if page <= 1 {
        format!("https://www.ebay.de/sch/i.html?_nkw={q}")
    } else {
        format!("https://www.ebay.de/sch/i.html?_nkw={q}&_pgn={page}")
    };
    let html = source.get(&url)?;
    let next = format!("_pgn={}", page + 1);
    let is_last = !html.contains(&next);
    Ok((html, is_last))
}

fn fetch_vinted_page(
    source: &LivePageSource,
    request: &ScanRequest,
    page: u32,
) -> Result<(String, bool), String> {
    let q = urlencode(&request.term);
    let url = if page <= 1 {
        format!("https://www.vinted.de/catalog?search_text={q}")
    } else {
        format!("https://www.vinted.de/catalog?search_text={q}&page={page}")
    };
    let html = source.get(&url)?;
    let next = format!("page={}", page + 1);
    let is_last = !html.contains(&next);
    Ok((html, is_last))
}

fn parse_search_listings(site: &str, html: &str) -> Vec<Listing> {
    let hrefs = match site {
        "Kleinanzeigen" => collect_hrefs(html, "/s-anzeige/"),
        "eBay" => collect_ebay_hrefs(html),
        "Vinted" => collect_hrefs(html, "/items/"),
        _ => Vec::new(),
    };
    let mut listings = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for href in hrefs {
        let url = absolute_url(site, &href);
        if !is_real_listing_url(site, &url) {
            continue;
        }
        if !seen.insert(url.clone()) {
            continue;
        }
        listings.push(Listing {
            title: String::new(),
            price: String::new(),
            url,
            site: site.to_string(),
            search_term: String::new(),
            first_seen: String::new(),
            last_seen: String::new(),
            product_images: Vec::new(),
        });
    }
    listings
}

fn collect_hrefs(html: &str, prefix: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut rest = html;
    let needle = format!("href=\"");
    while let Some(idx) = rest.find(&needle) {
        rest = &rest[idx + needle.len()..];
        let Some(end) = rest.find('"') else { break };
        let href = decode_html(&rest[..end]);
        rest = &rest[end + 1..];
        if href.contains(prefix) {
            out.push(href);
        }
    }
    out
}

fn collect_ebay_hrefs(html: &str) -> Vec<String> {
    let mut hrefs = collect_hrefs(html, "/itm/");
    hrefs.extend(collect_hrefs(html, "ebay.de/itm/"));
    hrefs.extend(collect_hrefs(html, "ebay.com/itm/"));
    hrefs
}

fn absolute_url(site: &str, href: &str) -> String {
    let href = href.split('?').next().unwrap_or(href);
    if href.starts_with("http://") || href.starts_with("https://") {
        return href.to_string();
    }
    let host = match site {
        "Kleinanzeigen" => "https://www.kleinanzeigen.de",
        "eBay" => "https://www.ebay.de",
        "Vinted" => "https://www.vinted.de",
        _ => "",
    };
    if href.starts_with('/') {
        format!("{host}{href}")
    } else {
        format!("{host}/{href}")
    }
}

pub(crate) fn is_real_listing_url(site: &str, url: &str) -> bool {
    match site {
        "Kleinanzeigen" => {
            url.starts_with("https://www.kleinanzeigen.de/s-anzeige/")
                || url.starts_with("https://kleinanzeigen.de/s-anzeige/")
        }
        "eBay" => url.contains("ebay.") && url.contains("/itm/"),
        "Vinted" => {
            (url.starts_with("https://www.vinted.de/items/")
                || url.starts_with("https://www.vinted.com/items/"))
                && url.split('/').nth(4).is_some_and(|id| id.chars().next().is_some_and(|c| c.is_ascii_digit()))
        }
        _ => false,
    }
}

fn parse_listing_page(url: &str, html: &str) -> Result<ListingPage, String> {
    let title = meta_content(html, "og:title")
        .or_else(|| inner_text(html, "id=\"viewad-title\""))
        .or_else(|| title_tag(html))
        .map(|t| t.split(" | ").next().unwrap_or(&t).trim().to_string())
        .filter(|t| !t.is_empty())
        .ok_or_else(|| format!("listing page {url} has no title"))?;
    let price = inner_text(html, "id=\"viewad-price\"")
        .or_else(|| inner_text(html, "data-testid=\"item-price\""))
        .or_else(|| json_ld_price(html))
        .or_else(|| meta_content(html, "product:price:amount"))
        .or_else(|| meta_content(html, "og:price:amount"))
        .filter(|p| !p.is_empty())
        .ok_or_else(|| format!("listing page {url} has no price"))?;
    let image = meta_content(html, "og:image")
        .or_else(|| first_http_image(html))
        .ok_or_else(|| format!("listing page {url} has no product image"))?;
    Ok(ListingPage {
        title,
        price,
        product_images: vec![image],
    })
}

fn meta_content(html: &str, property: &str) -> Option<String> {
    for key in ["property", "name"] {
        let needle = format!("{key}=\"{property}\"");
        if let Some(idx) = html.find(&needle) {
            let window = &html[idx.saturating_sub(80)..(idx + 200).min(html.len())];
            if let Some(content) = attr_value(window, "content") {
                let decoded = decode_html(&content).trim().to_string();
                if !decoded.is_empty() {
                    return Some(decoded);
                }
            }
        }
    }
    None
}

fn attr_value(fragment: &str, name: &str) -> Option<String> {
    let needle = format!("{name}=\"");
    let idx = fragment.find(&needle)?;
    let rest = &fragment[idx + needle.len()..];
    let end = rest.find('"')?;
    Some(rest[..end].to_string())
}

fn inner_text(html: &str, marker: &str) -> Option<String> {
    let idx = html.find(marker)?;
    let after = &html[idx..];
    let gt = after.find('>')?;
    let rest = &after[gt + 1..];
    // skip nested tags to first text, or read inside the next <p>
    let text = if let Some(p) = rest.find("<p") {
        if p < 120 {
            let from = rest[p..].find('>')?;
            let inner = &rest[p + from + 1..];
            let end = inner.find('<')?;
            inner[..end].to_string()
        } else {
            let end = rest.find('<')?;
            rest[..end].to_string()
        }
    } else {
        let end = rest.find('<')?;
        rest[..end].to_string()
    };
    let decoded = decode_html(&text).trim().to_string();
    if decoded.is_empty() {
        None
    } else {
        Some(decoded)
    }
}

fn title_tag(html: &str) -> Option<String> {
    let start = html.find("<title>")? + 7;
    let end = html[start..].find("</title>")?;
    let decoded = decode_html(&html[start..start + end]).trim().to_string();
    if decoded.is_empty() {
        None
    } else {
        Some(decoded)
    }
}

fn json_ld_price(html: &str) -> Option<String> {
    let mut rest = html;
    while let Some(idx) = rest.find("\"price\"") {
        rest = &rest[idx + 7..];
        let colon = rest.find(':')?;
        rest = rest[colon + 1..].trim_start();
        if rest.starts_with('"') {
            let end = rest[1..].find('"')?;
            let value = rest[1..1 + end].to_string();
            if !value.is_empty() {
                return Some(value);
            }
        } else {
            let end = rest
                .find(|c: char| !(c.is_ascii_digit() || c == '.' || c == ','))
                .unwrap_or(rest.len());
            let value = rest[..end].trim().to_string();
            if !value.is_empty() {
                return Some(value);
            }
        }
    }
    None
}

fn first_http_image(html: &str) -> Option<String> {
    for prefix in ["https://img.kleinanzeigen.de/", "https://images1.vinted.net/", "https://i.ebayimg.com/"] {
        if let Some(idx) = html.find(prefix) {
            let rest = &html[idx..];
            let end = rest.find(|c: char| c == '"' || c == '\'' || c.is_whitespace()).unwrap_or(rest.len());
            return Some(decode_html(&rest[..end]));
        }
    }
    None
}

fn decode_html(s: &str) -> String {
    s.replace("&amp;", "&")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
        .replace("&nbsp;", " ")
        .replace('\u{00a0}', " ")
}
