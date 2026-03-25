package friend

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"desktop-el-core/internal/httpclient"
)

func TestServiceListFriendRequestsSendsDirectionAndStatusQuery(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/friends/requests" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodGet {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if got := r.URL.Query().Get("direction"); got != "outgoing" {
			t.Fatalf("unexpected direction: %s", got)
		}
		if got := r.URL.Query().Get("status"); got != "pending" {
			t.Fatalf("unexpected status: %s", got)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": true,
			"code":    200,
			"message": "ok",
			"data":    []any{},
		})
	}))
	defer server.Close()

	service := New(httpclient.New(httpclient.Config{BaseURL: server.URL}))
	if _, err := service.ListFriendRequests(context.Background(), ListFriendRequestsParams{
		Direction: "outgoing",
		Status:    "pending",
	}); err != nil {
		t.Fatalf("list friend requests failed: %v", err)
	}
}

func TestServiceCreateFriendRequestPostsBody(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/friends/requests" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method: %s", r.Method)
		}

		var body map[string]string
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Fatalf("decode request body failed: %v", err)
		}
		if body["target_user_id"] != "u-2" || body["message"] != "你好" {
			t.Fatalf("unexpected request body: %+v", body)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": true,
			"code":    200,
			"message": "ok",
			"data":    map[string]any{},
		})
	}))
	defer server.Close()

	service := New(httpclient.New(httpclient.Config{BaseURL: server.URL}))
	if _, err := service.CreateFriendRequest(context.Background(), CreateFriendRequestParams{
		TargetUserID: "u-2",
		Message:      "你好",
	}); err != nil {
		t.Fatalf("create friend request failed: %v", err)
	}
}

func TestServiceUpdateFriendRemarkAndDeleteFriendUseExpectedRoutes(t *testing.T) {
	requests := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests++
		switch requests {
		case 1:
			if r.URL.Path != "/friends/u-2/remark" {
				t.Fatalf("unexpected remark path: %s", r.URL.Path)
			}
			if r.Method != http.MethodPatch {
				t.Fatalf("unexpected remark method: %s", r.Method)
			}

			var body map[string]string
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
				t.Fatalf("decode remark body failed: %v", err)
			}
			if body["remark"] != "Alice 同事" {
				t.Fatalf("unexpected remark body: %+v", body)
			}
		case 2:
			if r.URL.Path != "/friends/u-2" {
				t.Fatalf("unexpected delete path: %s", r.URL.Path)
			}
			if r.Method != http.MethodDelete {
				t.Fatalf("unexpected delete method: %s", r.Method)
			}
		default:
			t.Fatalf("unexpected request count: %d", requests)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"success": true,
			"code":    200,
			"message": "ok",
			"data":    map[string]any{},
		})
	}))
	defer server.Close()

	service := New(httpclient.New(httpclient.Config{BaseURL: server.URL}))

	if _, err := service.UpdateFriendRemark(context.Background(), UpdateFriendRemarkParams{
		FriendUserID: "u-2",
		Remark:       "Alice 同事",
	}); err != nil {
		t.Fatalf("update friend remark failed: %v", err)
	}

	if _, err := service.DeleteFriend(context.Background(), DeleteFriendParams{
		FriendUserID: "u-2",
	}); err != nil {
		t.Fatalf("delete friend failed: %v", err)
	}
}
