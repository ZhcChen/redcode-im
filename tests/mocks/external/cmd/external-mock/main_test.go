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

	jwt "github.com/golang-jwt/jwt/v5"
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

func TestJWKSEndpoints(t *testing.T) {
	s, ts := newTestServer()
	defer ts.Close()

	tests := []struct {
		name   string
		path   string
		expect string
	}{
		{name: "google", path: "/google/oauth2/v3/certs", expect: s.googleKid},
		{name: "apple", path: "/apple/auth/keys", expect: s.appleKid},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			resp, err := http.Get(ts.URL + tc.path)
			if err != nil {
				t.Fatalf("request failed: %v", err)
			}
			defer resp.Body.Close()
			if resp.StatusCode != http.StatusOK {
				t.Fatalf("expect 200, got %d", resp.StatusCode)
			}

			var payload struct {
				Keys []struct {
					Kid string `json:"kid"`
				} `json:"keys"`
			}
			if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
				t.Fatalf("decode jwks failed: %v", err)
			}
			if len(payload.Keys) == 0 {
				t.Fatalf("jwks keys empty")
			}
			if payload.Keys[0].Kid != tc.expect {
				t.Fatalf("expect kid=%s, got %s", tc.expect, payload.Keys[0].Kid)
			}
		})
	}
}

func TestCreateGoogleIDToken(t *testing.T) {
	s, ts := newTestServer()
	defer ts.Close()

	body := strings.NewReader(`{"sub":"u1","email":"u1@example.com","aud":"mock-google-client-id"}`)
	resp, err := http.Post(ts.URL+"/mock/google/id-token", "application/json", body)
	if err != nil {
		t.Fatalf("request failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		raw, _ := io.ReadAll(resp.Body)
		t.Fatalf("expect 200, got %d: %s", resp.StatusCode, string(raw))
	}

	var payload struct {
		IDToken string `json:"id_token"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		t.Fatalf("decode id token failed: %v", err)
	}
	if payload.IDToken == "" {
		t.Fatalf("id token is empty")
	}

	tok, err := jwt.Parse(payload.IDToken, func(token *jwt.Token) (any, error) {
		return &s.googleKey.PublicKey, nil
	})
	if err != nil {
		t.Fatalf("verify token failed: %v", err)
	}
	if !tok.Valid {
		t.Fatalf("token is invalid")
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

func TestTencentCI(t *testing.T) {
	_, ts := newTestServer()
	defer ts.Close()

	submitBody := `<Request><Input><Object>chat/violation-image.png</Object></Input></Request>`
	resp, err := http.Post(ts.URL+"/tencentci/image/auditing", "application/xml", strings.NewReader(submitBody))
	if err != nil {
		t.Fatalf("submit request failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		raw, _ := io.ReadAll(resp.Body)
		t.Fatalf("submit expect 200, got %d: %s", resp.StatusCode, string(raw))
	}
	body, _ := io.ReadAll(resp.Body)
	jobID := extractTag(string(body), "JobId")
	if jobID == "" {
		t.Fatalf("job id is empty, body=%s", string(body))
	}

	queryResp, err := http.Get(ts.URL + "/tencentci/image/auditing/" + jobID)
	if err != nil {
		t.Fatalf("query request failed: %v", err)
	}
	defer queryResp.Body.Close()
	if queryResp.StatusCode != http.StatusOK {
		raw, _ := io.ReadAll(queryResp.Body)
		t.Fatalf("query expect 200, got %d: %s", queryResp.StatusCode, string(raw))
	}
	queryBody, _ := io.ReadAll(queryResp.Body)
	if extractTag(string(queryBody), "Result") != "1" {
		t.Fatalf("expect result=1, body=%s", string(queryBody))
	}
}

func TestCOSObjectLifecycle(t *testing.T) {
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

func TestCOSMultipartLifecycle(t *testing.T) {
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

func TestCOSCORS(t *testing.T) {
	_, ts := newTestServer()
	defer ts.Close()

	getBefore, err := http.DefaultClient.Do(newRequest(t, http.MethodGet, ts.URL+"/?cors", nil))
	if err != nil {
		t.Fatalf("cors get before set failed: %v", err)
	}
	getBefore.Body.Close()
	if getBefore.StatusCode != http.StatusNotFound {
		t.Fatalf("expect 404 before set, got %d", getBefore.StatusCode)
	}

	corsXML := `<CORSConfiguration><CORSRule><AllowedOrigin>*</AllowedOrigin></CORSRule></CORSConfiguration>`
	putResp, err := http.DefaultClient.Do(newRequest(t, http.MethodPut, ts.URL+"/?cors", strings.NewReader(corsXML)))
	if err != nil {
		t.Fatalf("cors put failed: %v", err)
	}
	putResp.Body.Close()
	if putResp.StatusCode != http.StatusOK {
		t.Fatalf("expect 200, got %d", putResp.StatusCode)
	}

	getAfter, err := http.DefaultClient.Do(newRequest(t, http.MethodGet, ts.URL+"/?cors", nil))
	if err != nil {
		t.Fatalf("cors get after set failed: %v", err)
	}
	defer getAfter.Body.Close()
	if getAfter.StatusCode != http.StatusOK {
		t.Fatalf("expect 200, got %d", getAfter.StatusCode)
	}
	body, _ := io.ReadAll(getAfter.Body)
	if !strings.Contains(string(body), "AllowedOrigin") {
		t.Fatalf("unexpected cors body: %s", string(body))
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
