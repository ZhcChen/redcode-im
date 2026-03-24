package config

import "os"

type Config struct {
	AppName      string
	Environment  string
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

	return Config{
		AppName:     appName,
		Environment: environment,
		FeatureFlags: map[string]bool{
			"desktop_el":        true,
			"bootstrap_snapshot": true,
		},
	}
}
