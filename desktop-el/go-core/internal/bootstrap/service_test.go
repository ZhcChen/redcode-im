package bootstrap

import (
	"testing"

	"desktop-el-core/internal/config"
)

func TestServiceBuildSnapshot(t *testing.T) {
	service := New(config.Config{
		AppName:     "RedCode IM",
		Environment: "development",
		APIBaseURL:  "http://127.0.0.1:8010",
		WSURL:       "ws://127.0.0.1:8010/ws",
		AppVersion:  "0.1.0",
		BuildNumber: 1,
		Channel:     "stable",
		FeatureFlags: map[string]bool{
			"desktop_el": true,
		},
	})

	snapshot := service.BuildSnapshot()

	if snapshot.Config.AppName != "RedCode IM" {
		t.Fatalf("unexpected app name: %+v", snapshot.Config)
	}
	if snapshot.Config.APIBaseURL != "http://127.0.0.1:8010" {
		t.Fatalf("unexpected api base url: %+v", snapshot.Config)
	}
	if snapshot.Connection.Status != "idle" {
		t.Fatalf("unexpected connection status: %+v", snapshot.Connection)
	}
	if !snapshot.FeatureFlags["desktop_el"] {
		t.Fatalf("expected feature flag to be enabled: %+v", snapshot.FeatureFlags)
	}
}
