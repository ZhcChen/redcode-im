package admin_test

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type adminDataCleanupResponse struct {
	Success       bool     `json:"success"`
	Message       string   `json:"message"`
	CleanedTables []string `json:"cleaned_tables"`
	Error         *string  `json:"error"`
}

func TestAdminDataCleanupLocalizedResponses(t *testing.T) {
	c := testutil.NewClient()
	admin := testutil.AdminLogin(t, c)

	req := testutil.NewAuthedJSONRequest(
		t,
		http.MethodPost,
		c.BaseURL+"/admin/data/cleanup/all",
		admin.Token,
		map[string]any{},
	)
	req.Header.Set("Accept-Language", "en-US")

	resp, err := c.HTTP.Do(req)
	if err != nil {
		t.Fatalf("data cleanup request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("unexpected status: want %d got %d body=%s", http.StatusOK, resp.StatusCode, string(body))
	}

	var payload adminDataCleanupResponse
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode data cleanup response failed: %v", err)
	}
	if !payload.Success {
		t.Fatalf("expected success=true, got false: %+v", payload)
	}
	wantMessage := fmt.Sprintf("Successfully cleaned data from %d tables.", len(payload.CleanedTables))
	if payload.Message != wantMessage {
		t.Fatalf("unexpected message: %q", payload.Message)
	}
	if payload.Error != nil {
		t.Fatalf("expected nil error, got %q", *payload.Error)
	}
}
