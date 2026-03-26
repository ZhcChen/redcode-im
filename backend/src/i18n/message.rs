use std::collections::BTreeMap;

pub type MessageParams = BTreeMap<String, String>;

pub fn interpolate(template: &str, params: Option<&MessageParams>) -> String {
    match params {
        Some(params) => params.iter().fold(template.to_string(), |acc, (k, v)| {
            acc.replace(&format!("{{{}}}", k), v)
        }),
        None => template.to_string(),
    }
}
