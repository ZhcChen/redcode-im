package tooling

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func readRepoFile(t *testing.T, parts ...string) string {
	t.Helper()

	_, currentFile, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("failed to resolve current test file")
	}

	repoRoot := filepath.Clean(filepath.Join(filepath.Dir(currentFile), "..", "..", ".."))
	path := filepath.Join(append([]string{repoRoot}, parts...)...)
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("failed to read %s: %v", path, err)
	}
	return string(data)
}

func TestRootMakefileExposesUnifiedModuleTargets(t *testing.T) {
	makefile := readRepoFile(t, "Makefile")

	requiredTargets := []string{
		"api.up:",
		"api.down:",
		"api.logs:",
		"api.wait:",
		"api.test:",
		"api.test.unit:",
		"api.test.integration:",
		"api.test.smoke:",
		"api.test.build:",
		"api.test.build.release:",
		"api.perf:",
		"api.perf.run:",
		"api.perf.smoke:",
		"api.perf.healthz:",
		"api.perf.readyz:",
		"api.perf.auth:",
		"api.perf.ws.connect:",
		"api.perf.ws.join:",
		"api.perf.ws.broadcast:",
		"api.perf.release:",
		"api.perf.release.small:",
		"api.perf.release.standard:",
		"api.perf.release.large:",
		"api.perf.release.healthz:",
		"api.perf.release.readyz:",
		"api.perf.release.auth:",
		"api.perf.release.ws.connect:",
		"api.perf.release.ws.join:",
		"api.perf.release.ws.broadcast:",
		"api.perf.down:",
		"admin.up:",
		"admin.build:",
		"admin.test:",
		"admin.test.e2e:",
		"admin.test.routes:",
		"admin.test.live:",
		"desktop.up:",
		"desktop.build:",
		"desktop.test:",
		"desktop.check:",
		"desktop.test.api:",
		"desktop.test.store:",
		"desktop.test.utils:",
		"desktop.test.live:",
		"desktop.package.macos.arm64:",
		"desktop.package.macos.intel:",
		"app.run:",
		"app.check:",
		"app.test:",
		"app.test.unit:",
		"app.test.api-paths:",
		"app.test.core:",
		"app.test.chat:",
		"app.test.widgets:",
		"app.test.features:",
		"app.build.android:",
		"app.build.ios:",
		"website.up:",
		"website.build:",
		"website.test:",
		"website.test.unit:",
		"website.test.download:",
		"api.test:",
		"api.test.unit:",
		"api.test.integration:",
		"test.all:",
		"test.live:",
		"tests.all:",
		"tests.compose.config:",
		"tests.tooling:",
		"tests.perf.check:",
	}

	for _, target := range requiredTargets {
		if !strings.Contains(makefile, target) {
			t.Fatalf("expected Makefile to contain target %q", target)
		}
	}
}

func TestCodeReviewGraphIsExplicitAndIsolated(t *testing.T) {
	makefile := readRepoFile(t, "Makefile")
	gitignore := readRepoFile(t, ".gitignore")
	preCommit := readRepoFile(t, "admin", ".husky", "pre-commit")
	commitMsg := readRepoFile(t, "admin", ".husky", "commit-msg")

	requiredSnippets := []string{
		"CRG_VERSION ?= 2.3.7",
		"uvx --from code-review-graph==$(CRG_VERSION) code-review-graph",
		"CRG_BASE = $(if $(strip $(BASE)),$(BASE),HEAD~1)",
		"crg.build:",
		"crg.update:",
		"crg.status:",
		"crg.review:",
		"detect-changes --repo \"$(ROOT_DIR)\" --base \"$(CRG_BASE)\" --brief",
	}
	for _, snippet := range requiredSnippets {
		if !strings.Contains(makefile, snippet) {
			t.Fatalf("expected Makefile to contain controlled CRG entry %q", snippet)
		}
	}

	if !strings.Contains(gitignore, ".code-review-graph/") {
		t.Fatal("expected .gitignore to exclude local Code Review Graph data")
	}

	for _, target := range []string{"test.all", "test.live"} {
		body := makeTargetBody(makefile, target)
		if strings.Contains(body, "crg.") || strings.Contains(body, "code-review-graph") {
			t.Fatalf("expected %s to exclude Code Review Graph automatic triggers", target)
		}
	}

	for name, hook := range map[string]string{"pre-commit": preCommit, "commit-msg": commitMsg} {
		if strings.Contains(hook, "crg.") || strings.Contains(hook, "code-review-graph") {
			t.Fatalf("expected %s hook to exclude Code Review Graph automatic triggers", name)
		}
	}
}

func makeTargetBody(makefile, target string) string {
	startMarker := target + ":"
	start := strings.Index(makefile, startMarker)
	if start == -1 {
		return ""
	}

	remaining := makefile[start+len(startMarker):]
	lines := strings.Split(remaining, "\n")
	var body []string
	for _, line := range lines {
		if line == "" {
			body = append(body, line)
			continue
		}
		if !strings.HasPrefix(line, "\t") && !strings.HasPrefix(line, " ") {
			break
		}
		body = append(body, line)
	}
	return strings.Join(body, "\n")
}

func TestFlutterFirstReleaseGatesExcludePausedNativeChecks(t *testing.T) {
	makefile := readRepoFile(t, "Makefile")

	testAll := makeTargetBody(makefile, "test.all")
	if testAll == "" {
		t.Fatal("expected Makefile to contain test.all target body")
	}
	forbiddenTestAll := []string{
		"ios-app.check",
		"android-app.check",
		"ios-app.test",
		"android-app.test",
	}
	for _, snippet := range forbiddenTestAll {
		if strings.Contains(testAll, snippet) {
			t.Fatalf("expected test.all to exclude paused native gate %q", snippet)
		}
	}
	requiredTestAll := []string{
		"app.check",
		"app.test.scripts",
		"app.test.unit",
		"app.test.integration.smoke",
	}
	for _, snippet := range requiredTestAll {
		if !strings.Contains(testAll, snippet) {
			t.Fatalf("expected test.all to keep Flutter gate %q", snippet)
		}
	}

	testLive := makeTargetBody(makefile, "test.live")
	if testLive == "" {
		t.Fatal("expected Makefile to contain test.live target body")
	}
	forbiddenTestLive := []string{
		"h5-app.test.live",
		"ios-app.test.live",
		"android-app.test.live",
		"ios-app.test.interop",
		"android-app.test.interop",
	}
	for _, snippet := range forbiddenTestLive {
		if strings.Contains(testLive, snippet) {
			t.Fatalf("expected test.live to exclude non-Flutter first-release gate %q", snippet)
		}
	}
	requiredTestLive := []string{
		"app.test.integration.network",
		"app.test.integration.auth",
		"app.test.integration.contract",
	}
	for _, snippet := range requiredTestLive {
		if !strings.Contains(testLive, snippet) {
			t.Fatalf("expected test.live to keep Flutter live gate %q", snippet)
		}
	}
}

func TestBuildMacosScriptUsesAdHocSigningByDefault(t *testing.T) {
	script := readRepoFile(t, "desktop", "scripts", "build-macos.sh")

	requiredSnippets := []string{
		"MACOS_SIGN_IDENTITY",
		"codesign --force --deep --sign",
		"codesign --verify --deep --strict",
		"签名完成",
	}

	for _, snippet := range requiredSnippets {
		if !strings.Contains(script, snippet) {
			t.Fatalf("expected build-macos.sh to contain %q", snippet)
		}
	}

	if !strings.Contains(script, "\"-\"") && !strings.Contains(script, "='-'") && !strings.Contains(script, ":-'-'") {
		t.Fatal("expected build-macos.sh to default signing identity to ad-hoc (-)")
	}
}
