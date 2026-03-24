package config

import "os"

type Config struct {
	AppName      string
	Environment  string
	APIBaseURL   string
	WSURL        string
	AppVersion   string
	BuildNumber  int
	Channel      string
	FeatureFlags map[string]bool
}

func Load() Config {
	environment := os.Getenv("DESKTOP_EL_ENV")
	if environment == "" {
		environment = "development"
	}

	appName := os.Getenv("DESKTOP_EL_APP_NAME")
	if appName == "" {
		appName = "RedCode IM"
	}

	apiBaseURL := os.Getenv("DESKTOP_EL_API_BASE_URL")
	if apiBaseURL == "" {
		apiBaseURL = "http://127.0.0.1:8010"
	}

	wsURL := os.Getenv("DESKTOP_EL_WS_URL")
	if wsURL == "" {
		wsURL = "ws://127.0.0.1:8010/ws"
	}

	appVersion := os.Getenv("DESKTOP_EL_APP_VERSION")
	if appVersion == "" {
		appVersion = "0.1.0"
	}

	channel := os.Getenv("DESKTOP_EL_APP_CHANNEL")
	if channel == "" {
		channel = "stable"
	}

	return Config{
		AppName:     appName,
		Environment: environment,
		APIBaseURL:  apiBaseURL,
		WSURL:       wsURL,
		AppVersion:  appVersion,
		BuildNumber: 1,
		Channel:     channel,
		FeatureFlags: map[string]bool{
			"desktop_el":         true,
			"bootstrap_snapshot": true,
			"go_transport":       true,
		},
	}
}
