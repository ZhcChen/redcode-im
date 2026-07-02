package main

import (
	"bufio"
	"bytes"
	"context"
	crand "crypto/rand"
	"crypto/sha1"
	"crypto/tls"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	mrand "math/rand"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

var globalSeq uint64

type config struct {
	BaseURL      string
	APIRuntime   string
	Scenario     string
	Duration     time.Duration
	Warmup       time.Duration
	Interval     time.Duration
	Concurrency  int
	Timeout      time.Duration
	ReportDir    string
	ReportName   string
	RunID        string
	Password     string
	MaxErrorRate float64
	Resources    map[string]string
	WSClients    int
	WSMessages   int
	WSLingerRST  bool
}

type sample struct {
	DurationMicros int64
	Status         int
	OK             bool
	Bytes          int64
	HTTPRequests   int64
	Error          string
}

type wsConn struct {
	conn   net.Conn
	reader *bufio.Reader
}

type perfUser struct {
	ID    string
	Email string
	Token string
}

type wsJoinTarget struct {
	Token  string
	RoomID string
}

type report struct {
	Scenario              string            `json:"scenario"`
	APIRuntime            string            `json:"api_runtime"`
	BaseURL               string            `json:"base_url"`
	StartedAt             string            `json:"started_at"`
	DurationSeconds       float64           `json:"duration_seconds"`
	SetupSeconds          float64           `json:"setup_seconds"`
	SetupHTTPRequests     int64             `json:"setup_http_requests"`
	SetupBytesRead        int64             `json:"setup_bytes_read"`
	WarmupSeconds         float64           `json:"warmup_seconds"`
	RequestIntervalMillis int64             `json:"request_interval_millis"`
	Concurrency           int               `json:"concurrency"`
	TotalOperations       int               `json:"total_operations"`
	SuccessOperations     int               `json:"success_operations"`
	FailedOperations      int               `json:"failed_operations"`
	TotalHTTPRequests     int64             `json:"total_http_requests"`
	BytesRead             int64             `json:"bytes_read"`
	OperationsPerSecond   float64           `json:"operations_per_second"`
	SuccessPerSecond      float64           `json:"success_per_second"`
	HTTPRequestsPerSecond float64           `json:"http_requests_per_second"`
	ErrorRate             float64           `json:"error_rate"`
	MaxErrorRate          float64           `json:"max_error_rate"`
	LatencyMillis         latencyStats      `json:"latency_millis"`
	StatusCounts          map[string]int    `json:"status_counts"`
	ErrorCounts           map[string]int    `json:"error_counts"`
	ResourceLimits        map[string]string `json:"resource_limits"`
}

type latencyStats struct {
	Min float64 `json:"min"`
	Avg float64 `json:"avg"`
	P50 float64 `json:"p50"`
	P90 float64 `json:"p90"`
	P95 float64 `json:"p95"`
	P99 float64 `json:"p99"`
	Max float64 `json:"max"`
}

func main() {
	cfg := loadConfig()
	client := &http.Client{
		Timeout: cfg.Timeout,
		Transport: &http.Transport{
			MaxIdleConns:        cfg.Concurrency * 8,
			MaxIdleConnsPerHost: cfg.Concurrency * 8,
			IdleConnTimeout:     90 * time.Second,
			DisableCompression:  true,
			ForceAttemptHTTP2:   false,
		},
	}

	if err := waitReady(client, cfg); err != nil {
		fatalf("api not ready: %v", err)
	}

	displayConcurrency := cfg.Concurrency
	if cfg.Scenario == "ws-room-broadcast" {
		displayConcurrency = cfg.WSClients
	}

	if cfg.Warmup > 0 && !strings.HasPrefix(cfg.Scenario, "ws-") {
		fmt.Printf("warmup scenario=%s duration=%s concurrency=%d\n", cfg.Scenario, cfg.Warmup, displayConcurrency)
		_ = runLoad(client, cfg, cfg.Warmup)
	}

	fmt.Printf("load scenario=%s duration=%s concurrency=%d base_url=%s\n", cfg.Scenario, cfg.Duration, displayConcurrency, cfg.BaseURL)
	result := runLoad(client, cfg, cfg.Duration)
	if err := writeReport(cfg, result); err != nil {
		fatalf("write report: %v", err)
	}

	printSummary(result)

	if result.TotalOperations == 0 {
		fatalf("no operations completed")
	}
	if result.ErrorRate > cfg.MaxErrorRate {
		fatalf("error rate %.4f exceeds max %.4f", result.ErrorRate, cfg.MaxErrorRate)
	}
}

func loadConfig() config {
	scenario := getenv("PERF_SCENARIO", "healthz")
	runID := getenv("PERF_RUN_ID", fmt.Sprintf("%d-%04d", time.Now().Unix(), mrand.Intn(10000)))
	resources := map[string]string{}
	for _, key := range []string{
		"API_SERVICE_CPUS",
		"API_SERVICE_MEMORY",
		"POSTGRES_TEST_CPUS",
		"POSTGRES_TEST_MEMORY",
		"REDIS_TEST_CPUS",
		"REDIS_TEST_MEMORY",
		"DATABASE_MAX_CONNECTIONS",
		"DATABASE_MIN_CONNECTIONS",
		"DATABASE_ACQUIRE_TIMEOUT_SECONDS",
		"METRICS_ENABLED",
		"METRICS_SAMPLE_RATE",
		"METRICS_CHANNEL_CAPACITY",
		"METRICS_FLUSH_BATCH_SIZE",
		"WS_OUTBOUND_QUEUE_SIZE",
		"BCRYPT_COST",
		"PERF_WS_LINGER_RST",
	} {
		resources[key] = os.Getenv(key)
	}

	return config{
		BaseURL:      strings.TrimRight(getenv("API_BASE_URL", "http://api:8010"), "/"),
		APIRuntime:   getenv("API_RUNTIME", "debug"),
		Scenario:     scenario,
		Duration:     time.Duration(getenvPositiveInt("PERF_DURATION_SECONDS", 30)) * time.Second,
		Warmup:       time.Duration(getenvNonNegativeInt("PERF_WARMUP_SECONDS", 3)) * time.Second,
		Interval:     time.Duration(getenvNonNegativeInt("PERF_REQUEST_INTERVAL_MS", 0)) * time.Millisecond,
		Concurrency:  getenvPositiveInt("PERF_CONCURRENCY", 64),
		Timeout:      time.Duration(getenvPositiveInt("PERF_TIMEOUT_MS", 5000)) * time.Millisecond,
		ReportDir:    getenv("PERF_REPORT_DIR", "/reports"),
		ReportName:   getenv("PERF_REPORT_NAME", fmt.Sprintf("%s-%s.json", scenario, time.Now().Format("20060102-150405"))),
		RunID:        sanitizeRunID(runID),
		Password:     getenv("PERF_AUTH_PASSWORD", "pass123456"),
		MaxErrorRate: getenvFloat("PERF_MAX_ERROR_RATE", 0.01),
		Resources:    resources,
		WSClients:    getenvPositiveInt("PERF_WS_CLIENTS", 32),
		WSMessages:   getenvPositiveInt("PERF_WS_MESSAGES", 30),
		WSLingerRST:  getenvBool("PERF_WS_LINGER_RST", true),
	}
}

func waitReady(client *http.Client, cfg config) error {
	deadline := time.Now().Add(2 * time.Minute)
	var lastErr error
	for time.Now().Before(deadline) {
		status, _, err := doRequest(client, http.MethodGet, cfg.BaseURL+"/readyz", nil)
		if err == nil && status >= 200 && status < 300 {
			return nil
		}
		if err != nil {
			lastErr = err
		} else {
			lastErr = fmt.Errorf("readyz status %d", status)
		}
		time.Sleep(time.Second)
	}
	return lastErr
}

func runLoad(client *http.Client, cfg config, duration time.Duration) report {
	if cfg.Scenario == "ws-room-broadcast" {
		return runWSRoomBroadcast(client, cfg)
	}

	var wsConnectTokens []string
	var wsJoinTargets []wsJoinTarget
	var setupHTTPRequests int64
	var setupBytesRead int64
	var setupSeconds float64
	var setupErr error

	setupStart := time.Now()
	switch cfg.Scenario {
	case "ws-connect-ping":
		wsConnectTokens, setupBytesRead, setupHTTPRequests, setupErr = prepareWSConnectTokens(client, cfg)
	case "ws-connect-join":
		wsJoinTargets, setupBytesRead, setupHTTPRequests, setupErr = prepareWSJoinTargets(client, cfg)
	}
	if strings.HasPrefix(cfg.Scenario, "ws-") {
		cfg.Warmup = 0
	}
	if setupHTTPRequests > 0 || setupBytesRead > 0 {
		setupSeconds = time.Since(setupStart).Seconds()
	}

	if setupErr != nil {
		start := time.Now()
		return report{
			Scenario:              cfg.Scenario,
			APIRuntime:            cfg.APIRuntime,
			BaseURL:               cfg.BaseURL,
			StartedAt:             start.Format(time.RFC3339),
			DurationSeconds:       0,
			SetupSeconds:          setupSeconds,
			SetupHTTPRequests:     setupHTTPRequests,
			SetupBytesRead:        setupBytesRead,
			WarmupSeconds:         cfg.Warmup.Seconds(),
			RequestIntervalMillis: cfg.Interval.Milliseconds(),
			Concurrency:           cfg.Concurrency,
			TotalOperations:       1,
			FailedOperations:      1,
			TotalHTTPRequests:     setupHTTPRequests,
			BytesRead:             setupBytesRead,
			ErrorRate:             1,
			MaxErrorRate:          cfg.MaxErrorRate,
			StatusCounts:          map[string]int{"0": 1},
			ErrorCounts:           map[string]int{setupErr.Error(): 1},
			ResourceLimits:        cfg.Resources,
		}
	}

	start := time.Now()
	end := start.Add(duration)
	samples := make(chan sample, cfg.Concurrency*128)

	var wg sync.WaitGroup
	for workerID := 0; workerID < cfg.Concurrency; workerID++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			for time.Now().Before(end) {
				t0 := time.Now()
				status, bytesRead, httpRequests, err := executeScenario(client, cfg, id, wsConnectTokens, wsJoinTargets)
				elapsed := time.Since(t0)
				s := sample{
					DurationMicros: elapsed.Microseconds(),
					Status:         status,
					OK:             err == nil && status >= 200 && status < 300,
					Bytes:          bytesRead,
					HTTPRequests:   httpRequests,
				}
				if err != nil {
					s.Error = err.Error()
				}
				samples <- s
				if cfg.Interval > 0 {
					time.Sleep(cfg.Interval)
				}
			}
		}(workerID)
	}

	go func() {
		wg.Wait()
		close(samples)
	}()

	var durations []int64
	statusCounts := map[string]int{}
	errorCounts := map[string]int{}
	totalHTTPRequests := int64(0)
	bytesRead := int64(0)
	success := 0
	failed := 0

	for s := range samples {
		durations = append(durations, s.DurationMicros)
		if s.OK {
			success++
		} else {
			failed++
		}
		statusCounts[strconv.Itoa(s.Status)]++
		if s.Error != "" {
			errorCounts[s.Error]++
		}
		totalHTTPRequests += s.HTTPRequests
		bytesRead += s.Bytes
	}

	elapsed := time.Since(start).Seconds()
	total := success + failed
	errorRate := 0.0
	if total > 0 {
		errorRate = float64(failed) / float64(total)
	}

	return report{
		Scenario:              cfg.Scenario,
		APIRuntime:            cfg.APIRuntime,
		BaseURL:               cfg.BaseURL,
		StartedAt:             start.Format(time.RFC3339),
		DurationSeconds:       elapsed,
		SetupSeconds:          setupSeconds,
		SetupHTTPRequests:     setupHTTPRequests,
		SetupBytesRead:        setupBytesRead,
		WarmupSeconds:         cfg.Warmup.Seconds(),
		RequestIntervalMillis: cfg.Interval.Milliseconds(),
		Concurrency:           cfg.Concurrency,
		TotalOperations:       total,
		SuccessOperations:     success,
		FailedOperations:      failed,
		TotalHTTPRequests:     totalHTTPRequests,
		BytesRead:             bytesRead,
		OperationsPerSecond:   safeRate(float64(total), elapsed),
		SuccessPerSecond:      safeRate(float64(success), elapsed),
		HTTPRequestsPerSecond: safeRate(float64(totalHTTPRequests), elapsed),
		ErrorRate:             errorRate,
		MaxErrorRate:          cfg.MaxErrorRate,
		LatencyMillis:         summarizeLatency(durations),
		StatusCounts:          statusCounts,
		ErrorCounts:           errorCounts,
		ResourceLimits:        cfg.Resources,
	}
}

func executeScenario(client *http.Client, cfg config, workerID int, wsConnectTokens []string, wsJoinTargets []wsJoinTarget) (int, int64, int64, error) {
	switch cfg.Scenario {
	case "healthz":
		status, bytesRead, err := doRequest(client, http.MethodGet, cfg.BaseURL+"/healthz", nil)
		return status, bytesRead, 1, err
	case "readyz":
		status, bytesRead, err := doRequest(client, http.MethodGet, cfg.BaseURL+"/readyz", nil)
		return status, bytesRead, 1, err
	case "auth-register-login":
		return executeAuthRegisterLogin(client, cfg, workerID)
	case "ws-connect-ping":
		return executeWSConnectPing(cfg, workerID, wsConnectTokens)
	case "ws-connect-join":
		return executeWSConnectJoin(cfg, workerID, wsJoinTargets)
	default:
		return 0, 0, 0, fmt.Errorf("unknown scenario %q", cfg.Scenario)
	}
}

func executeAuthRegisterLogin(client *http.Client, cfg config, workerID int) (int, int64, int64, error) {
	seq := atomic.AddUint64(&globalSeq, 1)
	email := fmt.Sprintf("perf_%s_%d_%d@example.test", cfg.RunID, workerID, seq)
	registerBody := fmt.Sprintf(`{"email":%q,"password":%q,"nickname":"perf"}`, email, cfg.Password)
	status, bytesRead, err := doRequest(client, http.MethodPost, cfg.BaseURL+"/auth/register", []byte(registerBody))
	if err != nil || status < 200 || status >= 300 {
		if err == nil {
			err = fmt.Errorf("register status %d", status)
		}
		return status, bytesRead, 1, err
	}

	loginBody := fmt.Sprintf(`{"email":%q,"password":%q}`, email, cfg.Password)
	loginStatus, loginBytes, loginErr := doRequest(client, http.MethodPost, cfg.BaseURL+"/auth/login", []byte(loginBody))
	bytesRead += loginBytes
	if loginErr != nil {
		return loginStatus, bytesRead, 2, loginErr
	}
	if loginStatus < 200 || loginStatus >= 300 {
		return loginStatus, bytesRead, 2, fmt.Errorf("login status %d", loginStatus)
	}
	return loginStatus, bytesRead, 2, nil
}

func executeWSConnectPing(cfg config, workerID int, tokens []string) (int, int64, int64, error) {
	if len(tokens) == 0 {
		return 0, 0, 0, fmt.Errorf("no prepared ws tokens")
	}
	token := tokens[workerID%len(tokens)]
	ws, err := dialWebSocket(cfg.BaseURL, cfg.WSLingerRST)
	if err != nil {
		return 0, 0, 0, err
	}
	defer ws.close()

	if err := ws.writeText(fmt.Sprintf(`{"type":"auth","token":%q}`, token)); err != nil {
		return 0, 0, 0, err
	}
	if _, err := ws.readJSONType("authed", cfg.Timeout); err != nil {
		return 0, 0, 0, err
	}
	if err := ws.writeText(`{"type":"ping"}`); err != nil {
		return 0, 0, 0, err
	}
	if _, err := ws.readJSONType("pong", cfg.Timeout); err != nil {
		return 0, 0, 0, err
	}
	return http.StatusOK, 0, 0, nil
}

func executeWSConnectJoin(cfg config, workerID int, targets []wsJoinTarget) (int, int64, int64, error) {
	if len(targets) == 0 {
		return 0, 0, 0, fmt.Errorf("no prepared ws join targets")
	}
	target := targets[workerID%len(targets)]
	ws, err := dialWebSocket(cfg.BaseURL, cfg.WSLingerRST)
	if err != nil {
		return 0, 0, 0, err
	}
	defer ws.close()
	if err := ws.writeText(fmt.Sprintf(`{"type":"auth","token":%q}`, target.Token)); err != nil {
		return 0, 0, 0, err
	}
	if _, err := ws.readJSONType("authed", cfg.Timeout); err != nil {
		return 0, 0, 0, err
	}
	if err := ws.writeText(fmt.Sprintf(`{"type":"join","room_id":%q}`, target.RoomID)); err != nil {
		return 0, 0, 0, err
	}
	if _, err := ws.readJSONType("joined", cfg.Timeout); err != nil {
		return 0, 0, 0, err
	}
	return http.StatusOK, 0, 0, nil
}

func createPerfUser(client *http.Client, cfg config, workerID int) (perfUser, int64, int64, error) {
	seq := atomic.AddUint64(&globalSeq, 1)
	email := fmt.Sprintf("perf_ws_%s_%d_%d@example.test", cfg.RunID, workerID, seq)
	registerBody := fmt.Sprintf(`{"email":%q,"password":%q,"nickname":"perf-ws"}`, email, cfg.Password)
	status, bytesRead, err := doRequest(client, http.MethodPost, cfg.BaseURL+"/auth/register", []byte(registerBody))
	if err != nil || status < 200 || status >= 300 {
		if err == nil {
			err = fmt.Errorf("register status %d", status)
		}
		return perfUser{}, bytesRead, 1, err
	}

	loginBody := fmt.Sprintf(`{"email":%q,"password":%q}`, email, cfg.Password)
	loginStatus, loginBytes, loginResp, loginErr := doJSONRequest(client, http.MethodPost, cfg.BaseURL+"/auth/login", "", []byte(loginBody))
	bytesRead += loginBytes
	if loginErr != nil {
		return perfUser{}, bytesRead, 2, loginErr
	}
	if loginStatus < 200 || loginStatus >= 300 {
		return perfUser{}, bytesRead, 2, fmt.Errorf("login status %d", loginStatus)
	}

	token, _ := loginResp["token"].(string)
	userMap, _ := loginResp["user"].(map[string]any)
	userID, _ := userMap["id"].(string)
	if token == "" || userID == "" {
		return perfUser{}, bytesRead, 2, fmt.Errorf("login response missing token or user.id")
	}

	return perfUser{ID: userID, Email: email, Token: token}, bytesRead, 2, nil
}

func createPerfRoom(client *http.Client, cfg config, token string, memberIDs []string) (string, int64, int64, error) {
	bodyMap := map[string]any{
		"name":        fmt.Sprintf("perf room %s", cfg.RunID),
		"description": "perf",
		"room_type":   "group",
		"member_ids":  memberIDs,
	}
	body, _ := json.Marshal(bodyMap)
	status, bytesRead, resp, err := doJSONRequest(client, http.MethodPost, cfg.BaseURL+"/rooms", token, body)
	if err != nil {
		return "", bytesRead, 1, err
	}
	if status < 200 || status >= 300 {
		return "", bytesRead, 1, fmt.Errorf("create room status %d", status)
	}
	roomMap, _ := resp["room"].(map[string]any)
	roomID, _ := roomMap["id"].(string)
	if roomID == "" {
		return "", bytesRead, 1, fmt.Errorf("create room response missing room.id")
	}
	return roomID, bytesRead, 1, nil
}

func prepareWSConnectTokens(client *http.Client, cfg config) ([]string, int64, int64, error) {
	count := cfg.Concurrency
	if count < 1 {
		count = 1
	}
	tokens := make([]string, 0, count)
	var bytesRead int64
	var httpRequests int64
	for i := 0; i < count; i++ {
		user, n, reqs, err := createPerfUser(client, cfg, i)
		bytesRead += n
		httpRequests += reqs
		if err != nil {
			return nil, bytesRead, httpRequests, err
		}
		tokens = append(tokens, user.Token)
	}
	return tokens, bytesRead, httpRequests, nil
}

func prepareWSJoinTargets(client *http.Client, cfg config) ([]wsJoinTarget, int64, int64, error) {
	count := cfg.Concurrency
	if count < 1 {
		count = 1
	}
	targets := make([]wsJoinTarget, 0, count)
	var bytesRead int64
	var httpRequests int64
	for i := 0; i < count; i++ {
		owner, n, reqs, err := createPerfUser(client, cfg, i)
		bytesRead += n
		httpRequests += reqs
		if err != nil {
			return nil, bytesRead, httpRequests, err
		}
		member, n, reqs, err := createPerfUser(client, cfg, i+10_000)
		bytesRead += n
		httpRequests += reqs
		if err != nil {
			return nil, bytesRead, httpRequests, err
		}
		roomID, n, reqs, err := createPerfRoom(client, cfg, owner.Token, []string{member.ID})
		bytesRead += n
		httpRequests += reqs
		if err != nil {
			return nil, bytesRead, httpRequests, err
		}
		targets = append(targets, wsJoinTarget{Token: member.Token, RoomID: roomID})
	}
	return targets, bytesRead, httpRequests, nil
}

func runWSRoomBroadcast(client *http.Client, cfg config) report {
	setupStart := time.Now()
	statusCounts := map[string]int{}
	errorCounts := map[string]int{}
	var durations []int64
	var bytesRead int64
	var httpRequests int64
	var setupBytesRead int64
	var setupHTTPRequests int64

	fail := func(err error) report {
		setupSeconds := time.Since(setupStart).Seconds()
		statusCounts["0"]++
		errorCounts[err.Error()]++
		return report{
			Scenario:              cfg.Scenario,
			APIRuntime:            cfg.APIRuntime,
			BaseURL:               cfg.BaseURL,
			StartedAt:             time.Now().Format(time.RFC3339),
			DurationSeconds:       0,
			SetupSeconds:          setupSeconds,
			SetupHTTPRequests:     setupHTTPRequests,
			SetupBytesRead:        setupBytesRead,
			WarmupSeconds:         cfg.Warmup.Seconds(),
			RequestIntervalMillis: cfg.Interval.Milliseconds(),
			Concurrency:           cfg.WSClients,
			TotalOperations:       1,
			FailedOperations:      1,
			TotalHTTPRequests:     httpRequests,
			BytesRead:             bytesRead,
			ErrorRate:             1,
			MaxErrorRate:          cfg.MaxErrorRate,
			LatencyMillis:         summarizeLatency(durations),
			StatusCounts:          statusCounts,
			ErrorCounts:           errorCounts,
			ResourceLimits:        cfg.Resources,
		}
	}

	owner, n, reqs, err := createPerfUser(client, cfg, 0)
	setupBytesRead += n
	setupHTTPRequests += reqs
	if err != nil {
		return fail(err)
	}

	memberCount := cfg.WSClients
	if memberCount < 1 {
		memberCount = 1
	}
	members := make([]perfUser, 0, memberCount)
	memberIDs := make([]string, 0, memberCount)
	for i := 0; i < memberCount; i++ {
		user, n, reqs, err := createPerfUser(client, cfg, i+1)
		setupBytesRead += n
		setupHTTPRequests += reqs
		if err != nil {
			return fail(err)
		}
		members = append(members, user)
		memberIDs = append(memberIDs, user.ID)
	}

	roomID, n, reqs, err := createPerfRoom(client, cfg, owner.Token, memberIDs)
	setupBytesRead += n
	setupHTTPRequests += reqs
	if err != nil {
		return fail(err)
	}

	wsConns := make([]*wsConn, 0, len(members))
	for i, member := range members {
		ws, err := dialWebSocket(cfg.BaseURL, cfg.WSLingerRST)
		if err != nil {
			return fail(fmt.Errorf("ws client %d dial: %w", i, err))
		}
		defer ws.close()
		if err := ws.writeText(fmt.Sprintf(`{"type":"auth","token":%q}`, member.Token)); err != nil {
			return fail(fmt.Errorf("ws client %d auth write: %w", i, err))
		}
		if _, err := ws.readJSONType("authed", cfg.Timeout); err != nil {
			return fail(fmt.Errorf("ws client %d authed: %w", i, err))
		}
		if err := ws.writeText(fmt.Sprintf(`{"type":"join","room_id":%q}`, roomID)); err != nil {
			return fail(fmt.Errorf("ws client %d join write: %w", i, err))
		}
		if _, err := ws.readJSONType("joined", cfg.Timeout); err != nil {
			return fail(fmt.Errorf("ws client %d joined: %w", i, err))
		}
		wsConns = append(wsConns, ws)
	}

	if cfg.Warmup > 0 {
		time.Sleep(cfg.Warmup)
	}

	setupSeconds := time.Since(setupStart).Seconds()
	start := time.Now()
	totalExpected := cfg.WSMessages * len(wsConns)
	readCh := make(chan sample, totalExpected)
	var readers sync.WaitGroup
	for i, ws := range wsConns {
		readTarget := cfg.WSMessages
		readTimeout := cfg.Timeout + cfg.Duration
		readers.Add(1)
		go func(clientID int, conn *wsConn) {
			defer readers.Done()
			for received := 0; received < readTarget; received++ {
				t0 := time.Now()
				_, err := conn.readJSONType("message", readTimeout)
				elapsed := time.Since(t0)
				s := sample{DurationMicros: elapsed.Microseconds(), Status: http.StatusOK, OK: err == nil}
				if err != nil {
					s.Status = 0
					s.Error = fmt.Sprintf("client %d read message: %v", clientID, err)
				}
				readCh <- s
				if err != nil {
					return
				}
			}
		}(i, ws)
	}

	for i := 0; i < cfg.WSMessages; i++ {
		t0 := time.Now()
		body := fmt.Sprintf(`{"content":"ws perf %s %d"}`, cfg.RunID, i)
		status, n, err := doAuthedRequest(client, http.MethodPost, fmt.Sprintf("%s/rooms/%s/messages", cfg.BaseURL, roomID), owner.Token, []byte(body))
		bytesRead += n
		httpRequests++
		durations = append(durations, time.Since(t0).Microseconds())
		statusCounts[strconv.Itoa(status)]++
		if err != nil {
			errorCounts[err.Error()]++
			return fail(fmt.Errorf("send message %d: %w", i, err))
		}
	}

	go func() {
		readers.Wait()
		close(readCh)
	}()

	success := 0
	failed := 0
	for s := range readCh {
		durations = append(durations, s.DurationMicros)
		statusCounts[strconv.Itoa(s.Status)]++
		if s.OK {
			success++
		} else {
			failed++
			if s.Error != "" {
				errorCounts[s.Error]++
			}
		}
	}

	elapsed := time.Since(start).Seconds()
	total := success + failed
	errorRate := 0.0
	if total > 0 {
		errorRate = float64(failed) / float64(total)
	}

	return report{
		Scenario:              cfg.Scenario,
		APIRuntime:            cfg.APIRuntime,
		BaseURL:               cfg.BaseURL,
		StartedAt:             start.Format(time.RFC3339),
		DurationSeconds:       elapsed,
		SetupSeconds:          setupSeconds,
		SetupHTTPRequests:     setupHTTPRequests,
		SetupBytesRead:        setupBytesRead,
		WarmupSeconds:         cfg.Warmup.Seconds(),
		RequestIntervalMillis: cfg.Interval.Milliseconds(),
		Concurrency:           len(wsConns),
		TotalOperations:       total,
		SuccessOperations:     success,
		FailedOperations:      failed,
		TotalHTTPRequests:     httpRequests,
		BytesRead:             bytesRead,
		OperationsPerSecond:   safeRate(float64(total), elapsed),
		SuccessPerSecond:      safeRate(float64(success), elapsed),
		HTTPRequestsPerSecond: safeRate(float64(httpRequests), elapsed),
		ErrorRate:             errorRate,
		MaxErrorRate:          cfg.MaxErrorRate,
		LatencyMillis:         summarizeLatency(durations),
		StatusCounts:          statusCounts,
		ErrorCounts:           errorCounts,
		ResourceLimits:        cfg.Resources,
	}
}

func doRequest(client *http.Client, method string, url string, body []byte) (int, int64, error) {
	return doAuthedRequest(client, method, url, "", body)
}

func doAuthedRequest(client *http.Client, method string, url string, token string, body []byte) (int, int64, error) {
	var reader io.Reader
	if body != nil {
		reader = bytes.NewReader(body)
	}

	ctx, cancel := context.WithTimeout(context.Background(), client.Timeout)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, method, url, reader)
	if err != nil {
		return 0, 0, err
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := client.Do(req)
	if err != nil {
		return 0, 0, err
	}
	defer resp.Body.Close()

	n, readErr := io.Copy(io.Discard, resp.Body)
	if readErr != nil {
		return resp.StatusCode, n, readErr
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return resp.StatusCode, n, fmt.Errorf("status %d", resp.StatusCode)
	}
	return resp.StatusCode, n, nil
}

func doJSONRequest(client *http.Client, method string, url string, token string, body []byte) (int, int64, map[string]any, error) {
	var reader io.Reader
	if body != nil {
		reader = bytes.NewReader(body)
	}

	ctx, cancel := context.WithTimeout(context.Background(), client.Timeout)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, method, url, reader)
	if err != nil {
		return 0, 0, nil, err
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := client.Do(req)
	if err != nil {
		return 0, 0, nil, err
	}
	defer resp.Body.Close()

	data, readErr := io.ReadAll(resp.Body)
	bytesRead := int64(len(data))
	if readErr != nil {
		return resp.StatusCode, bytesRead, nil, readErr
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return resp.StatusCode, bytesRead, nil, fmt.Errorf("status %d body %s", resp.StatusCode, truncateString(string(data), 200))
	}
	var out map[string]any
	if err := json.Unmarshal(data, &out); err != nil {
		return resp.StatusCode, bytesRead, nil, err
	}
	return resp.StatusCode, bytesRead, out, nil
}

func dialWebSocket(baseURL string, lingerRST bool) (*wsConn, error) {
	wsURL, err := websocketURL(baseURL)
	if err != nil {
		return nil, err
	}
	u, err := url.Parse(wsURL)
	if err != nil {
		return nil, err
	}
	host := u.Host
	if !strings.Contains(host, ":") {
		if u.Scheme == "wss" {
			host += ":443"
		} else {
			host += ":80"
		}
	}

	dialer := net.Dialer{Timeout: 10 * time.Second}
	var conn net.Conn
	if u.Scheme == "wss" {
		conn, err = tls.DialWithDialer(&dialer, "tcp", host, &tls.Config{ServerName: u.Hostname()})
	} else {
		conn, err = dialer.Dial("tcp", host)
	}
	if err != nil {
		return nil, err
	}
	if lingerRST {
		if tcpConn, ok := conn.(*net.TCPConn); ok {
			_ = tcpConn.SetLinger(0)
		}
	}

	keyBytes := make([]byte, 16)
	if _, err := crand.Read(keyBytes); err != nil {
		_ = conn.Close()
		return nil, err
	}
	key := base64.StdEncoding.EncodeToString(keyBytes)
	path := u.RequestURI()
	if path == "" {
		path = "/"
	}
	req := fmt.Sprintf("GET %s HTTP/1.1\r\nHost: %s\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\n\r\n", path, u.Host, key)
	if _, err := conn.Write([]byte(req)); err != nil {
		_ = conn.Close()
		return nil, err
	}

	reader := bufio.NewReader(conn)
	resp, err := http.ReadResponse(reader, &http.Request{Method: http.MethodGet})
	if err != nil {
		_ = conn.Close()
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusSwitchingProtocols {
		_ = conn.Close()
		return nil, fmt.Errorf("websocket upgrade status %d", resp.StatusCode)
	}
	if !validWebSocketAccept(key, resp.Header.Get("Sec-WebSocket-Accept")) {
		_ = conn.Close()
		return nil, fmt.Errorf("invalid websocket accept")
	}
	return &wsConn{conn: conn, reader: reader}, nil
}

func websocketURL(baseURL string) (string, error) {
	u, err := url.Parse(baseURL)
	if err != nil {
		return "", err
	}
	switch u.Scheme {
	case "https":
		u.Scheme = "wss"
	default:
		u.Scheme = "ws"
	}
	u.Path = "/ws"
	q := u.Query()
	q.Set("format", "json")
	u.RawQuery = q.Encode()
	return u.String(), nil
}

func validWebSocketAccept(key string, got string) bool {
	const magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
	sum := sha1.Sum([]byte(key + magic))
	want := base64.StdEncoding.EncodeToString(sum[:])
	return got == want
}

func (w *wsConn) close() {
	_ = w.writeClose()
	_ = w.conn.Close()
}

func (w *wsConn) writeText(payload string) error {
	return w.writeFrame(0x1, []byte(payload))
}

func (w *wsConn) writeClose() error {
	return w.writeFrame(0x8, []byte{})
}

func (w *wsConn) writeFrame(opcode byte, payload []byte) error {
	header := []byte{0x80 | opcode}
	maskBit := byte(0x80)
	length := len(payload)
	switch {
	case length < 126:
		header = append(header, maskBit|byte(length))
	case length <= 0xffff:
		header = append(header, maskBit|126, byte(length>>8), byte(length))
	default:
		buf := make([]byte, 8)
		binary.BigEndian.PutUint64(buf, uint64(length))
		header = append(header, maskBit|127)
		header = append(header, buf...)
	}
	mask := make([]byte, 4)
	if _, err := crand.Read(mask); err != nil {
		return err
	}
	header = append(header, mask...)
	masked := make([]byte, length)
	for i, b := range payload {
		masked[i] = b ^ mask[i%4]
	}
	if _, err := w.conn.Write(header); err != nil {
		return err
	}
	_, err := w.conn.Write(masked)
	return err
}

func (w *wsConn) readJSONType(expected string, timeout time.Duration) (map[string]any, error) {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		remaining := time.Until(deadline)
		if remaining <= 0 {
			break
		}
		_ = w.conn.SetReadDeadline(time.Now().Add(remaining))
		opcode, payload, err := w.readFrame()
		if err != nil {
			return nil, err
		}
		switch opcode {
		case 0x1:
			var obj map[string]any
			if err := json.Unmarshal(payload, &obj); err != nil {
				return nil, err
			}
			if typ, _ := obj["type"].(string); typ == expected {
				return obj, nil
			}
		case 0x8:
			return nil, fmt.Errorf("websocket closed")
		case 0x9:
			_ = w.writeFrame(0xA, payload)
		}
	}
	return nil, fmt.Errorf("timeout waiting for ws event %q", expected)
}

func (w *wsConn) readFrame() (byte, []byte, error) {
	first, err := w.reader.ReadByte()
	if err != nil {
		return 0, nil, err
	}
	second, err := w.reader.ReadByte()
	if err != nil {
		return 0, nil, err
	}
	opcode := first & 0x0f
	masked := second&0x80 != 0
	length := uint64(second & 0x7f)
	switch length {
	case 126:
		var buf [2]byte
		if _, err := io.ReadFull(w.reader, buf[:]); err != nil {
			return 0, nil, err
		}
		length = uint64(binary.BigEndian.Uint16(buf[:]))
	case 127:
		var buf [8]byte
		if _, err := io.ReadFull(w.reader, buf[:]); err != nil {
			return 0, nil, err
		}
		length = binary.BigEndian.Uint64(buf[:])
	}
	var mask [4]byte
	if masked {
		if _, err := io.ReadFull(w.reader, mask[:]); err != nil {
			return 0, nil, err
		}
	}
	if length > 16*1024*1024 {
		return 0, nil, fmt.Errorf("websocket frame too large: %d", length)
	}
	payload := make([]byte, int(length))
	if _, err := io.ReadFull(w.reader, payload); err != nil {
		return 0, nil, err
	}
	if masked {
		for i := range payload {
			payload[i] ^= mask[i%4]
		}
	}
	return opcode, payload, nil
}

func summarizeLatency(values []int64) latencyStats {
	if len(values) == 0 {
		return latencyStats{}
	}
	sort.Slice(values, func(i, j int) bool { return values[i] < values[j] })

	var sum int64
	for _, v := range values {
		sum += v
	}

	return latencyStats{
		Min: microsToMillis(values[0]),
		Avg: microsToMillis(sum / int64(len(values))),
		P50: microsToMillis(percentile(values, 0.50)),
		P90: microsToMillis(percentile(values, 0.90)),
		P95: microsToMillis(percentile(values, 0.95)),
		P99: microsToMillis(percentile(values, 0.99)),
		Max: microsToMillis(values[len(values)-1]),
	}
}

func percentile(values []int64, p float64) int64 {
	if len(values) == 0 {
		return 0
	}
	index := int(math.Ceil(float64(len(values))*p)) - 1
	if index < 0 {
		index = 0
	}
	if index >= len(values) {
		index = len(values) - 1
	}
	return values[index]
}

func writeReport(cfg config, r report) error {
	if err := os.MkdirAll(cfg.ReportDir, 0o755); err != nil {
		return err
	}
	path := filepath.Join(cfg.ReportDir, cfg.ReportName)
	data, err := json.MarshalIndent(r, "", "  ")
	if err != nil {
		return err
	}
	if err := os.WriteFile(path, append(data, '\n'), 0o644); err != nil {
		return err
	}
	fmt.Printf("report=%s\n", path)
	return nil
}

func printSummary(r report) {
	fmt.Printf("summary scenario=%s ops=%d success=%d failed=%d error_rate=%.4f ops/s=%.2f http_req/s=%.2f p95=%.2fms p99=%.2fms\n",
		r.Scenario,
		r.TotalOperations,
		r.SuccessOperations,
		r.FailedOperations,
		r.ErrorRate,
		r.OperationsPerSecond,
		r.HTTPRequestsPerSecond,
		r.LatencyMillis.P95,
		r.LatencyMillis.P99,
	)
}

func getenv(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}

func getenvPositiveInt(key string, fallback int) int {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	n, err := strconv.Atoi(value)
	if err != nil || n <= 0 {
		return fallback
	}
	return n
}

func getenvNonNegativeInt(key string, fallback int) int {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	n, err := strconv.Atoi(value)
	if err != nil || n < 0 {
		return fallback
	}
	return n
}

func getenvFloat(key string, fallback float64) float64 {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	n, err := strconv.ParseFloat(value, 64)
	if err != nil || n < 0 {
		return fallback
	}
	return n
}

func getenvBool(key string, fallback bool) bool {
	value := strings.ToLower(strings.TrimSpace(os.Getenv(key)))
	switch value {
	case "1", "true", "yes", "y", "on":
		return true
	case "0", "false", "no", "n", "off":
		return false
	default:
		return fallback
	}
}

func sanitizeRunID(value string) string {
	value = strings.ToLower(value)
	replacer := strings.NewReplacer("/", "-", "\\", "-", ":", "-", " ", "-")
	value = replacer.Replace(value)
	if value == "" {
		return "run"
	}
	return value
}

func safeRate(count float64, seconds float64) float64 {
	if seconds <= 0 {
		return 0
	}
	return count / seconds
}

func microsToMillis(value int64) float64 {
	return float64(value) / 1000
}

func truncateString(value string, max int) string {
	if max <= 0 || len(value) <= max {
		return value
	}
	return value[:max] + "..."
}

func fatalf(format string, args ...any) {
	err := fmt.Errorf(format, args...)
	if errors.Is(err, context.Canceled) {
		os.Exit(1)
	}
	fmt.Fprintf(os.Stderr, "error: %v\n", err)
	os.Exit(1)
}
