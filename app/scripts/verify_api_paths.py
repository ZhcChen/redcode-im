#!/usr/bin/env python3
"""Verify Flutter REST path literals are registered by the API router."""

from __future__ import annotations

import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
APP_SEARCH_DIRS = (
    REPO_ROOT / "app" / "lib",
    REPO_ROOT / "app" / "integration_test",
)
API_ROUTES_FILE = REPO_ROOT / "api" / "src" / "routes.rs"
APP_BASE_URL_RE = re.compile(
    r"\$\{(?:AppConfig|EnvironmentConfig)\.apiBaseUrl\}([^\"']+)"
)
API_ROUTE_RE = re.compile(r'\.route\(\s*"([^"]+)"')
SUPPORTED_ROUTE_PLACEHOLDER_RE = re.compile(r"\{[^}/]+\}")
APP_DART_BRACED_VARIABLE_RE = re.compile(r"\$\{[^}]+\}")
APP_DART_VARIABLE_RE = re.compile(r"\$[A-Za-z_][A-Za-z0-9_]*")


def normalize_path(path: str) -> str:
    path = path.split("?", 1)[0]
    path = APP_DART_BRACED_VARIABLE_RE.sub("{}", path)
    path = SUPPORTED_ROUTE_PLACEHOLDER_RE.sub("{}", path)
    path = APP_DART_VARIABLE_RE.sub("{}", path)
    path = re.sub(r"/+", "/", path)
    return path.rstrip("/") or "/"


def collect_api_routes() -> set[str]:
    routes_text = API_ROUTES_FILE.read_text(encoding="utf-8")
    return {normalize_path(match) for match in API_ROUTE_RE.findall(routes_text)}


def collect_app_paths() -> set[str]:
    paths: set[str] = set()
    for directory in APP_SEARCH_DIRS:
        for dart_file in directory.rglob("*.dart"):
            text = dart_file.read_text(encoding="utf-8")
            for match in APP_BASE_URL_RE.finditer(text):
                suffix = match.group(1)
                if suffix.startswith("/"):
                    paths.add(normalize_path(suffix))
    return paths


def main() -> int:
    api_routes = collect_api_routes()
    app_paths = collect_app_paths()
    missing = sorted(path for path in app_paths if path not in api_routes)

    print(
        f"app_paths={len(app_paths)} "
        f"api_routes={len(api_routes)} "
        f"missing={len(missing)}"
    )
    for path in missing:
        print(f"missing: {path}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
