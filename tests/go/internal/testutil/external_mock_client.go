package testutil

import (
	"os"
	"strings"
)

func ExternalMockBaseURL() string {
	base := os.Getenv("EXTERNAL_MOCK_BASE_URL")
	if strings.TrimSpace(base) == "" {
		base = "http://localhost:19080"
	}
	return strings.TrimRight(base, "/")
}
