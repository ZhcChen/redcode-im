package versions_test

import (
	"net/url"
	"os"
	"testing"
	"time"

	"redcode-im-tests/internal/testutil"
)

type appVersionInfo struct {
	ID          string  `json:"id"`
	Platform    string  `json:"platform"`
	Version     string  `json:"version"`
	BuildNumber int     `json:"build_number"`
	Channel     string  `json:"channel"`
	DownloadKey string  `json:"download_key"`
	DownloadURL *string `json:"download_url"`
	IsActive    bool    `json:"is_active"`
}

type latestVersionResp struct {
	HasUpdate      bool           `json:"has_update"`
	CurrentVersion *string        `json:"current_version"`
	Version        *appVersionInfo `json:"version"`
}

type latestDownloadResp struct {
	Success     bool            `json:"success"`
	Message     string          `json:"message"`
	Version     *appVersionInfo `json:"version"`
	DownloadURL *string         `json:"download_url"`
}

type versionDownloadResp struct {
	Success     bool    `json:"success"`
	Message     string  `json:"message"`
	DownloadURL *string `json:"download_url"`
}

type hotUpdateInfo struct {
	ID           string  `json:"id"`
	Platform     string  `json:"platform"`
	AppVersionID string  `json:"app_version_id"`
	PatchVersion string  `json:"patch_version"`
	Channel      string  `json:"channel"`
	DownloadKey  string  `json:"download_key"`
	DownloadURL  *string `json:"download_url"`
	IsActive     bool    `json:"is_active"`
}

type hotUpdateResp struct {
	HasUpdate           bool         `json:"has_update"`
	CurrentPatchVersion *string      `json:"current_patch_version"`
	Patch               *hotUpdateInfo `json:"patch"`
}

type hotUpdateDownloadResp struct {
	Success     bool    `json:"success"`
	Message     string  `json:"message"`
	DownloadURL *string `json:"download_url"`
}

type simpleSuccess struct {
	Success bool `json:"success"`
}

func TestVersions_AppAndHotUpdate_Flow(t *testing.T) {
	adminUser := os.Getenv("ADMIN_USERNAME")
	adminPass := os.Getenv("ADMIN_PASSWORD")
	if adminUser == "" || adminPass == "" {
		t.Skip("missing ADMIN_USERNAME / ADMIN_PASSWORD, skip versions test")
	}

	c := testutil.NewClient()
	testutil.EnsureDefaultAdmin(t, c)
	admin := testutil.AdminLogin(t, c, adminUser, adminPass)

	channel := "stable"
	platform := "android"
	version := "1.0." + time.Now().Format("150405")
	downloadURL := "https://example.com/app-" + url.QueryEscape(version) + ".apk"

	// 1) 创建整包版本（使用 download_url，避免依赖对象存储）
	respCreate, bodyCreate, err := c.DoJSON("POST", "/api/admin/app-versions", map[string]any{
		"platform":     platform,
		"version":      version,
		"build_number": 1,
		"channel":      channel,
		"download_key": "",
		"download_url": downloadURL,
		"is_active":    true,
	}, admin.Token)
	if err != nil {
		t.Fatalf("create app version http error: %v", err)
	}
	if respCreate.StatusCode != 200 {
		t.Fatalf("create app version status=%d body=%s", respCreate.StatusCode, string(bodyCreate))
	}
	var created appVersionInfo
	if err := testutil.DecodeJSON(bodyCreate, &created); err != nil {
		t.Fatalf("decode created version: %v body=%s", err, string(bodyCreate))
	}
	if created.ID == "" || created.Platform != platform || created.Version != version || created.Channel != channel {
		t.Fatalf("unexpected created version: %+v body=%s", created, string(bodyCreate))
	}

	// 2) public: latest（current_version 为空 -> has_update=true）
	latestPath := "/versions/latest?platform=" + url.QueryEscape(platform) + "&channel=" + url.QueryEscape(channel)
	respLatest, bodyLatest, err := c.DoJSON("GET", latestPath, nil, "")
	if err != nil {
		t.Fatalf("latest version http error: %v", err)
	}
	if respLatest.StatusCode != 200 {
		t.Fatalf("latest version status=%d body=%s", respLatest.StatusCode, string(bodyLatest))
	}
	var latest latestVersionResp
	if err := testutil.DecodeJSON(bodyLatest, &latest); err != nil {
		t.Fatalf("decode latest version: %v body=%s", err, string(bodyLatest))
	}
	if latest.Version == nil || latest.Version.ID != created.ID || !latest.HasUpdate {
		t.Fatalf("unexpected latest version resp: %+v body=%s", latest, string(bodyLatest))
	}

	// 3) current_version 与最新一致 -> has_update=false
	latestNoUpdatePath := latestPath + "&current_version=" + url.QueryEscape(version)
	respNoUpd, bodyNoUpd, err := c.DoJSON("GET", latestNoUpdatePath, nil, "")
	if err != nil {
		t.Fatalf("latest version (no update) http error: %v", err)
	}
	if respNoUpd.StatusCode != 200 {
		t.Fatalf("latest version (no update) status=%d body=%s", respNoUpd.StatusCode, string(bodyNoUpd))
	}
	var latestNoUpd latestVersionResp
	if err := testutil.DecodeJSON(bodyNoUpd, &latestNoUpd); err != nil {
		t.Fatalf("decode latest no-update: %v body=%s", err, string(bodyNoUpd))
	}
	if latestNoUpd.HasUpdate {
		t.Fatalf("expected has_update=false when current_version matches latest, got %+v", latestNoUpd)
	}

	// 4) public: latest download-url（应返回显式 download_url）
	dlLatestPath := "/versions/latest/download-url?platform=" + url.QueryEscape(platform) + "&channel=" + url.QueryEscape(channel)
	respDL, bodyDL, err := c.DoJSON("GET", dlLatestPath, nil, "")
	if err != nil {
		t.Fatalf("latest download-url http error: %v", err)
	}
	if respDL.StatusCode != 200 {
		t.Fatalf("latest download-url status=%d body=%s", respDL.StatusCode, string(bodyDL))
	}
	var ldr latestDownloadResp
	if err := testutil.DecodeJSON(bodyDL, &ldr); err != nil {
		t.Fatalf("decode latest download-url: %v body=%s", err, string(bodyDL))
	}
	if !ldr.Success || ldr.DownloadURL == nil || *ldr.DownloadURL != downloadURL {
		t.Fatalf("unexpected latest download-url resp: %+v body=%s", ldr, string(bodyDL))
	}

	// 5) public: download by id
	downloadByID := "/versions/download?id=" + url.QueryEscape(created.ID)
	respDL2, bodyDL2, err := c.DoJSON("GET", downloadByID, nil, "")
	if err != nil {
		t.Fatalf("download version http error: %v", err)
	}
	if respDL2.StatusCode != 200 {
		t.Fatalf("download version status=%d body=%s", respDL2.StatusCode, string(bodyDL2))
	}
	var vdr versionDownloadResp
	if err := testutil.DecodeJSON(bodyDL2, &vdr); err != nil {
		t.Fatalf("decode download version: %v body=%s", err, string(bodyDL2))
	}
	if !vdr.Success || vdr.DownloadURL == nil || *vdr.DownloadURL != downloadURL {
		t.Fatalf("unexpected download version resp: %+v body=%s", vdr, string(bodyDL2))
	}

	// 6) 创建热更新补丁（同样使用 download_url + 空 download_key）
	patchVersion := "p-" + time.Now().Format("150405.000000000")
	patchURL := "https://example.com/patch-" + url.QueryEscape(patchVersion) + ".zip"
	respPatch, bodyPatch, err := c.DoJSON("POST", "/api/admin/hot-updates", map[string]any{
		"platform":       platform,
		"app_version_id": created.ID,
		"patch_version":  patchVersion,
		"channel":        channel,
		"download_key":   "",
		"download_url":   patchURL,
		"rollout_percentage": 100,
	}, admin.Token)
	if err != nil {
		t.Fatalf("create hot update http error: %v", err)
	}
	if respPatch.StatusCode != 200 {
		t.Fatalf("create hot update status=%d body=%s", respPatch.StatusCode, string(bodyPatch))
	}
	var patch hotUpdateInfo
	if err := testutil.DecodeJSON(bodyPatch, &patch); err != nil {
		t.Fatalf("decode created hot update: %v body=%s", err, string(bodyPatch))
	}
	if patch.ID == "" || patch.PatchVersion != patchVersion || patch.Channel != channel || patch.Platform != platform {
		t.Fatalf("unexpected hot update: %+v body=%s", patch, string(bodyPatch))
	}

	// 7) public: latest hot update
	hotPath := "/versions/hot-update?platform=" + url.QueryEscape(platform) + "&channel=" + url.QueryEscape(channel) + "&current_version=" + url.QueryEscape(version)
	respHot, bodyHot, err := c.DoJSON("GET", hotPath, nil, "")
	if err != nil {
		t.Fatalf("latest hot update http error: %v", err)
	}
	if respHot.StatusCode != 200 {
		t.Fatalf("latest hot update status=%d body=%s", respHot.StatusCode, string(bodyHot))
	}
	var hr hotUpdateResp
	if err := testutil.DecodeJSON(bodyHot, &hr); err != nil {
		t.Fatalf("decode hot update resp: %v body=%s", err, string(bodyHot))
	}
	if !hr.HasUpdate || hr.Patch == nil || hr.Patch.ID != patch.ID {
		t.Fatalf("unexpected hot update resp: %+v body=%s", hr, string(bodyHot))
	}

	// 8) public: download hot update by id
	patchDownload := "/versions/hot-update/download?id=" + url.QueryEscape(patch.ID)
	respHDL, bodyHDL, err := c.DoJSON("GET", patchDownload, nil, "")
	if err != nil {
		t.Fatalf("download hot update http error: %v", err)
	}
	if respHDL.StatusCode != 200 {
		t.Fatalf("download hot update status=%d body=%s", respHDL.StatusCode, string(bodyHDL))
	}
	var hdr hotUpdateDownloadResp
	if err := testutil.DecodeJSON(bodyHDL, &hdr); err != nil {
		t.Fatalf("decode download hot update: %v body=%s", err, string(bodyHDL))
	}
	if !hdr.Success || hdr.DownloadURL == nil || *hdr.DownloadURL != patchURL {
		t.Fatalf("unexpected download hot update resp: %+v body=%s", hdr, string(bodyHDL))
	}

	// 9) public: report hot update event + 兼容旧路径
	reportPayload := map[string]any{
		"platform":      platform,
		"channel":       channel,
		"base_version":  version,
		"patch_version": patchVersion,
		"event_type":    "download_success",
	}

	respR, bodyR, err := c.DoJSON("POST", "/versions/hot-update/report", reportPayload, "")
	if err != nil {
		t.Fatalf("report hot update http error: %v", err)
	}
	if respR.StatusCode != 200 {
		t.Fatalf("report hot update status=%d body=%s", respR.StatusCode, string(bodyR))
	}
	var ok simpleSuccess
	if err := testutil.DecodeJSON(bodyR, &ok); err != nil {
		t.Fatalf("decode report hot update: %v body=%s", err, string(bodyR))
	}
	if !ok.Success {
		t.Fatalf("expected report success=true, got %+v body=%s", ok, string(bodyR))
	}

	respR2, bodyR2, err := c.DoJSON("POST", "/versions/hot-update-events", reportPayload, "")
	if err != nil {
		t.Fatalf("report hot update (compat) http error: %v", err)
	}
	if respR2.StatusCode != 200 {
		t.Fatalf("report hot update (compat) status=%d body=%s", respR2.StatusCode, string(bodyR2))
	}
	var ok2 simpleSuccess
	if err := testutil.DecodeJSON(bodyR2, &ok2); err != nil {
		t.Fatalf("decode report hot update (compat): %v body=%s", err, string(bodyR2))
	}
	if !ok2.Success {
		t.Fatalf("expected report compat success=true, got %+v body=%s", ok2, string(bodyR2))
	}
}

