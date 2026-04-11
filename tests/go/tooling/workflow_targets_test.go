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
		"backend.up:",
		"backend.down:",
		"backend.logs:",
		"backend.test:",
		"backend.test.unit:",
		"backend.test.integration:",
		"backend.test.smoke:",
		"admin.up:",
		"admin.build:",
		"admin.test:",
		"admin.test.e2e:",
		"admin.test.routes:",
		"desktop.up:",
		"desktop.build:",
		"desktop.test:",
		"desktop.check:",
		"desktop.test.api:",
		"desktop.test.store:",
		"desktop.test.utils:",
		"desktop.package.macos.arm64:",
		"desktop.package.macos.intel:",
		"frontend.run:",
		"frontend.check:",
		"frontend.test:",
		"frontend.test.unit:",
		"frontend.test.core:",
		"frontend.test.chat:",
		"frontend.test.widgets:",
		"frontend.test.features:",
		"frontend.build.android:",
		"frontend.build.ios:",
		"website.up:",
		"website.build:",
		"website.test:",
		"website.test.unit:",
		"website.test.download:",
		"tests.run:",
		"tests.contract:",
		"tests.go:",
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
