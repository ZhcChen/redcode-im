package admin_test

import (
	"os"
	"testing"

	"redcode-im-tests/internal/testutil"
)

type dashboardStorageStats struct {
	TotalFiles  int64 `json:"totalFiles"`
	TotalSize   int64 `json:"totalSize"`
	TodayUploads int64 `json:"todayUploads"`
}

type dashboardEmojiStats struct {
	TotalEmojis   int64 `json:"totalEmojis"`
	TodayUsage    int64 `json:"todayUsage"`
	PopularCount  int64 `json:"popularCount"`
}

type dailyStat struct {
	Date  string `json:"date"`
	Count int64  `json:"count"`
}

type storageTypeStat struct {
	FileType   string  `json:"file_type"`
	Count      int64   `json:"count"`
	SizeBytes  int64   `json:"size_bytes"`
	Percentage float64 `json:"percentage"`
}

type dataStatistics struct {
	DailyActiveUsers   []dailyStat        `json:"daily_active_users"`
	DailyMessages      []dailyStat        `json:"daily_messages"`
	StorageUsageByType []storageTypeStat  `json:"storage_usage_by_type"`
	UserGrowthRate     float64            `json:"user_growth_rate"`
	MessageGrowthRate  float64            `json:"message_growth_rate"`
	PeakActiveTime     string             `json:"peak_active_time"`
}

func TestAdmin_Dashboard_StorageEmojiAndStatistics(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip admin dashboard extra test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	respStorage, bodyStorage, err := c.DoJSON("GET", "/api/dashboard/storage-stats", nil, admin.Token)
	if err != nil {
		t.Fatalf("dashboard storage-stats http error: %v", err)
	}
	if respStorage.StatusCode != 200 {
		t.Fatalf("dashboard storage-stats status=%d body=%s", respStorage.StatusCode, string(bodyStorage))
	}
	var storage dashboardStorageStats
	if err := testutil.DecodeJSON(bodyStorage, &storage); err != nil {
		t.Fatalf("decode dashboard storage-stats: %v body=%s", err, string(bodyStorage))
	}
	if storage.TotalFiles < 0 || storage.TotalSize < 0 || storage.TodayUploads < 0 {
		t.Fatalf("expected storage stats >=0, got %+v body=%s", storage, string(bodyStorage))
	}

	respEmoji, bodyEmoji, err := c.DoJSON("GET", "/api/dashboard/emoji-stats", nil, admin.Token)
	if err != nil {
		t.Fatalf("dashboard emoji-stats http error: %v", err)
	}
	if respEmoji.StatusCode != 200 {
		t.Fatalf("dashboard emoji-stats status=%d body=%s", respEmoji.StatusCode, string(bodyEmoji))
	}
	var emoji dashboardEmojiStats
	if err := testutil.DecodeJSON(bodyEmoji, &emoji); err != nil {
		t.Fatalf("decode dashboard emoji-stats: %v body=%s", err, string(bodyEmoji))
	}
	if emoji.TotalEmojis < 0 || emoji.TodayUsage < 0 || emoji.PopularCount < 0 {
		t.Fatalf("expected emoji stats >=0, got %+v body=%s", emoji, string(bodyEmoji))
	}

	respStats, bodyStats, err := c.DoJSON("GET", "/api/dashboard/statistics", nil, admin.Token)
	if err != nil {
		t.Fatalf("dashboard statistics http error: %v", err)
	}
	if respStats.StatusCode != 200 {
		t.Fatalf("dashboard statistics status=%d body=%s", respStats.StatusCode, string(bodyStats))
	}
	var stats dataStatistics
	if err := testutil.DecodeJSON(bodyStats, &stats); err != nil {
		t.Fatalf("decode dashboard statistics: %v body=%s", err, string(bodyStats))
	}
	if stats.PeakActiveTime == "" {
		t.Fatalf("expected peak_active_time non-empty, body=%s", string(bodyStats))
	}
	// 其余字段只做“可解析”断言，避免对统计细节产生脆弱耦合
}

