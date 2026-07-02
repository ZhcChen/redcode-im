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
