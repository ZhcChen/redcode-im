use std::collections::HashMap;

#[derive(Debug, Clone, Default)]
pub struct Catalog {
    messages: HashMap<String, HashMap<String, String>>,
}

impl Catalog {
    pub fn load_builtin() -> Self {
        let mut catalog = Self::default();
        catalog.load_locale_messages("zh-CN", include_str!("../../i18n/zh-CN/common.json"));
        catalog.load_locale_messages("zh-CN", include_str!("../../i18n/zh-CN/auth.json"));
        catalog.load_locale_messages("zh-CN", include_str!("../../i18n/zh-CN/friend.json"));
        catalog.load_locale_messages("zh-CN", include_str!("../../i18n/zh-CN/user.json"));
        catalog.load_locale_messages("zh-CN", include_str!("../../i18n/zh-CN/message.json"));
        catalog.load_locale_messages("zh-CN", include_str!("../../i18n/zh-CN/group.json"));
        catalog.load_locale_messages("zh-CN", include_str!("../../i18n/zh-CN/version.json"));
        catalog.load_locale_messages("zh-CN", include_str!("../../i18n/zh-CN/room.json"));
        catalog.load_locale_messages("zh-CN", include_str!("../../i18n/zh-CN/admin.json"));
        catalog.load_locale_messages("zh-CN", include_str!("../../i18n/zh-CN/upload.json"));
        catalog.load_locale_messages("zh-CN", include_str!("../../i18n/zh-CN/emoji.json"));
        catalog.load_locale_messages("zh-CN", include_str!("../../i18n/zh-CN/report.json"));
        catalog.load_locale_messages("zh-CN", include_str!("../../i18n/zh-CN/push.json"));
        catalog.load_locale_messages("zh-CN", include_str!("../../i18n/zh-CN/e2ee.json"));
        catalog.load_locale_messages("zh-CN", include_str!("../../i18n/zh-CN/feedback.json"));
        catalog.load_locale_messages("zh-CN", include_str!("../../i18n/zh-CN/upload_policy.json"));
        catalog.load_locale_messages("zh-CN", include_str!("../../i18n/zh-CN/settings.json"));
        catalog.load_locale_messages("zh-CN", include_str!("../../i18n/zh-CN/storage.json"));
        catalog.load_locale_messages("zh-CN", include_str!("../../i18n/zh-CN/chat_history.json"));
        catalog.load_locale_messages("en-US", include_str!("../../i18n/en-US/common.json"));
        catalog.load_locale_messages("en-US", include_str!("../../i18n/en-US/auth.json"));
        catalog.load_locale_messages("en-US", include_str!("../../i18n/en-US/friend.json"));
        catalog.load_locale_messages("en-US", include_str!("../../i18n/en-US/user.json"));
        catalog.load_locale_messages("en-US", include_str!("../../i18n/en-US/message.json"));
        catalog.load_locale_messages("en-US", include_str!("../../i18n/en-US/group.json"));
        catalog.load_locale_messages("en-US", include_str!("../../i18n/en-US/version.json"));
        catalog.load_locale_messages("en-US", include_str!("../../i18n/en-US/room.json"));
        catalog.load_locale_messages("en-US", include_str!("../../i18n/en-US/admin.json"));
        catalog.load_locale_messages("en-US", include_str!("../../i18n/en-US/upload.json"));
        catalog.load_locale_messages("en-US", include_str!("../../i18n/en-US/emoji.json"));
        catalog.load_locale_messages("en-US", include_str!("../../i18n/en-US/report.json"));
        catalog.load_locale_messages("en-US", include_str!("../../i18n/en-US/push.json"));
        catalog.load_locale_messages("en-US", include_str!("../../i18n/en-US/e2ee.json"));
        catalog.load_locale_messages("en-US", include_str!("../../i18n/en-US/feedback.json"));
        catalog.load_locale_messages("en-US", include_str!("../../i18n/en-US/upload_policy.json"));
        catalog.load_locale_messages("en-US", include_str!("../../i18n/en-US/settings.json"));
        catalog.load_locale_messages("en-US", include_str!("../../i18n/en-US/storage.json"));
        catalog.load_locale_messages("en-US", include_str!("../../i18n/en-US/chat_history.json"));
        catalog
    }

    pub fn find(&self, locale: &str, key: &str) -> Option<&str> {
        self.messages
            .get(locale)
            .and_then(|catalog| catalog.get(key))
            .map(String::as_str)
    }

    fn load_locale_messages(&mut self, locale: &str, content: &str) {
        let messages: HashMap<String, String> =
            serde_json::from_str(content).expect("invalid builtin i18n catalog JSON format");
        self.messages
            .entry(locale.to_string())
            .or_default()
            .extend(messages);
    }
}
