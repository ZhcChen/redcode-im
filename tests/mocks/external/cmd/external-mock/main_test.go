package main

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"regexp"
	"strconv"
	"strings"
	"testing"
)

func newTestServer() (*mockServer, *httptest.Server) {
	s := newMockServer()
	ts := httptest.NewServer(http.HandlerFunc(s.handle))
	return s, ts
}

func TestHealthz(t *testing.T) {
	_, ts := newTestServer()
	defer ts.Close()

	resp, err := http.Get(ts.URL + "/healthz")
	if err != nil {
		t.Fatalf("healthz request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expect 200, got %d", resp.StatusCode)
	}
}

func TestB2AuthorizeAccount(t *testing.T) {
	_, ts := newTestServer()
	defer ts.Close()

	req, err := http.NewRequest(http.MethodGet, ts.URL+"/b2api/v4/b2_authorize_account", nil)
	if err != nil {
		t.Fatalf("build request failed: %v", err)
	}
	req.SetBasicAuth("mock-key-id", "mock-application-key")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("expect 200, got %d: %s", resp.StatusCode, string(body))
	}

	var payload struct {
		APIInfo struct {
			StorageAPI struct {
				S3APIURL string `json:"s3ApiUrl"`
				Allowed  struct {
					Buckets []struct {
						Name string `json:"name"`
					} `json:"buckets"`
					Capabilities []string `json:"capabilities"`
				} `json:"allowed"`
			} `json:"storageApi"`
		} `json:"apiInfo"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode authorize response failed: %v", err)
	}
	if payload.APIInfo.StorageAPI.S3APIURL != ts.URL {
		t.Fatalf("expect s3ApiUrl=%s, got %s", ts.URL, payload.APIInfo.StorageAPI.S3APIURL)
	}
	if len(payload.APIInfo.StorageAPI.Allowed.Buckets) == 0 || payload.APIInfo.StorageAPI.Allowed.Buckets[0].Name != "mock-bucket" {
		t.Fatalf("expected mock-bucket in allowed buckets: %+v", payload.APIInfo.StorageAPI.Allowed.Buckets)
	}
	if !containsString(payload.APIInfo.StorageAPI.Allowed.Capabilities, "readFiles") ||
		!containsString(payload.APIInfo.StorageAPI.Allowed.Capabilities, "writeFiles") ||
		!containsString(payload.APIInfo.StorageAPI.Allowed.Capabilities, "writeBuckets") {
		t.Fatalf("missing expected capabilities: %+v", payload.APIInfo.StorageAPI.Allowed.Capabilities)
	}
}

func TestFCMSendScenarios(t *testing.T) {
	_, ts := newTestServer()
	defer ts.Close()

	cases := []struct {
		name       string
		token      string
		statusCode int
	}{
		{name: "ok", token: "token-ok", statusCode: http.StatusOK},
		{name: "invalid", token: "invalid-token", statusCode: http.StatusBadRequest},
		{name: "unregistered", token: "abc-unregistered-xyz", statusCode: http.StatusNotFound},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			payload := map[string]any{"message": map[string]any{"token": tc.token}}
			raw, _ := json.Marshal(payload)
			resp, err := http.Post(ts.URL+"/fcm/v1/projects/mock/messages:send", "application/json", bytes.NewReader(raw))
			if err != nil {
				t.Fatalf("request failed: %v", err)
			}
			defer resp.Body.Close()
			if resp.StatusCode != tc.statusCode {
				body, _ := io.ReadAll(resp.Body)
				t.Fatalf("expect %d, got %d: %s", tc.statusCode, resp.StatusCode, string(body))
			}
		})
	}
}

func TestIPInfo(t *testing.T) {
	_, ts := newTestServer()
	defer ts.Close()

	resp, err := http.Get(ts.URL + "/ipinfo/1.2.3.4/json?token=abc")
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expect 200, got %d", resp.StatusCode)
	}

	var payload map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode failed: %v", err)
	}
	if payload["ip"] != "1.2.3.4" {
		t.Fatalf("expect ip 1.2.3.4, got %v", payload["ip"])
	}
}

func TestObjectStorageObjectLifecycle(t *testing.T) {
	_, ts := newTestServer()
	defer ts.Close()

	key := "/chat/hello.txt"
	putResp, err := http.DefaultClient.Do(newRequest(t, http.MethodPut, ts.URL+key, strings.NewReader("hello")))
	if err != nil {
		t.Fatalf("put failed: %v", err)
	}
	putResp.Body.Close()
	if putResp.StatusCode != http.StatusOK {
		t.Fatalf("put expect 200, got %d", putResp.StatusCode)
	}

	headResp, err := http.DefaultClient.Do(newRequest(t, http.MethodHead, ts.URL+key, nil))
	if err != nil {
		t.Fatalf("head failed: %v", err)
	}
	headResp.Body.Close()
	if headResp.StatusCode != http.StatusOK {
		t.Fatalf("head expect 200, got %d", headResp.StatusCode)
	}

	getResp, err := http.Get(ts.URL + key)
	if err != nil {
		t.Fatalf("get failed: %v", err)
	}
	defer getResp.Body.Close()
	if getResp.StatusCode != http.StatusOK {
		t.Fatalf("get expect 200, got %d", getResp.StatusCode)
	}
	body, _ := io.ReadAll(getResp.Body)
	if string(body) != "hello" {
		t.Fatalf("expect hello, got %s", string(body))
	}

	delResp, err := http.DefaultClient.Do(newRequest(t, http.MethodDelete, ts.URL+key, nil))
	if err != nil {
		t.Fatalf("delete failed: %v", err)
	}
	delResp.Body.Close()
	if delResp.StatusCode != http.StatusNoContent {
		t.Fatalf("delete expect 204, got %d", delResp.StatusCode)
	}

	headAfter, err := http.DefaultClient.Do(newRequest(t, http.MethodHead, ts.URL+key, nil))
	if err != nil {
		t.Fatalf("head after delete failed: %v", err)
	}
	headAfter.Body.Close()
	if headAfter.StatusCode != http.StatusNotFound {
		t.Fatalf("head after delete expect 404, got %d", headAfter.StatusCode)
	}
}

func TestObjectStorageCreateBucketPathStyle(t *testing.T) {
	_, ts := newTestServer()
	defer ts.Close()

	createResp, err := http.DefaultClient.Do(newRequest(t, http.MethodPut, ts.URL+"/new-bucket", nil))
	if err != nil {
		t.Fatalf("create bucket failed: %v", err)
	}
	createResp.Body.Close()
	if createResp.StatusCode != http.StatusOK {
		t.Fatalf("create bucket expect 200, got %d", createResp.StatusCode)
	}

	listResp, err := http.Get(ts.URL + "/")
	if err != nil {
		t.Fatalf("list buckets failed: %v", err)
	}
	defer listResp.Body.Close()
	if listResp.StatusCode != http.StatusOK {
		t.Fatalf("list buckets expect 200, got %d", listResp.StatusCode)
	}
	body, _ := io.ReadAll(listResp.Body)
	if !strings.Contains(string(body), "<Name>new-bucket</Name>") {
		t.Fatalf("new bucket missing from list response: %s", string(body))
	}
}

func TestObjectStorageMultipartLifecycle(t *testing.T) {
	_, ts := newTestServer()
	defer ts.Close()

	key := "/chat/large.bin"
	initResp, err := http.DefaultClient.Do(newRequest(t, http.MethodPost, ts.URL+key+"?uploads", nil))
	if err != nil {
		t.Fatalf("initiate multipart failed: %v", err)
	}
	initRaw, _ := io.ReadAll(initResp.Body)
	initResp.Body.Close()
	if initResp.StatusCode != http.StatusOK {
		t.Fatalf("initiate expect 200, got %d: %s", initResp.StatusCode, string(initRaw))
	}
	uploadID := extractTag(string(initRaw), "UploadId")
	if uploadID == "" {
		t.Fatalf("upload id missing: %s", string(initRaw))
	}

	part1 := "AAA"
	part2 := "BBB"
	uploadPart := func(partNumber int, content string) {
		url := ts.URL + key + "?partNumber=" + strconv.Itoa(partNumber) + "&uploadId=" + uploadID
		resp, err := http.DefaultClient.Do(newRequest(t, http.MethodPut, url, strings.NewReader(content)))
		if err != nil {
			t.Fatalf("upload part %d failed: %v", partNumber, err)
		}
		resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("upload part %d expect 200, got %d", partNumber, resp.StatusCode)
		}
	}
	uploadPart(1, part1)
	uploadPart(2, part2)

	completeBody := `<CompleteMultipartUpload><Part><PartNumber>1</PartNumber><ETag>"e1"</ETag></Part><Part><PartNumber>2</PartNumber><ETag>"e2"</ETag></Part></CompleteMultipartUpload>`
	completeURL := ts.URL + key + "?uploadId=" + uploadID
	completeResp, err := http.DefaultClient.Do(newRequest(t, http.MethodPost, completeURL, strings.NewReader(completeBody)))
	if err != nil {
		t.Fatalf("complete multipart failed: %v", err)
	}
	completeResp.Body.Close()
	if completeResp.StatusCode != http.StatusOK {
		t.Fatalf("complete expect 200, got %d", completeResp.StatusCode)
	}

	getResp, err := http.Get(ts.URL + key)
	if err != nil {
		t.Fatalf("get object failed: %v", err)
	}
	defer getResp.Body.Close()
	if getResp.StatusCode != http.StatusOK {
		t.Fatalf("get object expect 200, got %d", getResp.StatusCode)
	}
	finalBody, _ := io.ReadAll(getResp.Body)
	if string(finalBody) != part1+part2 {
		t.Fatalf("expect %s, got %s", part1+part2, string(finalBody))
	}
}

func newRequest(t *testing.T, method, url string, body io.Reader) *http.Request {
	t.Helper()
	req, err := http.NewRequest(method, url, body)
	if err != nil {
		t.Fatalf("new request failed: %v", err)
	}
	return req
}

func extractTag(source, tag string) string {
	re := regexp.MustCompile("(?s)<" + regexp.QuoteMeta(tag) + ">(.*?)</" + regexp.QuoteMeta(tag) + ">")
	m := re.FindStringSubmatch(source)
	if len(m) < 2 {
		return ""
	}
	return strings.TrimSpace(m[1])
}

func containsString(items []string, expected string) bool {
	for _, item := range items {
		if item == expected {
			return true
		}
	}
	return false
}
