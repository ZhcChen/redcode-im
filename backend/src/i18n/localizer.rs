use once_cell::sync::Lazy;

use crate::i18n::catalog::Catalog;
use crate::i18n::locale::{DEFAULT_LOCALE, negotiate_locale};
use crate::i18n::message::{MessageParams, interpolate};

#[derive(Debug, Clone)]
pub struct Localizer {
    catalog: Catalog,
    fallback_locale: String,
}

impl Localizer {
    pub fn new(catalog: Catalog, fallback_locale: impl Into<String>) -> Self {
        Self {
            catalog,
            fallback_locale: fallback_locale.into(),
        }
    }

    pub fn resolve_locale(&self, accept_language: Option<&str>) -> String {
        negotiate_locale(accept_language)
    }

    pub fn localize(
        &self,
        locale: &str,
        message_key: &str,
        params: Option<&MessageParams>,
    ) -> String {
        if let Some(template) = self.catalog.find(locale, message_key) {
            return interpolate(template, params);
        }

        if let Some(template) = self.catalog.find(&self.fallback_locale, message_key) {
            return interpolate(template, params);
        }

        message_key.to_string()
    }

    pub fn localize_by_header(
        &self,
        accept_language: Option<&str>,
        message_key: &str,
        params: Option<&MessageParams>,
    ) -> String {
        let locale = self.resolve_locale(accept_language);
        self.localize(&locale, message_key, params)
    }

    pub fn fallback_locale(&self) -> &str {
        &self.fallback_locale
    }
}

static DEFAULT_LOCALIZER: Lazy<Localizer> =
    Lazy::new(|| Localizer::new(Catalog::load_builtin(), DEFAULT_LOCALE));

pub fn default_localizer() -> &'static Localizer {
    &DEFAULT_LOCALIZER
}
