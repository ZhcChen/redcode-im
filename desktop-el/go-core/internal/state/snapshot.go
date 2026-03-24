package state

type AccountSnapshot struct {
	ID          string `json:"id"`
	DisplayName string `json:"display_name"`
}

type ConfigSnapshot struct {
	AppName     string `json:"app_name"`
	Environment string `json:"environment"`
	APIBaseURL  string `json:"api_base_url"`
	WSURL       string `json:"ws_url"`
	Version     string `json:"version"`
	BuildNumber int    `json:"build_number"`
	Channel     string `json:"channel"`
}

type ConversationSnapshot struct {
	ID    string `json:"id"`
	Title string `json:"title"`
}

type ConnectionSnapshot struct {
	Status string `json:"status"`
}

type UserSnapshot struct {
	ID        string  `json:"id"`
	Username  string  `json:"username"`
	Email     string  `json:"email"`
	Nickname  *string `json:"nickname,omitempty"`
	AvatarURL *string `json:"avatar_url,omitempty"`
	Status    string  `json:"status"`
}

type AuthSnapshot struct {
	LoggedIn    bool          `json:"logged_in"`
	CurrentUser *UserSnapshot `json:"current_user"`
}

type BootstrapSnapshot struct {
	Accounts            []AccountSnapshot      `json:"accounts"`
	Config              ConfigSnapshot         `json:"config"`
	RecentConversations []ConversationSnapshot `json:"recent_conversations"`
	Connection          ConnectionSnapshot     `json:"connection"`
	FeatureFlags        map[string]bool        `json:"feature_flags"`
	Auth                AuthSnapshot           `json:"auth"`
}
