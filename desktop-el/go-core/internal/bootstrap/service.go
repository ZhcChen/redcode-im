package bootstrap

import (
	"desktop-el-core/internal/config"
	"desktop-el-core/internal/state"
)

type Service struct {
	config config.Config
}

func New(cfg config.Config) *Service {
	return &Service{config: cfg}
}

func (s *Service) BuildSnapshot() state.BootstrapSnapshot {
	return state.BootstrapSnapshot{
		Accounts: []state.AccountSnapshot{},
		Config: state.ConfigSnapshot{
			AppName:     s.config.AppName,
			Environment: s.config.Environment,
		},
		RecentConversations: []state.ConversationSnapshot{},
		Connection: state.ConnectionSnapshot{
			Status: "idle",
		},
		FeatureFlags: cloneFeatureFlags(s.config.FeatureFlags),
	}
}

func cloneFeatureFlags(source map[string]bool) map[string]bool {
	if len(source) == 0 {
		return map[string]bool{}
	}

	result := make(map[string]bool, len(source))
	for key, value := range source {
		result[key] = value
	}
	return result
}
