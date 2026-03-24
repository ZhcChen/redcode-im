package state

type AccountSnapshot struct {
	ID          string `json:"id"`
	DisplayName string `json:"display_name"`
}

type ConfigSnapshot struct {
	AppName     string `json:"app_name"`
	Environment string `json:"environment"`
}

type ConversationSnapshot struct {
	ID    string `json:"id"`
	Title string `json:"title"`
}

type ConnectionSnapshot struct {
	Status string `json:"status"`
}

type BootstrapSnapshot struct {
	Accounts            []AccountSnapshot      `json:"accounts"`
	Config              ConfigSnapshot         `json:"config"`
	RecentConversations []ConversationSnapshot `json:"recent_conversations"`
	Connection          ConnectionSnapshot     `json:"connection"`
	FeatureFlags        map[string]bool        `json:"feature_flags"`
}
