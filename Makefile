# 根目录统一开发 / 构建 / 测试入口
#
# 设计原则：
# 1. 命令按模块 namespaced：backend.* / admin.* / desktop.* / frontend.* / website.* / tests.*
# 2. 保留旧命令别名，避免打断已有使用习惯。
# 3. backend 默认走 Compose-first；admin / desktop / website 默认走 screen 后台运行。

.DEFAULT_GOAL := help
SHELL := /bin/bash

ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

DOCKER := docker
BUN := bun
SCREEN := screen
CURL := curl
TAIL := tail
FLUTTER := flutter
CARGO := cargo
GO := go
PATROL := patrol

API_COMPOSE_FILE := $(ROOT_DIR)/backend/docker/dev/docker-compose.yml
API_SERVICE := backend
API_PORT := 8010

ADMIN_DIR := $(ROOT_DIR)/admin
ADMIN_SCREEN := admin
ADMIN_PORT := 8011
ADMIN_LOG := /tmp/redcode-admin.log

DESKTOP_DIR := $(ROOT_DIR)/desktop
DESKTOP_SCREEN := desktop
DESKTOP_PORT := 1420
DESKTOP_LOG := /tmp/redcode-desktop.log

FRONTEND_DIR := $(ROOT_DIR)/frontend
FRONTEND_ENV ?= .env.development
FLUTTER_DEVICE ?=
FRONTEND_TEST_DEVICE ?= macos
FRONTEND_ANDROID_ENV ?= production
FRONTEND_IOS_ENV ?= production
FRONTEND_API_BASE_URL ?= http://127.0.0.1:$(API_PORT)
FRONTEND_WS_URL ?= ws://127.0.0.1:$(API_PORT)/ws
PATROL_IOS_DEVICE ?= iPhone 17 Pro
PATROL_DEVICE ?= $(PATROL_IOS_DEVICE)
PATROL_JAVA_HOME ?= $(shell /usr/libexec/java_home -v 21 2>/dev/null || true)
PATROL_TEST_SERVER_PORT ?= 19081
PATROL_APP_SERVER_PORT ?= 19082

WEBSITE_DIR := $(ROOT_DIR)/website
WEBSITE_SCREEN := website
WEBSITE_PORT := 8015
WEBSITE_LOG := /tmp/redcode-website.log

TESTS_SCRIPT := $(ROOT_DIR)/tests/run.sh

define require_cmd
command -v $(1) >/dev/null 2>&1 || { echo "[make] 缺少命令: $(1)"; exit 1; }
endef

.PHONY: help status install.all test.all tests.all dev.up dev.down dev.logs \
	backend.up backend.down backend.restart backend.reset backend.logs backend.ps backend.test backend.test.unit backend.test.integration backend.test.smoke \
	admin.install admin.up admin.down admin.logs admin.build admin.check admin.test admin.test.e2e admin.test.routes admin.test.routes.default admin.test.routes.data-cleanup \
	desktop.install desktop.up desktop.down desktop.logs desktop.build desktop.check desktop.test desktop.test.unit desktop.test.api desktop.test.store desktop.test.utils \
	desktop.package.macos.arm64 desktop.package.macos.intel desktop.package.linux \
	frontend.install frontend.run frontend.check frontend.test frontend.test.unit frontend.test.core frontend.test.chat frontend.test.widgets frontend.test.features frontend.test.integration.smoke frontend.test.integration.network frontend.test.integration.auth frontend.test.integration.device frontend.test.integration.device.auth frontend.test.integration.device.reverse frontend.test.integration.device.auth.reverse frontend.test.patrol.harness frontend.test.patrol.login frontend.build.android frontend.build.ios frontend.proto \
	website.install website.up website.down website.logs website.build website.test website.test.unit website.test.download \
	tests.run tests.contract tests.go tests.rust tests.rust-lib tests.rust-integration \
	api-up api-down api-logs api-ps tests \
	admin-up admin-down admin-logs \
	desktop-up desktop-down desktop-logs \
	website-up website-down website-logs

help: ## 显示所有可用命令
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_.-]+:.*## / {printf "%-28s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

status: ## 查看各模块状态（backend / admin / desktop / website）
	@echo "[backend]"
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_COMPOSE_FILE)" ps || true
	@printf "healthz: "
	@$(CURL) -fsS "http://localhost:$(API_PORT)/healthz" 2>/dev/null || echo "unavailable"
	@echo
	@echo "[admin]"
	@if $(SCREEN) -ls 2>/dev/null | grep -q "[[:digit:]]\\.$(ADMIN_SCREEN)"; then echo "screen: running ($(ADMIN_SCREEN))"; else echo "screen: stopped"; fi
	@if lsof -nP -iTCP:$(ADMIN_PORT) -sTCP:LISTEN >/dev/null 2>&1; then echo "port $(ADMIN_PORT): listening"; else echo "port $(ADMIN_PORT): stopped"; fi
	@echo
	@echo "[desktop]"
	@if $(SCREEN) -ls 2>/dev/null | grep -q "[[:digit:]]\\.$(DESKTOP_SCREEN)"; then echo "screen: running ($(DESKTOP_SCREEN))"; else echo "screen: stopped"; fi
	@if lsof -nP -iTCP:$(DESKTOP_PORT) -sTCP:LISTEN >/dev/null 2>&1; then echo "port $(DESKTOP_PORT): listening"; else echo "port $(DESKTOP_PORT): stopped"; fi
	@echo
	@echo "[frontend]"
	@echo "run command: make frontend.run FRONTEND_ENV=$(FRONTEND_ENV) FLUTTER_DEVICE=$(FLUTTER_DEVICE)"
	@echo
	@echo "[website]"
	@if $(SCREEN) -ls 2>/dev/null | grep -q "[[:digit:]]\\.$(WEBSITE_SCREEN)"; then echo "screen: running ($(WEBSITE_SCREEN))"; else echo "screen: stopped"; fi
	@if lsof -nP -iTCP:$(WEBSITE_PORT) -sTCP:LISTEN >/dev/null 2>&1; then echo "port $(WEBSITE_PORT): listening"; else echo "port $(WEBSITE_PORT): stopped"; fi

install.all: ## 安装 admin / desktop / website 依赖，并拉取 frontend 依赖
	@$(MAKE) admin.install
	@$(MAKE) desktop.install
	@$(MAKE) website.install
	@$(MAKE) frontend.install

test.all: ## 运行仓库全量本地测试入口（backend contract + frontend + admin + desktop + website）
	@$(MAKE) tests.contract
	@$(MAKE) frontend.check
	@$(MAKE) frontend.test.unit
	@$(MAKE) frontend.test.integration.smoke
	@$(MAKE) admin.check
	@$(MAKE) admin.test.routes
	@$(MAKE) desktop.check
	@$(MAKE) desktop.test.unit
	@$(MAKE) website.test.unit

dev.up: ## 启动常用开发链路（backend + admin + website）
	@$(MAKE) backend.up
	@$(MAKE) admin.up
	@$(MAKE) website.up

dev.down: ## 停止常用开发链路（website + admin + desktop + backend）
	@$(MAKE) website.down
	@$(MAKE) admin.down
	@$(MAKE) desktop.down
	@$(MAKE) backend.down

dev.logs: ## 提示查看各模块日志命令
	@echo "backend: make backend.logs"
	@echo "admin:   make admin.logs"
	@echo "desktop: make desktop.logs"
	@echo "website: make website.logs"

backend.up: ## 启动 backend 开发栈（backend + postgres + redis）
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_COMPOSE_FILE)" up -d $(API_SERVICE)
	@echo "[backend] 已启动，健康检查地址: http://localhost:$(API_PORT)/healthz"

backend.down: ## 停止 backend 开发栈（保留数据卷）
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_COMPOSE_FILE)" down

backend.restart: ## 重启 backend 容器
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_COMPOSE_FILE)" restart $(API_SERVICE)

backend.reset: ## 停止 backend 开发栈并删除数据卷
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_COMPOSE_FILE)" down -v --remove-orphans

backend.logs: ## 跟随查看 backend 日志
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_COMPOSE_FILE)" logs -f --tail=200 $(API_SERVICE)

backend.ps: ## 查看 backend 开发栈容器状态
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_COMPOSE_FILE)" ps

backend.test: backend.test.unit backend.test.integration ## 运行 backend 默认 Rust 测试集

backend.test.unit: ## 运行 backend Rust 单元测试（cargo test --lib）
	@$(call require_cmd,$(CARGO))
	@cd "$(ROOT_DIR)/backend" && $(CARGO) test --lib

backend.test.integration: ## 运行 backend Rust 集成测试（cargo test --tests）
	@$(call require_cmd,$(CARGO))
	@cd "$(ROOT_DIR)/backend" && $(CARGO) test --tests -- --test-threads=1

backend.test.smoke: ## 运行 backend Rust smoke 测试
	@$(call require_cmd,$(CARGO))
	@cd "$(ROOT_DIR)/backend" && $(CARGO) test --test smoke_test -- --test-threads=1

admin.install: ## 安装 admin 依赖（bun install）
	@$(call require_cmd,$(BUN))
	@cd "$(ADMIN_DIR)" && $(BUN) install

admin.up: ## 启动 admin 开发服务（screen: admin，port: 8011）
	@$(call require_cmd,$(SCREEN))
	@$(call require_cmd,$(BUN))
	@if $(SCREEN) -ls 2>/dev/null | grep -q "[[:digit:]]\\.$(ADMIN_SCREEN)"; then \
		echo "[admin] 停止已有 screen 会话 $(ADMIN_SCREEN)"; \
		$(SCREEN) -S $(ADMIN_SCREEN) -X quit || true; \
	fi
	@if lsof -tiTCP:$(ADMIN_PORT) -sTCP:LISTEN >/dev/null 2>&1; then \
		echo "[admin] 清理占用端口 $(ADMIN_PORT) 的进程"; \
		lsof -tiTCP:$(ADMIN_PORT) -sTCP:LISTEN | xargs kill -9; \
	fi
	@echo "[admin] 启动中，日志: $(ADMIN_LOG)"
	@$(SCREEN) -dmS $(ADMIN_SCREEN) bash -lc 'cd "$(ADMIN_DIR)" && exec $(BUN) run dev > "$(ADMIN_LOG)" 2>&1'

admin.down: ## 停止 admin 开发服务
	@if $(SCREEN) -ls 2>/dev/null | grep -q "[[:digit:]]\\.$(ADMIN_SCREEN)"; then \
		$(SCREEN) -S $(ADMIN_SCREEN) -X quit || true; \
	fi
	@if lsof -tiTCP:$(ADMIN_PORT) -sTCP:LISTEN >/dev/null 2>&1; then \
		lsof -tiTCP:$(ADMIN_PORT) -sTCP:LISTEN | xargs kill -9; \
	fi
	@echo "[admin] 已停止"

admin.logs: ## 跟随查看 admin 日志
	@$(call require_cmd,$(TAIL))
	@test -f "$(ADMIN_LOG)" || { echo "[admin] 日志不存在: $(ADMIN_LOG)"; exit 1; }
	@$(TAIL) -n 200 -f "$(ADMIN_LOG)"

admin.build: ## 构建 admin 生产包
	@$(call require_cmd,$(BUN))
	@cd "$(ADMIN_DIR)" && $(BUN) run build

admin.check: ## 执行 admin 类型检查
	@$(call require_cmd,$(BUN))
	@cd "$(ADMIN_DIR)" && $(BUN) run type:check

admin.test: admin.test.routes ## 执行 admin 默认路由 smoke e2e

admin.test.e2e: ## 执行 admin Playwright 全量 E2E
	@$(call require_cmd,$(BUN))
	@cd "$(ADMIN_DIR)" && $(BUN) run test:e2e

admin.test.routes: ## 执行 admin 路由 smoke e2e
	@$(call require_cmd,$(BUN))
	@cd "$(ADMIN_DIR)" && $(BUN) run test:e2e:routes

admin.test.routes.default: ## 执行 admin default 路由 smoke
	@$(call require_cmd,$(BUN))
	@cd "$(ADMIN_DIR)" && $(BUN) run test:e2e:routes:default

admin.test.routes.data-cleanup: ## 执行 admin data-cleanup 路由 smoke
	@$(call require_cmd,$(BUN))
	@cd "$(ADMIN_DIR)" && $(BUN) run test:e2e:routes:data-cleanup

desktop.install: ## 安装 desktop 依赖（bun install）
	@$(call require_cmd,$(BUN))
	@cd "$(DESKTOP_DIR)" && $(BUN) install

desktop.up: ## 启动 desktop Tauri 开发服务（screen: desktop，port: 1420）
	@$(call require_cmd,$(SCREEN))
	@$(call require_cmd,$(BUN))
	@if $(SCREEN) -ls 2>/dev/null | grep -q "[[:digit:]]\\.$(DESKTOP_SCREEN)"; then \
		echo "[desktop] 停止已有 screen 会话 $(DESKTOP_SCREEN)"; \
		$(SCREEN) -S $(DESKTOP_SCREEN) -X quit || true; \
	fi
	@if lsof -tiTCP:$(DESKTOP_PORT) -sTCP:LISTEN >/dev/null 2>&1; then \
		echo "[desktop] 清理占用端口 $(DESKTOP_PORT) 的进程"; \
		lsof -tiTCP:$(DESKTOP_PORT) -sTCP:LISTEN | xargs kill -9; \
	fi
	@echo "[desktop] 启动中，日志: $(DESKTOP_LOG)"
	@$(SCREEN) -dmS $(DESKTOP_SCREEN) bash -lc 'cd "$(DESKTOP_DIR)" && exec $(BUN) run tauri:dev > "$(DESKTOP_LOG)" 2>&1'

desktop.down: ## 停止 desktop 开发服务
	@if $(SCREEN) -ls 2>/dev/null | grep -q "[[:digit:]]\\.$(DESKTOP_SCREEN)"; then \
		$(SCREEN) -S $(DESKTOP_SCREEN) -X quit || true; \
	fi
	@if lsof -tiTCP:$(DESKTOP_PORT) -sTCP:LISTEN >/dev/null 2>&1; then \
		lsof -tiTCP:$(DESKTOP_PORT) -sTCP:LISTEN | xargs kill -9; \
	fi
	@echo "[desktop] 已停止"

desktop.logs: ## 跟随查看 desktop 日志
	@$(call require_cmd,$(TAIL))
	@test -f "$(DESKTOP_LOG)" || { echo "[desktop] 日志不存在: $(DESKTOP_LOG)"; exit 1; }
	@$(TAIL) -n 200 -f "$(DESKTOP_LOG)"

desktop.build: ## 构建 desktop 前端资源（不打包安装器）
	@$(call require_cmd,$(BUN))
	@cd "$(DESKTOP_DIR)" && $(BUN) run build

desktop.check: ## 执行 desktop TypeScript 类型检查
	@$(call require_cmd,$(BUN))
	@cd "$(DESKTOP_DIR)" && $(BUN) run type-check

desktop.test: desktop.test.unit ## 执行 desktop 默认单元测试

desktop.test.unit: ## 执行 desktop 全量 Vitest
	@$(call require_cmd,$(BUN))
	@cd "$(DESKTOP_DIR)" && $(BUN) run test

desktop.test.api: ## 执行 desktop API 相关测试
	@$(call require_cmd,$(BUN))
	@cd "$(DESKTOP_DIR)" && $(BUN) run test -- test/api

desktop.test.store: ## 执行 desktop store 相关测试
	@$(call require_cmd,$(BUN))
	@cd "$(DESKTOP_DIR)" && $(BUN) run test -- test/store

desktop.test.utils: ## 执行 desktop utils 相关测试
	@$(call require_cmd,$(BUN))
	@cd "$(DESKTOP_DIR)" && $(BUN) run test -- test/utils

desktop.package.macos.arm64: ## 打包 macOS Apple Silicon（默认 ad-hoc 签名）
	@cd "$(DESKTOP_DIR)" && ./scripts/build-macos.sh arm64

desktop.package.macos.intel: ## 打包 macOS Intel（默认 ad-hoc 签名）
	@cd "$(DESKTOP_DIR)" && ./scripts/build-macos.sh intel

desktop.package.linux: ## 打包 Linux AppImage
	@cd "$(DESKTOP_DIR)" && ./scripts/build-linux.sh stable-linux

frontend.install: ## 获取 frontend Flutter 依赖
	@$(call require_cmd,$(FLUTTER))
	@cd "$(FRONTEND_DIR)" && $(FLUTTER) pub get

frontend.run: ## 运行 frontend（可覆盖 FRONTEND_ENV / FLUTTER_DEVICE）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(FRONTEND_DIR)" && if [ -n "$(FLUTTER_DEVICE)" ]; then ./scripts/run.sh --env "$(FRONTEND_ENV)" "$(FLUTTER_DEVICE)"; else ./scripts/run.sh --env "$(FRONTEND_ENV)"; fi

frontend.check: ## 执行 frontend Flutter analyze
	@$(call require_cmd,$(FLUTTER))
	@cd "$(FRONTEND_DIR)" && $(FLUTTER) analyze

frontend.test: frontend.test.unit ## 执行 frontend 默认 Flutter 测试

frontend.test.unit: ## 执行 frontend 全量 Flutter test
	@$(call require_cmd,$(FLUTTER))
	@cd "$(FRONTEND_DIR)" && $(FLUTTER) test

frontend.test.core: ## 执行 frontend core 测试
	@$(call require_cmd,$(FLUTTER))
	@cd "$(FRONTEND_DIR)" && $(FLUTTER) test test/core

frontend.test.chat: ## 执行 frontend chat 测试
	@$(call require_cmd,$(FLUTTER))
	@cd "$(FRONTEND_DIR)" && $(FLUTTER) test test/chat

frontend.test.widgets: ## 执行 frontend widgets 测试
	@$(call require_cmd,$(FLUTTER))
	@cd "$(FRONTEND_DIR)" && $(FLUTTER) test test/widgets

frontend.test.features: ## 执行 frontend features 模型测试
	@$(call require_cmd,$(FLUTTER))
	@cd "$(FRONTEND_DIR)" && $(FLUTTER) test test/features

frontend.test.integration.smoke: ## 执行 frontend integration smoke（不访问真实 backend）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(FRONTEND_DIR)" && ./scripts/test_integration.sh smoke

frontend.test.integration.network: ## 执行 frontend network integration（默认 macos + 127.0.0.1:8010，可覆盖 FRONTEND_TEST_DEVICE / FRONTEND_API_BASE_URL / FRONTEND_WS_URL）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(FRONTEND_DIR)" && API_BASE_URL="$(FRONTEND_API_BASE_URL)" WS_URL="$(FRONTEND_WS_URL)" ./scripts/test_integration.sh network --device "$(FRONTEND_TEST_DEVICE)"

frontend.test.integration.auth: ## 执行 frontend 真实邮箱注册/登录 integration（默认 macos + 127.0.0.1:8010，可覆盖 FRONTEND_TEST_DEVICE / FRONTEND_API_BASE_URL / FRONTEND_WS_URL）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(FRONTEND_DIR)" && API_BASE_URL="$(FRONTEND_API_BASE_URL)" WS_URL="$(FRONTEND_WS_URL)" ./scripts/test_integration.sh auth --device "$(FRONTEND_TEST_DEVICE)"

frontend.test.integration.device: ## 执行 frontend 设备 network integration（默认 Pixel 8 Pro；未连接则回退本机 iOS Simulator）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(FRONTEND_DIR)" && if [ -n "$(FLUTTER_DEVICE)" ]; then ./scripts/test_integration.sh device --device "$(FLUTTER_DEVICE)"; else ./scripts/test_integration.sh device; fi

frontend.test.integration.device.auth: ## 执行 frontend 设备真实邮箱注册/登录 integration（默认 Pixel 8 Pro；未连接则回退本机 iOS Simulator）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(FRONTEND_DIR)" && if [ -n "$(FLUTTER_DEVICE)" ]; then ./scripts/test_integration.sh device --target integration_test/auth_email_flow_test.dart --device "$(FLUTTER_DEVICE)"; else ./scripts/test_integration.sh device --target integration_test/auth_email_flow_test.dart; fi

frontend.test.integration.device.reverse: ## 执行 frontend Android 真机 network integration（adb reverse，默认 Pixel 8 Pro）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(FRONTEND_DIR)" && if [ -n "$(FLUTTER_DEVICE)" ]; then ./scripts/test_integration.sh device-reverse --device "$(FLUTTER_DEVICE)"; else ./scripts/test_integration.sh device-reverse; fi

frontend.test.integration.device.auth.reverse: ## 执行 frontend Android 真机真实邮箱注册/登录 integration（adb reverse，默认 Pixel 8 Pro）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(FRONTEND_DIR)" && if [ -n "$(FLUTTER_DEVICE)" ]; then ./scripts/test_integration.sh device-reverse --target integration_test/auth_email_flow_test.dart --device "$(FLUTTER_DEVICE)"; else ./scripts/test_integration.sh device-reverse --target integration_test/auth_email_flow_test.dart; fi

frontend.test.patrol.harness: ## 执行 frontend Patrol harness smoke（可覆盖 PATROL_DEVICE / PATROL_*_PORT）
	@$(call require_cmd,$(PATROL))
	@cd "$(FRONTEND_DIR)" && PATH="$$HOME/Library/Android/sdk/platform-tools:$$PATH" JAVA_HOME="$${JAVA_HOME:-$(PATROL_JAVA_HOME)}" $(PATROL) test -t patrol_test/harness_smoke_test.dart -d "$(PATROL_DEVICE)" --test-server-port "$(PATROL_TEST_SERVER_PORT)" --app-server-port "$(PATROL_APP_SERVER_PORT)"

frontend.test.patrol.login: ## 执行 frontend Patrol 登录 smoke（mock 模式，可覆盖 PATROL_DEVICE / PATROL_*_PORT）
	@$(call require_cmd,$(PATROL))
	@cd "$(FRONTEND_DIR)" && PATH="$$HOME/Library/Android/sdk/platform-tools:$$PATH" JAVA_HOME="$${JAVA_HOME:-$(PATROL_JAVA_HOME)}" $(PATROL) test -t patrol_test/login_smoke_test.dart -d "$(PATROL_DEVICE)" --test-server-port "$(PATROL_TEST_SERVER_PORT)" --app-server-port "$(PATROL_APP_SERVER_PORT)" --dart-define USE_MOCK_DATA=true --dart-define API_BASE_URL=http://127.0.0.1:1 --dart-define WS_URL=ws://127.0.0.1:1/ws

frontend.build.android: ## 构建 Android 安装包（默认 production）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(FRONTEND_DIR)" && ./scripts/build_android.sh "$(FRONTEND_ANDROID_ENV)"

frontend.build.ios: ## 构建 iOS IPA（无签名，默认 production）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(FRONTEND_DIR)" && ./scripts/build_ipa.sh "$(FRONTEND_IOS_ENV)"

frontend.proto: ## 重新生成 Flutter WebSocket proto
	@cd "$(FRONTEND_DIR)" && ./scripts/gen_ws_proto.sh

website.install: ## 安装 website 依赖（bun install）
	@$(call require_cmd,$(BUN))
	@cd "$(WEBSITE_DIR)" && $(BUN) install

website.up: ## 启动 website 开发服务（screen: website，port: 8015）
	@$(call require_cmd,$(SCREEN))
	@$(call require_cmd,$(BUN))
	@if $(SCREEN) -ls 2>/dev/null | grep -q "[[:digit:]]\\.$(WEBSITE_SCREEN)"; then \
		echo "[website] 停止已有 screen 会话 $(WEBSITE_SCREEN)"; \
		$(SCREEN) -S $(WEBSITE_SCREEN) -X quit || true; \
	fi
	@if lsof -tiTCP:$(WEBSITE_PORT) -sTCP:LISTEN >/dev/null 2>&1; then \
		echo "[website] 清理占用端口 $(WEBSITE_PORT) 的进程"; \
		lsof -tiTCP:$(WEBSITE_PORT) -sTCP:LISTEN | xargs kill -9; \
	fi
	@echo "[website] 启动中，日志: $(WEBSITE_LOG)"
	@$(SCREEN) -dmS $(WEBSITE_SCREEN) bash -lc 'cd "$(WEBSITE_DIR)" && exec $(BUN) run dev > "$(WEBSITE_LOG)" 2>&1'

website.down: ## 停止 website 开发服务
	@if $(SCREEN) -ls 2>/dev/null | grep -q "[[:digit:]]\\.$(WEBSITE_SCREEN)"; then \
		$(SCREEN) -S $(WEBSITE_SCREEN) -X quit || true; \
	fi
	@if lsof -tiTCP:$(WEBSITE_PORT) -sTCP:LISTEN >/dev/null 2>&1; then \
		lsof -tiTCP:$(WEBSITE_PORT) -sTCP:LISTEN | xargs kill -9; \
	fi
	@echo "[website] 已停止"

website.logs: ## 跟随查看 website 日志
	@$(call require_cmd,$(TAIL))
	@test -f "$(WEBSITE_LOG)" || { echo "[website] 日志不存在: $(WEBSITE_LOG)"; exit 1; }
	@$(TAIL) -n 200 -f "$(WEBSITE_LOG)"

website.build: ## 构建 website 生产包
	@$(call require_cmd,$(BUN))
	@cd "$(WEBSITE_DIR)" && $(BUN) run build

website.test: website.test.unit ## 执行 website 默认单元测试

website.test.unit: ## 执行 website 全量 Vitest
	@$(call require_cmd,$(BUN))
	@cd "$(WEBSITE_DIR)" && $(BUN) run test

website.test.download: ## 执行 website 下载逻辑测试
	@$(call require_cmd,$(BUN))
	@cd "$(WEBSITE_DIR)" && $(BUN) run test -- test/download-utils.test.ts

tests.contract: ## 运行 backend contract 全量测试栈（Rust + Go）
	@bash "$(TESTS_SCRIPT)" all

tests.go: ## 仅运行 backend Go 黑盒契约测试
	@bash "$(TESTS_SCRIPT)" go

tests.rust: ## 运行 backend Rust 单元 + 集成测试
	@bash "$(TESTS_SCRIPT)" rust

tests.rust-lib: ## 仅运行 backend Rust 单元测试
	@bash "$(TESTS_SCRIPT)" rust-lib

tests.rust-integration: ## 仅运行 backend Rust 集成测试
	@bash "$(TESTS_SCRIPT)" rust-integration

tests.run: ## 兼容旧命令：运行 backend contract 全量测试栈
	@bash "$(TESTS_SCRIPT)" all

tests.all: test.all ## 兼容命令：运行仓库全量本地测试入口

# 兼容旧命令 ---------------------------------------------------------------

api-up: backend.up ## 兼容旧命令：启动 backend 开发栈
api-down: backend.down ## 兼容旧命令：停止 backend 开发栈
api-logs: backend.logs ## 兼容旧命令：查看 backend 日志
api-ps: backend.ps ## 兼容旧命令：查看 backend 容器状态

admin-up: admin.up ## 兼容旧命令：启动 admin
admin-down: admin.down ## 兼容旧命令：停止 admin
admin-logs: admin.logs ## 兼容旧命令：查看 admin 日志

desktop-up: desktop.up ## 兼容旧命令：启动 desktop
desktop-down: desktop.down ## 兼容旧命令：停止 desktop
desktop-logs: desktop.logs ## 兼容旧命令：查看 desktop 日志

website-up: website.up ## 兼容旧命令：启动 website
website-down: website.down ## 兼容旧命令：停止 website
website-logs: website.logs ## 兼容旧命令：查看 website 日志

tests: tests.run ## 兼容旧命令：运行 tests/run.sh
