use std::cmp::Ordering;

pub const DEFAULT_LOCALE: &str = "zh-CN";
pub const SUPPORTED_LOCALES: [&str; 2] = ["zh-CN", "en-US"];

pub fn negotiate_locale(accept_language: Option<&str>) -> String {
    let Some(header) = accept_language else {
        return DEFAULT_LOCALE.to_string();
    };

    let mut candidates: Vec<(String, f32, usize)> = header
        .split(',')
        .enumerate()
        .filter_map(|(index, segment)| {
            let mut parts = segment.trim().split(';');
            let raw_tag = parts.next()?.trim();
            if raw_tag.is_empty() {
                return None;
            }

            let q = parts
                .find_map(|part| {
                    let part = part.trim();
                    part.strip_prefix("q=").and_then(|value| value.parse::<f32>().ok())
                })
                .unwrap_or(1.0);

            Some((normalize_tag(raw_tag), q, index))
        })
        .collect();

    candidates.sort_by(|a, b| {
        b.1.partial_cmp(&a.1)
            .unwrap_or(Ordering::Equal)
            .then_with(|| a.2.cmp(&b.2))
    });

    for (candidate, _, _) in candidates {
        if candidate == "*" {
            return DEFAULT_LOCALE.to_string();
        }

        if let Some(exact) = exact_supported_locale(&candidate) {
            return exact.to_string();
        }

        if let Some(fallback) = family_fallback_locale(&candidate) {
            return fallback.to_string();
        }
    }

    DEFAULT_LOCALE.to_string()
}

fn normalize_tag(tag: &str) -> String {
    let normalized = tag.trim().replace('_', "-");
    let mut parts = normalized.split('-');
    let language = parts.next().unwrap_or_default().to_ascii_lowercase();
    let region = parts.next().map(|value| value.to_ascii_uppercase());

    match region {
        Some(region) if !language.is_empty() => format!("{}-{}", language, region),
        _ => language,
    }
}

fn exact_supported_locale(tag: &str) -> Option<&'static str> {
    SUPPORTED_LOCALES
        .iter()
        .copied()
        .find(|locale| locale.eq_ignore_ascii_case(tag))
}

fn family_fallback_locale(tag: &str) -> Option<&'static str> {
    let family = tag.split('-').next()?;
    SUPPORTED_LOCALES.iter().copied().find(|locale| {
        locale
            .split('-')
            .next()
            .is_some_and(|supported_family| supported_family.eq_ignore_ascii_case(family))
    })
}
