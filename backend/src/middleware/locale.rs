use axum::{extract::Request, http::header::ACCEPT_LANGUAGE, middleware::Next, response::Response};

use crate::i18n::localizer::default_localizer;

tokio::task_local! {
    static CURRENT_REQUEST_LOCALE: String;
}

#[derive(Debug, Clone)]
pub struct RequestLocale(String);

impl RequestLocale {
    pub fn new(locale: impl Into<String>) -> Self {
        Self(locale.into())
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

pub fn current_request_locale() -> Option<String> {
    CURRENT_REQUEST_LOCALE.try_with(Clone::clone).ok()
}

pub async fn locale_middleware(mut request: Request, next: Next) -> Response {
    let locale = default_localizer().resolve_locale(
        request
            .headers()
            .get(ACCEPT_LANGUAGE)
            .and_then(|value| value.to_str().ok()),
    );

    request
        .extensions_mut()
        .insert(RequestLocale::new(locale.clone()));

    CURRENT_REQUEST_LOCALE
        .scope(locale, async move { next.run(request).await })
        .await
}
