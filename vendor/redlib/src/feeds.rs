//! Named MAIN FEEDS: instance defaults + cookie-backed user feeds.
//!
//! Encoding:
//! - Instance / urlencoded: `name:sub+sub;name2:sub+sub` (`;` between feeds)
//! - Cookie value: `name:sub+sub|name2:sub+sub` (`|` between feeds; split across feedsN cookies)

use crate::server::{RequestExt, ResponseExt};
use crate::utils::{redirect, Preferences};
use cookie::Cookie;
use hyper::{Body, Request, Response};
use revision::revisioned;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use time::{Duration, OffsetDateTime};

/// A named multi-reddit shown under MAIN FEEDS.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[revisioned(revision = 1)]
pub struct NamedFeed {
	#[revision(start = 1)]
	pub name: String,
	#[revision(start = 1)]
	pub subs: Vec<String>,
}

impl NamedFeed {
	pub fn multi_path(&self) -> String {
		self.subs.join("+")
	}

	pub fn is_valid(&self) -> bool {
		!self.name.is_empty() && !self.subs.is_empty()
	}
}

/// Sanitize feed names to `[A-Za-z0-9_-]{1,32}`.
pub fn sanitize_feed_name(raw: &str) -> Option<String> {
	let name: String = raw
		.chars()
		.filter(|c| c.is_ascii_alphanumeric() || *c == '_' || *c == '-')
		.take(32)
		.collect();
	if name.is_empty() {
		None
	} else {
		Some(name)
	}
}

fn sanitize_sub(raw: &str) -> Option<String> {
	let sub: String = raw
		.trim()
		.trim_start_matches("r/")
		.trim_start_matches("/r/")
		.chars()
		.filter(|c| c.is_ascii_alphanumeric() || *c == '_' || *c == '-')
		.take(64)
		.collect();
	if sub.is_empty() {
		None
	} else {
		Some(sub)
	}
}

fn parse_subs(raw: &str) -> Vec<String> {
	raw
		.split('+')
		.filter_map(sanitize_sub)
		.collect()
}

/// Parse instance/`urlencoded` format: `name:subs;name:subs`
pub fn parse_feeds_semicolon(raw: &str) -> Vec<NamedFeed> {
	if raw.is_empty() {
		return Vec::new();
	}
	raw
		.split(';')
		.filter_map(|part| {
			let (name, subs) = part.split_once(':')?;
			let name = sanitize_feed_name(name)?;
			let subs = parse_subs(subs);
			let feed = NamedFeed { name, subs };
			feed.is_valid().then_some(feed)
		})
		.collect()
}

/// Parse cookie format: `name:subs|name:subs`
pub fn parse_feeds_pipe(raw: &str) -> Vec<NamedFeed> {
	if raw.is_empty() {
		return Vec::new();
	}
	raw
		.split('|')
		.filter_map(|part| {
			let (name, subs) = part.split_once(':')?;
			let name = sanitize_feed_name(name)?;
			let subs = parse_subs(subs);
			let feed = NamedFeed { name, subs };
			feed.is_valid().then_some(feed)
		})
		.collect()
}

/// Encode feeds for cookies (`|` separator).
pub fn encode_feeds_pipe(feeds: &[NamedFeed]) -> String {
	feeds
		.iter()
		.filter(|f| f.is_valid())
		.map(|f| format!("{}:{}", f.name, f.multi_path()))
		.collect::<Vec<_>>()
		.join("|")
}

/// Encode feeds for urlencoded restore / instance docs (`;` separator).
pub fn encode_feeds_semicolon(feeds: &[NamedFeed]) -> String {
	feeds
		.iter()
		.filter(|f| f.is_valid())
		.map(|f| format!("{}:{}", f.name, f.multi_path()))
		.collect::<Vec<_>>()
		.join(";")
}

/// Read concatenated `feeds` / `feedsN` cookies, or `REDLIB_DEFAULT_FEEDS` when unset.
pub fn feeds_setting(req: &Request<Body>) -> String {
	if req.cookie("feeds").is_some() {
		let mut feeds = String::new();
		if let Some(c) = req.cookie("feeds") {
			feeds.push_str(c.value());
		}
		let mut n = 1;
		while let Some(c) = req.cookie(&format!("feeds{n}")) {
			feeds.push_str(c.value());
			n += 1;
		}
		feeds
	} else {
		crate::config::get_setting("REDLIB_DEFAULT_FEEDS").unwrap_or_default()
	}
}

pub fn feeds_from_request(req: &Request<Body>) -> Vec<NamedFeed> {
	let raw = feeds_setting(req);
	// Cookie uses `|`; instance default / restore uses `;`. Accept either.
	if raw.contains('|') {
		parse_feeds_pipe(&raw)
	} else {
		parse_feeds_semicolon(&raw)
	}
}

fn clear_feeds_cookies(response: &mut Response<Body>) {
	response.remove_cookie("feeds".to_string());
	for i in 1..16 {
		response.remove_cookie(format!("feeds{i}"));
	}
}

/// Write (or clear) feeds cookies on a response.
pub fn set_feeds_cookies(response: &mut Response<Body>, feeds: &[NamedFeed]) {
	clear_feeds_cookies(response);
	let pieces: Vec<String> = feeds
		.iter()
		.filter(|f| f.is_valid())
		.map(|f| format!("{}:{}", f.name, f.multi_path()))
		.collect();
	if pieces.is_empty() {
		return;
	}
	// Split on feed boundaries so we stay under the ~4KB cookie cap.
	let mut chunks: Vec<String> = Vec::new();
	let mut current = String::new();
	for piece in pieces {
		let add_len = if current.is_empty() { piece.len() } else { piece.len() + 1 };
		if !current.is_empty() && current.len() + add_len > 4000 {
			chunks.push(std::mem::take(&mut current));
			current = piece;
		} else {
			if !current.is_empty() {
				current.push('|');
			}
			current.push_str(&piece);
		}
	}
	if !current.is_empty() {
		chunks.push(current);
	}

	for (i, list) in chunks.into_iter().enumerate() {
		let name = if i == 0 {
			"feeds".to_string()
		} else {
			format!("feeds{i}")
		};
		response.insert_cookie(
			Cookie::build((name, list))
				.path("/")
				.http_only(true)
				.expires(OffsetDateTime::now_utc() + Duration::weeks(52))
				.into(),
		);
	}
}

/// Apply feeds from a restore query (`feeds=name:a+b;name2:c`).
pub fn restore_feeds_from_form(
	response: &mut Response<Body>,
	form: &HashMap<std::borrow::Cow<'_, str>, std::borrow::Cow<'_, str>>,
) {
	if let Some(raw) = form.get("feeds") {
		let feeds = parse_feeds_semicolon(raw);
		set_feeds_cookies(response, &feeds);
	} else {
		clear_feeds_cookies(response);
	}
}

fn redirect_after(req: &Request<Body>, fallback: &str) -> String {
	let query = req.uri().query().unwrap_or_default().as_bytes();
	let form: HashMap<_, _> = url::form_urlencoded::parse(query).collect();
	match form.get("redirect") {
		Some(value) => {
			let value = value.replace("%26", "&").replace("%23", "#");
			if value.starts_with('/') {
				value
			} else {
				format!("/{value}")
			}
		}
		None => fallback.to_string(),
	}
}

async fn form_map(req: Request<Body>) -> Result<(Request<Body>, HashMap<String, String>), String> {
	let (parts, body) = req.into_parts();
	let bytes = hyper::body::to_bytes(body).await.map_err(|e| e.to_string())?;
	let form: HashMap<String, String> = url::form_urlencoded::parse(&bytes)
		.map(|(k, v)| (k.into_owned(), v.into_owned()))
		.collect();
	let req = Request::from_parts(parts, Body::empty());
	Ok((req, form))
}

/// POST /feeds/create  form: name, subs (plus-delimited)
pub async fn create(req: Request<Body>) -> Result<Response<Body>, String> {
	let (req, form) = form_map(req).await?;
	let name = form.get("name").and_then(|n| sanitize_feed_name(n)).ok_or_else(|| "Invalid feed name".to_string())?;
	let subs = form.get("subs").map(|s| parse_subs(s)).unwrap_or_default();
	if subs.is_empty() {
		return Err("Feed needs at least one subreddit".to_string());
	}

	let mut feeds = feeds_from_request(&req);
	feeds.retain(|f| f.name != name);
	feeds.push(NamedFeed { name, subs });

	let path = redirect_after(&req, "/settings");
	let mut response = redirect(&path);
	set_feeds_cookies(&mut response, &feeds);
	Ok(response)
}

/// POST /feeds/:name/delete
pub async fn delete(req: Request<Body>) -> Result<Response<Body>, String> {
	let raw_name = req.param("name").ok_or_else(|| "Missing feed name".to_string())?;
	let name = sanitize_feed_name(&raw_name).ok_or_else(|| "Invalid feed name".to_string())?;
	let mut feeds = Preferences::new(&req).feeds;
	feeds.retain(|f| f.name != name);

	let path = redirect_after(&req, "/settings");
	let mut response = redirect(&path);
	set_feeds_cookies(&mut response, &feeds);
	Ok(response)
}

/// POST /feeds/save  form: name, subs (current multi) — upsert named feed from a multireddit view
pub async fn save(req: Request<Body>) -> Result<Response<Body>, String> {
	create(req).await
}

#[cfg(test)]
mod tests {
	use super::*;

	#[test]
	fn roundtrip_semicolon() {
		let raw = "work:sysadmin+365;fun:drumkits+pcmusic";
		let feeds = parse_feeds_semicolon(raw);
		assert_eq!(feeds.len(), 2);
		assert_eq!(feeds[0].name, "work");
		assert_eq!(feeds[0].subs, vec!["sysadmin", "365"]);
		assert_eq!(feeds[1].name, "fun");
		assert_eq!(encode_feeds_semicolon(&feeds), raw);
	}

	#[test]
	fn roundtrip_pipe() {
		let raw = "work:sysadmin+365|fun:drumkits+pcmusic";
		let feeds = parse_feeds_pipe(raw);
		assert_eq!(encode_feeds_pipe(&feeds), raw);
	}

	#[test]
	fn sanitize_rejects_empty() {
		assert!(sanitize_feed_name("!!!").is_none());
		assert_eq!(sanitize_feed_name("Fun_Feed-1").as_deref(), Some("Fun_Feed-1"));
	}
}
