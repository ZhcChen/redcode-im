package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
)

type routeEndpoint struct {
	Method        string
	TemplatePath  string
	CanonicalPath string
}

type testHit struct {
	Kind         string // go | rust
	Method       string
	CanonicalKey string // "METHOD path"
	File         string
	Line         int
	RawPath      string
}

var (
	reRouteCall = []byte(".route(")
	reMethod    = regexp.MustCompile(`\b(get|post|put|patch|delete)\s*\(`)
	reTemplate  = regexp.MustCompile(`\{[^}]+\}`)
	reUUID      = regexp.MustCompile(`(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)

	reRustJSONRequest  = regexp.MustCompile(`json_request\(\s*Method::(GET|POST|PUT|PATCH|DELETE)\s*,\s*"([^"]+)"`)
	reRustEmptyRequest = regexp.MustCompile(`empty_request\(\s*Method::(GET|POST|PUT|PATCH|DELETE)\s*,\s*"([^"]+)"`)
)

func main() {
	repoRoot, err := findRepoRoot()
	if err != nil {
		fmt.Fprintln(os.Stderr, "[route_coverage] error:", err)
		os.Exit(1)
	}

	_, jsonData, err := buildReport(repoRoot)
	if err != nil {
		fmt.Fprintln(os.Stderr, "[route_coverage] error:", err)
		os.Exit(1)
	}

	outDir := filepath.Join(repoRoot, filepath.FromSlash("docs/reports"))
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		fmt.Fprintln(os.Stderr, "[route_coverage] mkdir error:", err)
		os.Exit(1)
	}

	// 写入 JSON
	jsonPath := filepath.Join(outDir, "api-test-coverage.json")
	if err := os.WriteFile(jsonPath, jsonData, 0o644); err != nil {
		fmt.Fprintln(os.Stderr, "[route_coverage] write json error:", err)
		os.Exit(1)
	}
	fmt.Println("[route_coverage] wrote:", jsonPath)
}

// CoverageJSON 是输出到 JSON 文件的结构
type CoverageJSON struct {
	UpdatedAt   string              `json:"updatedAt"`
	Summary     CoverageSummary     `json:"summary"`
	Routes      []RouteJSON         `json:"routes"`
	Uncovered   []string            `json:"uncovered"`
	OnlyGo      []string            `json:"onlyGo"`
	OnlyRust    []string            `json:"onlyRust"`
}

type CoverageSummary struct {
	Total       int     `json:"total"`
	GoCovered   int     `json:"goCovered"`
	RustCovered int     `json:"rustCovered"`
	BothCovered int     `json:"bothCovered"`
	Uncovered   int     `json:"uncovered"`
	Percentage  float64 `json:"percentage"`
}

type RouteJSON struct {
	Method   string `json:"method"`
	Path     string `json:"path"`
	GoHits   int    `json:"goHits"`
	RustHits int    `json:"rustHits"`
	Status   string `json:"status"` // "covered", "partial", "uncovered"
}

func buildReport(repoRoot string) (string, []byte, error) {
	routes, err := parseRoutes(filepath.Join(repoRoot, filepath.FromSlash("backend/src/routes.rs")))
	if err != nil {
		return "", nil, err
	}

	goHits, err := parseGoTests(repoRoot, filepath.Join(repoRoot, filepath.FromSlash("tests/go")))
	if err != nil {
		return "", nil, err
	}

	rustHits, err := parseRustTests(repoRoot, filepath.Join(repoRoot, filepath.FromSlash("backend/tests")))
	if err != nil {
		return "", nil, err
	}

	hits := append(goHits, rustHits...)

	coveredByGo := make(map[string][]testHit)
	coveredByRust := make(map[string][]testHit)
	for _, h := range hits {
		switch h.Kind {
		case "go":
			coveredByGo[h.CanonicalKey] = append(coveredByGo[h.CanonicalKey], h)
		case "rust":
			coveredByRust[h.CanonicalKey] = append(coveredByRust[h.CanonicalKey], h)
		}
	}

	allKeys := make([]string, 0, len(routes))
	for k := range routes {
		allKeys = append(allKeys, k)
	}
	sort.Strings(allKeys)

	type row struct {
		Key          string
		Method       string
		TemplatePath string
		Path         string
		GoHits       []testHit
		RustHits     []testHit
	}

	rows := make([]row, 0, len(allKeys))
	for _, key := range allKeys {
		ep := routes[key]
		rows = append(rows, row{
			Key:          key,
			Method:       ep.Method,
			TemplatePath: ep.TemplatePath,
			Path:         ep.CanonicalPath,
			GoHits:       coveredByGo[key],
			RustHits:     coveredByRust[key],
		})
	}

	var total, goCovered, rustCovered, bothCovered, noneCovered int
	var onlyGo, onlyRust []row
	var missing []row

	for _, r := range rows {
		total++
		goOK := len(r.GoHits) > 0
		rustOK := len(r.RustHits) > 0

		switch {
		case goOK && rustOK:
			bothCovered++
			goCovered++
			rustCovered++
		case goOK && !rustOK:
			onlyGo = append(onlyGo, r)
			goCovered++
		case !goOK && rustOK:
			onlyRust = append(onlyRust, r)
			rustCovered++
		default:
			noneCovered++
			missing = append(missing, r)
		}
	}

	var b strings.Builder
	b.WriteString("# API 路由测试覆盖清单\n\n")
	b.WriteString("> 生成方式：在仓库根目录执行 `go -C tests/go run ./cmd/route_coverage`（会更新本文件）。\n\n")
	b.WriteString("## 汇总\n\n")
	fmt.Fprintf(&b, "- 路由条目（按 method+path 计）：%d\n", total)
	fmt.Fprintf(&b, "- Go 覆盖：%d\n", goCovered)
	fmt.Fprintf(&b, "- Rust 覆盖：%d\n", rustCovered)
	fmt.Fprintf(&b, "- Go+Rust 均覆盖：%d\n", bothCovered)
	fmt.Fprintf(&b, "- 无测试覆盖：%d\n\n", noneCovered)

	b.WriteString("说明：\n\n")
	b.WriteString("- Go 覆盖：`tests/go/**` 里出现过匹配的 `DoJSON(method, path, ...)` 调用（含 internal/testutil 的封装）。\n")
	b.WriteString("- Rust 覆盖：`backend/tests/**` 里出现过匹配的 `json_request/empty_request` 调用（Axum in-process）。\n")
	b.WriteString("- `path` 统一做了规范化：去掉 query string；`{param}` 与动态拼接统一映射为 `{}`。\n\n")

	writeRows := func(title string, items []row, limit int) {
		b.WriteString("## " + title + "\n\n")
		if len(items) == 0 {
			b.WriteString("- （空）\n\n")
			return
		}
		if limit > 0 && len(items) > limit {
			items = items[:limit]
		}
		for _, r := range items {
			fmt.Fprintf(&b, "- `%s %s`\n", r.Method, r.TemplatePath)
			if len(r.GoHits) > 0 {
				b.WriteString("  - Go: " + formatHits(r.GoHits, 3) + "\n")
			}
			if len(r.RustHits) > 0 {
				b.WriteString("  - Rust: " + formatHits(r.RustHits, 3) + "\n")
			}
		}
		b.WriteString("\n")
	}

	writeRows("无测试覆盖（需要补）", missing, 0)
	writeRows("仅 Go 覆盖（Rust 覆盖率目标的主要补齐对象）", onlyGo, 0)
	writeRows("仅 Rust 覆盖（需要补 Go 黑盒用例的对象）", onlyRust, 0)

	// 构建 JSON 数据
	jsonRoutes := make([]RouteJSON, 0, len(rows))
	for _, r := range rows {
		status := "uncovered"
		if len(r.GoHits) > 0 && len(r.RustHits) > 0 {
			status = "covered"
		} else if len(r.GoHits) > 0 || len(r.RustHits) > 0 {
			status = "partial"
		}
		jsonRoutes = append(jsonRoutes, RouteJSON{
			Method:   r.Method,
			Path:     r.TemplatePath,
			GoHits:   len(r.GoHits),
			RustHits: len(r.RustHits),
			Status:   status,
		})
	}

	uncoveredPaths := make([]string, 0, len(missing))
	for _, r := range missing {
		uncoveredPaths = append(uncoveredPaths, r.Method+" "+r.TemplatePath)
	}

	onlyGoPaths := make([]string, 0, len(onlyGo))
	for _, r := range onlyGo {
		onlyGoPaths = append(onlyGoPaths, r.Method+" "+r.TemplatePath)
	}

	onlyRustPaths := make([]string, 0, len(onlyRust))
	for _, r := range onlyRust {
		onlyRustPaths = append(onlyRustPaths, r.Method+" "+r.TemplatePath)
	}

	percentage := 0.0
	if total > 0 {
		percentage = float64(total-noneCovered) / float64(total) * 100
	}

	coverageJSON := CoverageJSON{
		UpdatedAt: time.Now().Format(time.RFC3339),
		Summary: CoverageSummary{
			Total:       total,
			GoCovered:   goCovered,
			RustCovered: rustCovered,
			BothCovered: bothCovered,
			Uncovered:   noneCovered,
			Percentage:  percentage,
		},
		Routes:    jsonRoutes,
		Uncovered: uncoveredPaths,
		OnlyGo:    onlyGoPaths,
		OnlyRust:  onlyRustPaths,
	}

	jsonData, err := json.MarshalIndent(coverageJSON, "", "  ")
	if err != nil {
		return "", nil, fmt.Errorf("json marshal error: %w", err)
	}

	return b.String(), jsonData, nil
}

func findRepoRoot() (string, error) {
	wd, err := os.Getwd()
	if err != nil {
		return "", err
	}

	dir := wd
	for i := 0; i < 20; i++ {
		if fileExists(filepath.Join(dir, filepath.FromSlash("backend/src/routes.rs"))) {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return "", fmt.Errorf("无法定位仓库根目录（未找到 backend/src/routes.rs），当前目录=%s", wd)
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func formatHits(hits []testHit, max int) string {
	if len(hits) == 0 {
		return "0"
	}
	sort.Slice(hits, func(i, j int) bool {
		if hits[i].File == hits[j].File {
			return hits[i].Line < hits[j].Line
		}
		return hits[i].File < hits[j].File
	})
	if len(hits) > max {
		hits = hits[:max]
	}
	parts := make([]string, 0, len(hits))
	for _, h := range hits {
		parts = append(parts, fmt.Sprintf("`%s:%d`", filepath.ToSlash(h.File), h.Line))
	}
	return fmt.Sprintf("%d (%s)", len(hits), strings.Join(parts, ", "))
}

func parseRoutes(path string) (map[string]routeEndpoint, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	out := make(map[string]routeEndpoint)
	i := 0
	for {
		idx := bytes.Index(data[i:], reRouteCall)
		if idx < 0 {
			break
		}
		start := i + idx
		// Find beginning of arguments after ".route("
		j := start + len(reRouteCall)
		j = skipSpaces(data, j)
		if j >= len(data) || data[j] != '"' {
			i = j
			continue
		}

		pathLit, next, ok := parseStringLiteral(data, j)
		if !ok {
			i = j + 1
			continue
		}

		// Scan full call to match parentheses.
		callStart := start + bytes.Index(data[start:], reRouteCall)
		callArgsStart := callStart + len(reRouteCall)
		callEnd, ok := findMatchingParen(data, callArgsStart-1) // position at '('
		if !ok {
			return nil, fmt.Errorf("无法解析 .route(...)：%s", path)
		}
		callBody := string(data[callArgsStart:callEnd]) // inside parentheses

		methodMatches := reMethod.FindAllStringSubmatch(callBody, -1)
		methods := make(map[string]struct{})
		for _, m := range methodMatches {
			methods[strings.ToUpper(m[1])] = struct{}{}
		}

		// 如果没匹配到 method，则跳过（不应发生）
		for method := range methods {
			canonical := canonicalizePath(pathLit)
			key := method + " " + canonical
			// 同 key 可能来自多次 .route(...)（例如同一路径重复注册 method），保持幂等
			if _, exists := out[key]; !exists {
				out[key] = routeEndpoint{
					Method:        method,
					TemplatePath:  canonicalizeTemplate(pathLit),
					CanonicalPath: canonical,
				}
			}
		}

		i = callEnd + 1
		_ = next
	}

	return out, nil
}

func skipSpaces(data []byte, i int) int {
	for i < len(data) {
		switch data[i] {
		case ' ', '\n', '\r', '\t':
			i++
		default:
			return i
		}
	}
	return i
}

func parseStringLiteral(data []byte, i int) (value string, next int, ok bool) {
	// expects starting quote at i
	if i >= len(data) || data[i] != '"' {
		return "", i, false
	}
	j := i + 1
	for j < len(data) {
		if data[j] == '\\' {
			// skip escaped char
			j += 2
			continue
		}
		if data[j] == '"' {
			raw := data[i : j+1]
			var s string
			if err := json.Unmarshal(raw, &s); err != nil {
				// fallback: naive
				return string(raw[1:j]), j + 1, true
			}
			return s, j + 1, true
		}
		j++
	}
	return "", i, false
}

func findMatchingParen(data []byte, openParenAt int) (end int, ok bool) {
	// openParenAt points to '('
	if openParenAt < 0 || openParenAt >= len(data) || data[openParenAt] != '(' {
		return 0, false
	}
	depth := 0
	inString := false
	escaped := false
	for i := openParenAt; i < len(data); i++ {
		ch := data[i]
		if inString {
			if escaped {
				escaped = false
				continue
			}
			if ch == '\\' {
				escaped = true
				continue
			}
			if ch == '"' {
				inString = false
			}
			continue
		}
		switch ch {
		case '"':
			inString = true
		case '(':
			depth++
		case ')':
			depth--
			if depth == 0 {
				return i, true
			}
		}
	}
	return 0, false
}

func canonicalizeTemplate(path string) string {
	return reTemplate.ReplaceAllString(path, "{}")
}

func canonicalizePath(path string) string {
	p := path
	if idx := strings.IndexByte(p, '?'); idx >= 0 {
		p = p[:idx]
	}
	p = canonicalizeTemplate(p)

	// 将 UUID 片段归一化为 {}（极少数测试会写死 uuid）
	segs := strings.Split(p, "/")
	for i := range segs {
		if reUUID.MatchString(segs[i]) {
			segs[i] = "{}"
		}
	}
	p = strings.Join(segs, "/")

	return p
}

func parseGoTests(repoRoot string, root string) ([]testHit, error) {
	var files []string
	cmdRoot := filepath.Clean(filepath.Join(root, "cmd"))
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			// 跳过本命令自身，避免误把工具代码当成“测试覆盖”
			if filepath.Clean(path) == cmdRoot {
				return filepath.SkipDir
			}
			return nil
		}
		if strings.HasSuffix(path, ".go") {
			files = append(files, path)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	sort.Strings(files)

	var hits []testHit
	fset := token.NewFileSet()
	for _, path := range files {
		f, err := parser.ParseFile(fset, path, nil, 0)
		if err != nil {
			return nil, fmt.Errorf("parse %s: %w", path, err)
		}

		reportPath := path
		if rel, err := filepath.Rel(repoRoot, path); err == nil {
			reportPath = rel
		}

		for _, decl := range f.Decls {
			fn, ok := decl.(*ast.FuncDecl)
			if !ok || fn.Body == nil {
				continue
			}
			env := make(map[string]string)
			walkGoBlock(fset, reportPath, fn.Body, env, &hits)
		}
	}
	return hits, nil
}

func walkGoBlock(fset *token.FileSet, filePath string, block *ast.BlockStmt, env map[string]string, hits *[]testHit) {
	for _, stmt := range block.List {
		switch s := stmt.(type) {
		case *ast.AssignStmt:
			for _, rhs := range s.Rhs {
				ast.Inspect(rhs, func(n ast.Node) bool {
					call, ok := n.(*ast.CallExpr)
					if !ok {
						return true
					}
					maybeRecordDoJSONCall(fset, filePath, call, env, hits)
					return true
				})
			}
			// 记录形如: x := "/rooms/"+id 的路径模板
			for i := 0; i < len(s.Lhs) && i < len(s.Rhs); i++ {
				lhsIdent, ok := s.Lhs[i].(*ast.Ident)
				if !ok || lhsIdent.Name == "_" {
					continue
				}
				pattern := extractStringPatternWithEnv(s.Rhs[i], env)
				if pattern != "" && pattern != "{}" {
					env[lhsIdent.Name] = pattern
				}
			}
		case *ast.DeclStmt:
			// var x = "..."
			decl, ok := s.Decl.(*ast.GenDecl)
			if !ok {
				break
			}
			for _, spec := range decl.Specs {
				vs, ok := spec.(*ast.ValueSpec)
				if !ok {
					continue
				}
				for i := 0; i < len(vs.Names) && i < len(vs.Values); i++ {
					name := vs.Names[i].Name
					if name == "_" {
						continue
					}
					pattern := extractStringPatternWithEnv(vs.Values[i], env)
					if pattern != "" && pattern != "{}" {
						env[name] = pattern
					}
				}
			}
		case *ast.ExprStmt:
			if call, ok := s.X.(*ast.CallExpr); ok {
				maybeRecordDoJSONCall(fset, filePath, call, env, hits)
			}
		case *ast.IfStmt:
			local := cloneEnv(env)
			if s.Init != nil {
				walkGoStmt(fset, filePath, s.Init, local, hits)
			}
			walkGoBlock(fset, filePath, s.Body, local, hits)
			if s.Else != nil {
				walkGoStmt(fset, filePath, s.Else, local, hits)
			}
		case *ast.ForStmt:
			local := cloneEnv(env)
			if s.Init != nil {
				walkGoStmt(fset, filePath, s.Init, local, hits)
			}
			if s.Body != nil {
				walkGoBlock(fset, filePath, s.Body, local, hits)
			}
		case *ast.RangeStmt:
			local := cloneEnv(env)
			if s.Body != nil {
				walkGoBlock(fset, filePath, s.Body, local, hits)
			}
		case *ast.BlockStmt:
			local := cloneEnv(env)
			walkGoBlock(fset, filePath, s, local, hits)
		default:
			// 尝试在其它 stmt 内部递归找 DoJSON
			walkGoStmt(fset, filePath, s, env, hits)
		}
	}
}

func walkGoStmt(fset *token.FileSet, filePath string, stmt ast.Stmt, env map[string]string, hits *[]testHit) {
	switch s := stmt.(type) {
	case *ast.BlockStmt:
		local := cloneEnv(env)
		walkGoBlock(fset, filePath, s, local, hits)
	case *ast.ExprStmt:
		if call, ok := s.X.(*ast.CallExpr); ok {
			maybeRecordDoJSONCall(fset, filePath, call, env, hits)
		}
	case *ast.AssignStmt:
		for _, rhs := range s.Rhs {
			ast.Inspect(rhs, func(n ast.Node) bool {
				call, ok := n.(*ast.CallExpr)
				if !ok {
					return true
				}
				maybeRecordDoJSONCall(fset, filePath, call, env, hits)
				return true
			})
		}
		for i := 0; i < len(s.Lhs) && i < len(s.Rhs); i++ {
			lhsIdent, ok := s.Lhs[i].(*ast.Ident)
			if !ok || lhsIdent.Name == "_" {
				continue
			}
			pattern := extractStringPatternWithEnv(s.Rhs[i], env)
			if pattern != "" && pattern != "{}" {
				env[lhsIdent.Name] = pattern
			}
		}
	case *ast.IfStmt:
		local := cloneEnv(env)
		if s.Init != nil {
			walkGoStmt(fset, filePath, s.Init, local, hits)
		}
		walkGoBlock(fset, filePath, s.Body, local, hits)
		if s.Else != nil {
			walkGoStmt(fset, filePath, s.Else, local, hits)
		}
	case *ast.ForStmt:
		local := cloneEnv(env)
		if s.Init != nil {
			walkGoStmt(fset, filePath, s.Init, local, hits)
		}
		if s.Body != nil {
			walkGoBlock(fset, filePath, s.Body, local, hits)
		}
	case *ast.RangeStmt:
		local := cloneEnv(env)
		if s.Body != nil {
			walkGoBlock(fset, filePath, s.Body, local, hits)
		}
	default:
		ast.Inspect(stmt, func(n ast.Node) bool {
			call, ok := n.(*ast.CallExpr)
			if !ok {
				return true
			}
			maybeRecordDoJSONCall(fset, filePath, call, env, hits)
			return true
		})
	}
}

func maybeRecordDoJSONCall(fset *token.FileSet, filePath string, call *ast.CallExpr, env map[string]string, hits *[]testHit) {
	sel, ok := call.Fun.(*ast.SelectorExpr)
	if !ok || sel.Sel == nil || sel.Sel.Name != "DoJSON" {
		return
	}
	if len(call.Args) < 2 {
		return
	}

	method := extractStringLiteral(call.Args[0])
	if method == "" {
		method = "UNKNOWN"
	} else {
		method = strings.ToUpper(method)
	}

	pathPattern := extractStringPatternWithEnv(call.Args[1], env)
	if pathPattern == "" || pathPattern == "{}" {
		return
	}
	canonical := canonicalizePath(pathPattern)

	pos := fset.Position(call.Lparen)
	*hits = append(*hits, testHit{
		Kind:         "go",
		Method:       method,
		CanonicalKey: method + " " + canonical,
		File:         filepath.ToSlash(filePath),
		Line:         pos.Line,
		RawPath:      pathPattern,
	})
}

func extractStringPatternWithEnv(expr ast.Expr, env map[string]string) string {
	if ident, ok := expr.(*ast.Ident); ok {
		if v, exists := env[ident.Name]; exists {
			return v
		}
	}
	return extractStringPattern(expr)
}

func cloneEnv(env map[string]string) map[string]string {
	out := make(map[string]string, len(env))
	for k, v := range env {
		out[k] = v
	}
	return out
}

func extractStringLiteral(expr ast.Expr) string {
	lit, ok := expr.(*ast.BasicLit)
	if !ok || lit.Kind != token.STRING {
		return ""
	}
	s, err := strconvUnquote(lit.Value)
	if err != nil {
		return ""
	}
	return s
}

func extractStringPattern(expr ast.Expr) string {
	parts := extractStringParts(expr)
	if len(parts) == 0 {
		return ""
	}
	// 压缩连续的 "{}"
	var sb strings.Builder
	lastWasPlaceholder := false
	for _, p := range parts {
		if p == "{}" {
			if lastWasPlaceholder {
				continue
			}
			lastWasPlaceholder = true
			sb.WriteString(p)
			continue
		}
		lastWasPlaceholder = false
		sb.WriteString(p)
	}
	return sb.String()
}

func extractStringParts(expr ast.Expr) []string {
	switch v := expr.(type) {
	case *ast.BasicLit:
		if v.Kind != token.STRING {
			return []string{"{}"}
		}
		s, err := strconvUnquote(v.Value)
		if err != nil {
			return []string{"{}"}
		}
		return []string{s}
	case *ast.BinaryExpr:
		if v.Op != token.ADD {
			return []string{"{}"}
		}
		left := extractStringParts(v.X)
		right := extractStringParts(v.Y)
		return append(left, right...)
	case *ast.CallExpr:
		// fmt.Sprintf("...%s...", x) => 用格式串，所有 %v/%s/%d 等替换为 {}
		if sel, ok := v.Fun.(*ast.SelectorExpr); ok && sel.Sel != nil && sel.Sel.Name == "Sprintf" {
			if ident, ok := sel.X.(*ast.Ident); ok && ident.Name == "fmt" && len(v.Args) > 0 {
				if format := extractStringLiteral(v.Args[0]); format != "" {
					return []string{normalizeSprintfFormat(format)}
				}
			}
		}
		return []string{"{}"}
	default:
		return []string{"{}"}
	}
}

func normalizeSprintfFormat(format string) string {
	// 极简：把 %<verb> 都替换成 {}，并处理 %% -> %
	var out strings.Builder
	r := bufio.NewReader(strings.NewReader(format))
	for {
		ch, _, err := r.ReadRune()
		if err != nil {
			break
		}
		if ch != '%' {
			out.WriteRune(ch)
			continue
		}
		next, _, err := r.ReadRune()
		if err != nil {
			out.WriteRune('%')
			break
		}
		if next == '%' {
			out.WriteRune('%')
			continue
		}
		// 跳过 flags/width/precision（简单跳到字母 verb）
		for !isVerbRune(next) {
			n, _, err := r.ReadRune()
			if err != nil {
				next = 0
				break
			}
			next = n
		}
		out.WriteString("{}")
	}
	return out.String()
}

func isVerbRune(r rune) bool {
	return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z')
}

func strconvUnquote(s string) (string, error) {
	// json.Unmarshal 可以处理 Go 字符串字面量（"..."）
	var out string
	if err := json.Unmarshal([]byte(s), &out); err == nil {
		return out, nil
	}
	// fallback
	if len(s) >= 2 && s[0] == '"' && s[len(s)-1] == '"' {
		return s[1 : len(s)-1], nil
	}
	return "", errors.New("invalid string literal")
}

func parseRustTests(repoRoot string, root string) ([]testHit, error) {
	var files []string
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		if strings.HasSuffix(path, ".rs") {
			files = append(files, path)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	sort.Strings(files)

	var hits []testHit
	for _, path := range files {
		reportPath := path
		if rel, err := filepath.Rel(repoRoot, path); err == nil {
			reportPath = rel
		}

		data, err := os.ReadFile(path)
		if err != nil {
			return nil, err
		}

		for _, m := range reRustJSONRequest.FindAllSubmatchIndex(data, -1) {
			method := string(data[m[2]:m[3]])
			raw := string(data[m[4]:m[5]])
			line := 1 + bytes.Count(data[:m[0]], []byte("\n"))
			canonical := canonicalizePath(raw)
			hits = append(hits, testHit{
				Kind:         "rust",
				Method:       method,
				CanonicalKey: method + " " + canonical,
				File:         filepath.ToSlash(reportPath),
				Line:         line,
				RawPath:      raw,
			})
		}

		for _, m := range reRustEmptyRequest.FindAllSubmatchIndex(data, -1) {
			method := string(data[m[2]:m[3]])
			raw := string(data[m[4]:m[5]])
			line := 1 + bytes.Count(data[:m[0]], []byte("\n"))
			canonical := canonicalizePath(raw)
			hits = append(hits, testHit{
				Kind:         "rust",
				Method:       method,
				CanonicalKey: method + " " + canonical,
				File:         filepath.ToSlash(reportPath),
				Line:         line,
				RawPath:      raw,
			})
		}
	}

	return hits, nil
}
