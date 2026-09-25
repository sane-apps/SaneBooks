//! Canonical JSON matching Swift `JSONEncoder` with `.sortedKeys` and `.iso8601`.
//! Forward slashes are escaped. Object keys are sorted. Nil values are omitted.

use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use time::format_description::well_known::Rfc3339;
use time::OffsetDateTime;

#[derive(Clone, Debug, PartialEq)]
pub enum Json {
    Bool(bool),
    Number(String),
    String(String),
    Array(Vec<Json>),
    Object(BTreeMap<String, Json>),
}

impl Json {
    pub fn object(entries: impl IntoIterator<Item = (String, Json)>) -> Self {
        Json::Object(entries.into_iter().collect())
    }

    pub fn encode(&self) -> String {
        let mut out = String::new();
        self.write(&mut out);
        out
    }

    fn write(&self, out: &mut String) {
        match self {
            Json::Bool(true) => out.push_str("true"),
            Json::Bool(false) => out.push_str("false"),
            Json::Number(n) => out.push_str(n),
            Json::String(s) => write_string(out, s),
            Json::Array(items) => {
                out.push('[');
                for (i, item) in items.iter().enumerate() {
                    if i > 0 {
                        out.push(',');
                    }
                    item.write(out);
                }
                out.push(']');
            }
            Json::Object(map) => {
                out.push('{');
                for (i, (key, value)) in map.iter().enumerate() {
                    if i > 0 {
                        out.push(',');
                    }
                    write_string(out, key);
                    out.push(':');
                    value.write(out);
                }
                out.push('}');
            }
        }
    }
}

fn write_string(out: &mut String, value: &str) {
    out.push('"');
    for ch in value.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '/' => out.push_str("\\/"),
            '\u{0008}' => out.push_str("\\b"),
            '\u{000c}' => out.push_str("\\f"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => {
                out.push_str(&format!("\\u{:04x}", c as u32));
            }
            c => out.push(c),
        }
    }
    out.push('"');
}

pub fn sha256_hex(bytes: &[u8]) -> String {
    let digest = Sha256::digest(bytes);
    hex::encode(digest)
}

pub fn format_unix(seconds: i64) -> Result<String, String> {
    let dt = OffsetDateTime::from_unix_timestamp(seconds)
        .map_err(|err| format!("invalid timestamp: {err}"))?;
    dt.format(&Rfc3339)
        .map_err(|err| format!("invalid timestamp: {err}"))
}

/// `YYYY-MM-DD` is the start of that UTC day, or 23:59:59 when `end_of_day` is set.
/// A full RFC3339 timestamp is used as given.
pub fn parse_date(text: &str, end_of_day: bool) -> Result<i64, String> {
    if text.len() == 10 && text.as_bytes().get(4) == Some(&b'-') && text.as_bytes().get(7) == Some(&b'-')
    {
        let unix = parse_unix(&format!("{text}T00:00:00Z"))?;
        return Ok(if end_of_day { unix + 86_399 } else { unix });
    }
    parse_unix(text)
}

pub fn parse_unix(text: &str) -> Result<i64, String> {
    let dt = OffsetDateTime::parse(text, &Rfc3339).map_err(|err| format!("invalid date: {err}"))?;
    Ok(dt.unix_timestamp())
}

/// Zatoshis as a JSON number. Whole ZEC stays an integer. Fractional ZEC trims trailing zeros.
pub fn zatoshis_number(zatoshis: i64) -> String {
    let sign = if zatoshis < 0 { "-" } else { "" };
    let abs = zatoshis.unsigned_abs();
    let whole = abs / 100_000_000;
    let frac = abs % 100_000_000;
    if frac == 0 {
        format!("{sign}{whole}")
    } else {
        let digits = format!("{frac:08}");
        let trimmed = digits.trim_end_matches('0');
        format!("{sign}{whole}.{trimmed}")
    }
}

pub fn insert_some(map: &mut BTreeMap<String, Json>, key: &str, value: Option<Json>) {
    if let Some(value) = value {
        map.insert(key.to_string(), value);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn slash_and_sort_match_swift() {
        let mut map = BTreeMap::new();
        map.insert("url".into(), Json::String("https://lwd.example/x".into()));
        let encoded = Json::Object(map).encode();
        assert_eq!(encoded, r#"{"url":"https:\/\/lwd.example\/x"}"#);
    }

    #[test]
    fn zatoshis_match_swift_decimal() {
        assert_eq!(zatoshis_number(150_000_000), "1.5");
        assert_eq!(zatoshis_number(200_000_000), "2");
        assert_eq!(zatoshis_number(1), "0.00000001");
        assert_eq!(zatoshis_number(0), "0");
    }

    #[test]
    fn iso8601_utc_uses_z() {
        assert_eq!(format_unix(1_700_000_000).unwrap(), "2023-11-14T22:13:20Z");
    }
}
