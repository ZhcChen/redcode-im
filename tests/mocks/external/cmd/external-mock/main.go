package main

import (
	"crypto/md5"
	"crypto/rand"
	"crypto/rsa"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"io"
	"log"
	"math/big"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	jwt "github.com/golang-jwt/jwt/v5"
)

type objectEntry struct {
	Body        []byte
	ContentType string
	ETag        string
}

type multipartSession struct {
	Key   string
	Parts map[int][]byte
}

type ciJob struct {
	Kind      string
	ObjectKey string
	Result    int
	Label     string
}

type createIDTokenRequest struct {
	Sub   string `json:"sub"`
	Email string `json:"email"`
	Name  string `json:"name"`
	Aud   string `json:"aud"`
	Exp   int64  `json:"exp"`
}

type mockServer struct {
	mu sync.RWMutex

	objects map[string]objectEntry
	uploads map[string]*multipartSession
	ciJobs  map[string]ciJob

	corsXML string
	buckets map[string]time.Time

	googleKey *rsa.PrivateKey
	appleKey  *rsa.PrivateKey
	googleKid string
	appleKid  string
}

func newMockServer() *mockServer {
	googleKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		panic(fmt.Sprintf("generate google rsa key failed: %v", err))
	}
	appleKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		panic(fmt.Sprintf("generate apple rsa key failed: %v", err))
	}

	return &mockServer{
		objects:   make(map[string]objectEntry),
		uploads:   make(map[string]*multipartSession),
		ciJobs:    make(map[string]ciJob),
		corsXML:   "",
		buckets:   map[string]time.Time{"mock-bucket": time.Now().UTC()},
		googleKey: googleKey,
		appleKey:  appleKey,
		googleKid: "mock-google-kid",
		appleKid:  "mock-apple-kid",
	}
}

func main() {
	addr := envOrDefault("EXTERNAL_MOCK_ADDR", ":19080")
	server := newMockServer()

	mux := http.NewServeMux()
	mux.HandleFunc("/", server.handle)

	log.Printf("[external-mock] listening on %s", addr)
	if err := http.ListenAndServe(addr, logRequest(mux)); err != nil {
		log.Fatalf("[external-mock] server stopped: %v", err)
	}
}

func logRequest(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("[external-mock] %s %s (%s)", r.Method, r.URL.String(), time.Since(start).Truncate(time.Millisecond))
	})
}

func (s *mockServer) handle(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Path
	switch {
	case r.Method == http.MethodGet && path == "/healthz":
		writeJSON(w, http.StatusOK, map[string]any{"ok": true})
	case r.Method == http.MethodGet && path == "/google/oauth2/v3/certs":
		s.handleGoogleJWKS(w)
	case r.Method == http.MethodGet && path == "/apple/auth/keys":
		s.handleAppleJWKS(w)
	case r.Method == http.MethodPost && path == "/google/oauth2/token":
		s.handleGoogleOAuthToken(w)
	case r.Method == http.MethodPost && path == "/mock/google/id-token":
		s.handleCreateGoogleIDToken(w, r)
	case r.Method == http.MethodPost && path == "/mock/apple/id-token":
		s.handleCreateAppleIDToken(w, r)
	case strings.HasPrefix(path, "/fcm/v1/projects/") && strings.HasSuffix(path, "/messages:send") && r.Method == http.MethodPost:
		s.handleFCMSend(w, r)
	case strings.HasPrefix(path, "/ipinfo/") && strings.HasSuffix(path, "/json") && r.Method == http.MethodGet:
		s.handleIPInfo(w, r)
	case strings.HasPrefix(path, "/tencentci/"):
		s.handleTencentCI(w, r)
	default:
		s.handleCOS(w, r)
	}
}

func (s *mockServer) handleGoogleJWKS(w http.ResponseWriter) {
	jwk := buildJWK(s.googleKey.PublicKey, s.googleKid)
	writeJSON(w, http.StatusOK, map[string]any{"keys": []any{jwk}})
}

func (s *mockServer) handleAppleJWKS(w http.ResponseWriter) {
	jwk := buildJWK(s.appleKey.PublicKey, s.appleKid)
	writeJSON(w, http.StatusOK, map[string]any{"keys": []any{jwk}})
}

func (s *mockServer) handleGoogleOAuthToken(w http.ResponseWriter) {
	writeJSON(w, http.StatusOK, map[string]any{
		"access_token": "mock-access-token",
		"expires_in":   3600,
		"token_type":   "Bearer",
	})
}

func (s *mockServer) handleCreateGoogleIDToken(w http.ResponseWriter, r *http.Request) {
	var req createIDTokenRequest
	_ = json.NewDecoder(r.Body).Decode(&req)
	if strings.TrimSpace(req.Sub) == "" {
		req.Sub = "google-user-001"
	}
	if strings.TrimSpace(req.Email) == "" {
		req.Email = "google_user_001@example.com"
	}
	if strings.TrimSpace(req.Name) == "" {
		req.Name = "Google Mock User"
	}
	if strings.TrimSpace(req.Aud) == "" {
		req.Aud = envOrDefault("MOCK_GOOGLE_OAUTH_CLIENT_ID", "mock-google-client-id")
	}
	if req.Exp <= 0 {
		req.Exp = time.Now().Add(30 * time.Minute).Unix()
	}

	claims := jwt.MapClaims{
		"sub":   req.Sub,
		"email": req.Email,
		"name":  req.Name,
		"iss":   "https://accounts.google.com",
		"aud":   req.Aud,
		"iat":   time.Now().Unix(),
		"exp":   req.Exp,
	}
	token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	token.Header["kid"] = s.googleKid
	signed, err := token.SignedString(s.googleKey)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]any{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"id_token": signed})
}

func (s *mockServer) handleCreateAppleIDToken(w http.ResponseWriter, r *http.Request) {
	var req createIDTokenRequest
	_ = json.NewDecoder(r.Body).Decode(&req)
	if strings.TrimSpace(req.Sub) == "" {
		req.Sub = "apple-user-001"
	}
	if strings.TrimSpace(req.Email) == "" {
		req.Email = "apple_user_001@example.com"
	}
	if strings.TrimSpace(req.Aud) == "" {
		req.Aud = envOrDefault("MOCK_APPLE_OAUTH_CLIENT_ID", "mock-apple-client-id")
	}
	if req.Exp <= 0 {
		req.Exp = time.Now().Add(30 * time.Minute).Unix()
	}

	claims := jwt.MapClaims{
		"sub":   req.Sub,
		"email": req.Email,
		"iss":   "https://appleid.apple.com",
		"aud":   req.Aud,
		"iat":   time.Now().Unix(),
		"exp":   req.Exp,
	}
	token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	token.Header["kid"] = s.appleKid
	signed, err := token.SignedString(s.appleKey)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]any{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"id_token": signed})
}

func (s *mockServer) handleFCMSend(w http.ResponseWriter, r *http.Request) {
	var payload map[string]any
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]any{"error": map[string]any{"message": "invalid json"}})
		return
	}

	token, _ := digMapString(payload, "message", "token")
	if strings.Contains(strings.ToLower(token), "unregistered") {
		writeJSON(w, http.StatusNotFound, map[string]any{
			"error": map[string]any{
				"status":  "NOT_FOUND",
				"message": "Requested entity was not found.",
				"details": []any{map[string]any{"errorCode": "UNREGISTERED"}},
			},
		})
		return
	}
	if strings.Contains(strings.ToLower(token), "invalid") {
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"error": map[string]any{
				"status":  "INVALID_ARGUMENT",
				"message": "The registration token is not a valid FCM registration token",
			},
		})
		return
	}

	name := fmt.Sprintf("%s/messages/mock-%d", strings.TrimPrefix(r.URL.Path, "/fcm/v1/projects/"), time.Now().UnixNano())
	writeJSON(w, http.StatusOK, map[string]any{"name": name})
}

func (s *mockServer) handleIPInfo(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/ipinfo/"), "/")
	if len(parts) < 2 || parts[1] != "json" {
		http.NotFound(w, r)
		return
	}
	ip := parts[0]
	writeJSON(w, http.StatusOK, map[string]any{
		"ip":       ip,
		"hostname": "mock-host.local",
		"city":     "Shanghai",
		"region":   "Shanghai",
		"country":  "CN",
		"loc":      "31.2304,121.4737",
		"org":      "Mock ISP",
		"postal":   "200000",
		"timezone": "Asia/Shanghai",
	})
}

func (s *mockServer) handleTencentCI(w http.ResponseWriter, r *http.Request) {
	path := strings.TrimPrefix(r.URL.Path, "/tencentci")
	parts := strings.Split(strings.Trim(path, "/"), "/")
	if len(parts) < 2 || parts[1] != "auditing" {
		http.NotFound(w, r)
		return
	}
	kind := parts[0]

	if r.Method == http.MethodPost && len(parts) == 2 {
		body, _ := io.ReadAll(r.Body)
		objectKey := extractXMLValue(string(body), "Object")
		if strings.TrimSpace(objectKey) == "" {
			objectKey = "unknown"
		}

		result := 0
		label := ""
		lowerKey := strings.ToLower(objectKey)
		if strings.Contains(lowerKey, "violation") {
			result = 1
			label = "Porn"
		} else if strings.Contains(lowerKey, "review") {
			result = 2
			label = "Ads"
		}

		jobID := fmt.Sprintf("job-%d", time.Now().UnixNano())
		s.mu.Lock()
		s.ciJobs[jobID] = ciJob{Kind: kind, ObjectKey: objectKey, Result: result, Label: label}
		s.mu.Unlock()

		xmlResp := fmt.Sprintf(`<Response><JobsDetail><Code>Success</Code><Message></Message><JobId>%s</JobId><State>Success</State></JobsDetail></Response>`, xmlEscape(jobID))
		writeXML(w, http.StatusOK, xmlResp)
		return
	}

	if r.Method == http.MethodGet && len(parts) == 3 {
		jobID := parts[2]
		s.mu.RLock()
		job, ok := s.ciJobs[jobID]
		s.mu.RUnlock()
		if !ok {
			writeXML(w, http.StatusNotFound, `<Response><JobsDetail><Code>NoSuchJob</Code><Message>job not found</Message></JobsDetail></Response>`)
			return
		}

		xmlResp := fmt.Sprintf(
			`<Response><JobsDetail><Code>Success</Code><Message></Message><JobId>%s</JobId><State>Success</State><Result>%d</Result><Label>%s</Label></JobsDetail></Response>`,
			xmlEscape(jobID),
			job.Result,
			xmlEscape(job.Label),
		)
		writeXML(w, http.StatusOK, xmlResp)
		return
	}

	http.NotFound(w, r)
}

func (s *mockServer) handleCOS(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()
	path := r.URL.Path

	if path == "/" {
		if _, ok := query["cors"]; ok {
			s.handleCOSCors(w, r)
			return
		}
		s.handleCOSBucketRoot(w, r)
		return
	}

	key, err := decodeObjectKey(strings.TrimPrefix(path, "/"))
	if err != nil {
		writeText(w, http.StatusBadRequest, "invalid object key")
		return
	}

	if _, ok := query["uploads"]; ok && r.Method == http.MethodPost {
		s.handleCOSMultipartInitiate(w, key)
		return
	}

	uploadID := query.Get("uploadId")
	if uploadID != "" {
		partNumber := query.Get("partNumber")
		switch r.Method {
		case http.MethodPut:
			s.handleCOSMultipartUploadPart(w, r, key, uploadID, partNumber)
			return
		case http.MethodPost:
			s.handleCOSMultipartComplete(w, r, key, uploadID)
			return
		case http.MethodDelete:
			s.handleCOSMultipartAbort(w, key, uploadID)
			return
		}
	}

	switch r.Method {
	case http.MethodPut:
		s.handleCOSPutObject(w, r, key)
	case http.MethodHead:
		s.handleCOSHeadObject(w, key)
	case http.MethodGet:
		s.handleCOSGetObject(w, key)
	case http.MethodDelete:
		s.handleCOSDeleteObject(w, key)
	default:
		http.NotFound(w, r)
	}
}

func (s *mockServer) handleCOSBucketRoot(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		s.mu.RLock()
		defer s.mu.RUnlock()

		type bucket struct {
			Name         string
			CreationDate string
		}
		items := make([]bucket, 0, len(s.buckets))
		for name, t := range s.buckets {
			items = append(items, bucket{Name: name, CreationDate: t.UTC().Format(time.RFC3339)})
		}
		sort.Slice(items, func(i, j int) bool { return items[i].Name < items[j].Name })

		var sb strings.Builder
		sb.WriteString(`<ListAllMyBucketsResult><Buckets>`)
		for _, b := range items {
			sb.WriteString(`<Bucket><Name>` + xmlEscape(b.Name) + `</Name><Location>ap-shanghai</Location><CreationDate>` + xmlEscape(b.CreationDate) + `</CreationDate></Bucket>`)
		}
		sb.WriteString(`</Buckets></ListAllMyBucketsResult>`)
		writeXML(w, http.StatusOK, sb.String())
	case http.MethodPut:
		bucketName := strings.TrimSpace(strings.Split(r.Host, ".")[0])
		if bucketName == "" || bucketName == "external-mock:19080" {
			bucketName = "mock-bucket"
		}
		s.mu.Lock()
		s.buckets[bucketName] = time.Now().UTC()
		s.mu.Unlock()
		w.WriteHeader(http.StatusOK)
	default:
		http.NotFound(w, r)
	}
}

func (s *mockServer) handleCOSCors(w http.ResponseWriter, r *http.Request) {
	s.mu.Lock()
	defer s.mu.Unlock()

	switch r.Method {
	case http.MethodGet:
		if strings.TrimSpace(s.corsXML) == "" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		writeXML(w, http.StatusOK, s.corsXML)
	case http.MethodPut:
		body, _ := io.ReadAll(r.Body)
		s.corsXML = strings.TrimSpace(string(body))
		if s.corsXML == "" {
			s.corsXML = `<CORSConfiguration></CORSConfiguration>`
		}
		w.WriteHeader(http.StatusOK)
	default:
		http.NotFound(w, r)
	}
}

func (s *mockServer) handleCOSPutObject(w http.ResponseWriter, r *http.Request, key string) {
	body, _ := io.ReadAll(r.Body)
	sum := md5.Sum(body)
	eTag := hex.EncodeToString(sum[:])

	s.mu.Lock()
	s.objects[key] = objectEntry{Body: body, ContentType: r.Header.Get("Content-Type"), ETag: eTag}
	s.mu.Unlock()

	w.Header().Set("ETag", fmt.Sprintf("\"%s\"", eTag))
	w.WriteHeader(http.StatusOK)
}

func (s *mockServer) handleCOSHeadObject(w http.ResponseWriter, key string) {
	s.mu.RLock()
	obj, ok := s.objects[key]
	s.mu.RUnlock()
	if !ok {
		w.WriteHeader(http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Length", strconv.Itoa(len(obj.Body)))
	w.Header().Set("ETag", fmt.Sprintf("\"%s\"", obj.ETag))
	if obj.ContentType != "" {
		w.Header().Set("Content-Type", obj.ContentType)
	}
	w.WriteHeader(http.StatusOK)
}

func (s *mockServer) handleCOSGetObject(w http.ResponseWriter, key string) {
	s.mu.RLock()
	obj, ok := s.objects[key]
	s.mu.RUnlock()
	if !ok {
		w.WriteHeader(http.StatusNotFound)
		return
	}
	if obj.ContentType != "" {
		w.Header().Set("Content-Type", obj.ContentType)
	}
	w.Header().Set("ETag", fmt.Sprintf("\"%s\"", obj.ETag))
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(obj.Body)
}

func (s *mockServer) handleCOSDeleteObject(w http.ResponseWriter, key string) {
	s.mu.Lock()
	delete(s.objects, key)
	s.mu.Unlock()
	w.WriteHeader(http.StatusNoContent)
}

func (s *mockServer) handleCOSMultipartInitiate(w http.ResponseWriter, key string) {
	uploadID := fmt.Sprintf("upload-%d", time.Now().UnixNano())
	s.mu.Lock()
	s.uploads[uploadID] = &multipartSession{Key: key, Parts: make(map[int][]byte)}
	s.mu.Unlock()

	xmlResp := fmt.Sprintf(`<InitiateMultipartUploadResult><Bucket>mock-bucket</Bucket><Key>%s</Key><UploadId>%s</UploadId></InitiateMultipartUploadResult>`, xmlEscape(key), xmlEscape(uploadID))
	writeXML(w, http.StatusOK, xmlResp)
}

func (s *mockServer) handleCOSMultipartUploadPart(w http.ResponseWriter, r *http.Request, key, uploadID, partNumberRaw string) {
	partNumber, err := strconv.Atoi(partNumberRaw)
	if err != nil || partNumber <= 0 {
		writeText(w, http.StatusBadRequest, "invalid partNumber")
		return
	}

	body, _ := io.ReadAll(r.Body)
	if len(body) == 0 {
		body = []byte{}
	}
	etagBytes := md5.Sum(body)
	eTag := hex.EncodeToString(etagBytes[:])

	s.mu.Lock()
	session, ok := s.uploads[uploadID]
	if ok && session.Key == key {
		session.Parts[partNumber] = body
	}
	s.mu.Unlock()

	if !ok {
		writeText(w, http.StatusNotFound, "upload session not found")
		return
	}

	w.Header().Set("ETag", fmt.Sprintf("\"%s\"", eTag))
	w.WriteHeader(http.StatusOK)
}

func (s *mockServer) handleCOSMultipartComplete(w http.ResponseWriter, r *http.Request, key, uploadID string) {
	body, _ := io.ReadAll(r.Body)
	partNumbers := extractPartNumbers(string(body))

	s.mu.Lock()
	session, ok := s.uploads[uploadID]
	if !ok || session.Key != key {
		s.mu.Unlock()
		writeText(w, http.StatusNotFound, "upload session not found")
		return
	}

	if len(partNumbers) == 0 {
		for n := range session.Parts {
			partNumbers = append(partNumbers, n)
		}
		sort.Ints(partNumbers)
	}

	final := make([]byte, 0)
	for _, n := range partNumbers {
		if p, exists := session.Parts[n]; exists {
			final = append(final, p...)
		}
	}
	sum := md5.Sum(final)
	eTag := hex.EncodeToString(sum[:])
	s.objects[key] = objectEntry{Body: final, ETag: eTag, ContentType: "application/octet-stream"}
	delete(s.uploads, uploadID)
	s.mu.Unlock()

	xmlResp := fmt.Sprintf(`<CompleteMultipartUploadResult><Location>mock://%s</Location><Bucket>mock-bucket</Bucket><Key>%s</Key><ETag>"%s"</ETag></CompleteMultipartUploadResult>`, xmlEscape(key), xmlEscape(key), eTag)
	writeXML(w, http.StatusOK, xmlResp)
}

func (s *mockServer) handleCOSMultipartAbort(w http.ResponseWriter, key, uploadID string) {
	s.mu.Lock()
	session, ok := s.uploads[uploadID]
	if ok && session.Key == key {
		delete(s.uploads, uploadID)
	}
	s.mu.Unlock()
	w.WriteHeader(http.StatusNoContent)
}

func extractXMLValue(source, tag string) string {
	re := regexp.MustCompile(fmt.Sprintf(`(?s)<%s>(.*?)</%s>`, regexp.QuoteMeta(tag), regexp.QuoteMeta(tag)))
	matches := re.FindStringSubmatch(source)
	if len(matches) < 2 {
		return ""
	}
	return xmlUnescape(strings.TrimSpace(matches[1]))
}

func extractPartNumbers(xmlBody string) []int {
	re := regexp.MustCompile(`(?s)<Part>\s*<PartNumber>(\d+)</PartNumber>\s*<ETag>.*?</ETag>\s*</Part>`)
	matches := re.FindAllStringSubmatch(xmlBody, -1)
	result := make([]int, 0, len(matches))
	for _, m := range matches {
		if len(m) < 2 {
			continue
		}
		n, err := strconv.Atoi(m[1])
		if err != nil {
			continue
		}
		result = append(result, n)
	}
	sort.Ints(result)
	return result
}

func buildJWK(pub rsa.PublicKey, kid string) map[string]any {
	n := base64.RawURLEncoding.EncodeToString(pub.N.Bytes())
	e := big.NewInt(int64(pub.E)).Bytes()
	eStr := base64.RawURLEncoding.EncodeToString(e)
	return map[string]any{
		"kty": "RSA",
		"kid": kid,
		"alg": "RS256",
		"use": "sig",
		"n":   n,
		"e":   eStr,
	}
}

func decodeObjectKey(v string) (string, error) {
	if strings.TrimSpace(v) == "" {
		return "", fmt.Errorf("empty")
	}
	decoded, err := url.PathUnescape(v)
	if err != nil {
		return "", err
	}
	return decoded, nil
}

func digMapString(v map[string]any, keys ...string) (string, bool) {
	var cur any = v
	for _, key := range keys {
		m, ok := cur.(map[string]any)
		if !ok {
			return "", false
		}
		cur, ok = m[key]
		if !ok {
			return "", false
		}
	}
	out, ok := cur.(string)
	return out, ok
}

func xmlEscape(v string) string {
	esc := strings.NewReplacer(
		"&", "&amp;",
		"<", "&lt;",
		">", "&gt;",
		`"`, "&quot;",
		"'", "&apos;",
	)
	return esc.Replace(v)
}

func xmlUnescape(v string) string {
	unesc := strings.NewReplacer(
		"&lt;", "<",
		"&gt;", ">",
		"&amp;", "&",
		"&quot;", `"`,
		"&apos;", "'",
	)
	return unesc.Replace(v)
}

func envOrDefault(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}

func writeJSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(data)
}

func writeXML(w http.ResponseWriter, status int, body string) {
	w.Header().Set("Content-Type", "application/xml")
	w.WriteHeader(status)
	_, _ = io.WriteString(w, body)
}

func writeText(w http.ResponseWriter, status int, body string) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(status)
	_, _ = io.WriteString(w, body)
}

func _unusedXML() {
	_ = xml.Header
}
