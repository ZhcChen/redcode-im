package session

import "testing"

func TestServiceStoreAndClear(t *testing.T) {
	service := New()

	service.Set("access-token", "refresh-token")

	if got := service.AccessToken(); got != "access-token" {
		t.Fatalf("unexpected access token: %s", got)
	}
	if got := service.RefreshToken(); got != "refresh-token" {
		t.Fatalf("unexpected refresh token: %s", got)
	}

	service.Clear()

	if service.AccessToken() != "" {
		t.Fatalf("expected access token to be cleared")
	}
	if service.RefreshToken() != "" {
		t.Fatalf("expected refresh token to be cleared")
	}
}
