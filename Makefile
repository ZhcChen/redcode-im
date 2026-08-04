# 根目录统一开发 / 构建 / 测试入口
#
# 设计原则：
# 1. 命令按模块 namespaced：api.* / admin.* / desktop.* / h5-app.* / app.* / website.* / tests.*
# 2. 保留旧命令别名，避免打断已有使用习惯。
# 3. api 默认走 Compose-first；admin / desktop / h5-app / website 默认走 screen 后台运行。

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
SWIFT := swift
XCODEBUILD := xcodebuild
XCRUN := xcrun
RUBY := ruby

E2EE_CORE_DIR := $(ROOT_DIR)/e2ee-core

API_COMPOSE_FILE := $(ROOT_DIR)/api/docker/dev/docker-compose.yml
API_TEST_COMPOSE_FILE := $(ROOT_DIR)/tests/docker-compose.test.yml
API_SERVICE := api
API_PORT := 8010
API_SERVICE_CPUS ?= 2.0
API_SERVICE_MEMORY ?= 1g
POSTGRES_PERF_CPUS ?= 4.0
POSTGRES_PERF_MEMORY ?= 4g
REDIS_PERF_CPUS ?= 2.0
REDIS_PERF_MEMORY ?= 1g
DATABASE_PERF_MAX_CONNECTIONS ?= 80
DATABASE_PERF_MIN_CONNECTIONS ?= 8
API_PERF_BCRYPT_COST ?= 8
API_PERF_REPORT_PREFIX ?= release
PERF_HEALTHZ_CONCURRENCY ?= 64
PERF_READYZ_CONCURRENCY ?= 1
PERF_READYZ_INTERVAL_MS ?= 1000
PERF_AUTH_CONCURRENCY ?= 4
PERF_AUTH_TIMEOUT_MS ?= 15000
PERF_WS_CONNECT_CONCURRENCY ?= 8
PERF_WS_BROADCAST_CLIENTS ?= 16
PERF_WS_BROADCAST_MESSAGES ?= 20
PERF_WS_TIMEOUT_MS ?= 20000
API_PERF_ENV := API_SERVICE_CPUS=$(API_SERVICE_CPUS) API_SERVICE_MEMORY=$(API_SERVICE_MEMORY) API_SERVICE_MEMORY_SWAP=$(API_SERVICE_MEMORY) POSTGRES_TEST_CPUS=$(POSTGRES_PERF_CPUS) POSTGRES_TEST_MEMORY=$(POSTGRES_PERF_MEMORY) POSTGRES_TEST_MEMORY_SWAP=$(POSTGRES_PERF_MEMORY) REDIS_TEST_CPUS=$(REDIS_PERF_CPUS) REDIS_TEST_MEMORY=$(REDIS_PERF_MEMORY) REDIS_TEST_MEMORY_SWAP=$(REDIS_PERF_MEMORY) DATABASE_MAX_CONNECTIONS=$(DATABASE_PERF_MAX_CONNECTIONS) DATABASE_MIN_CONNECTIONS=$(DATABASE_PERF_MIN_CONNECTIONS) BCRYPT_COST=$(API_PERF_BCRYPT_COST)

ADMIN_DIR := $(ROOT_DIR)/admin
ADMIN_SCREEN := admin
ADMIN_PORT := 8011
ADMIN_LOG := /tmp/redcode-admin.log
ADMIN_BASE_URL ?= http://localhost:$(ADMIN_PORT)
ADMIN_API_BASE_URL ?= http://127.0.0.1:$(API_PORT)

DESKTOP_DIR := $(ROOT_DIR)/desktop
DESKTOP_SCREEN := desktop
DESKTOP_PORT := 1420
DESKTOP_LOG := /tmp/redcode-desktop.log
DESKTOP_API_BASE_URL ?= http://127.0.0.1:$(API_PORT)
DESKTOP_WS_URL ?= ws://127.0.0.1:$(API_PORT)/ws

APP_DIR := $(ROOT_DIR)/app
APP_ENV ?= .env.development
FLUTTER_DEVICE ?=
APP_TEST_DEVICE ?=
FRONTEND_TEST_DEVICE ?=
APP_SELECTED_TEST_DEVICE := $(strip $(or $(APP_TEST_DEVICE),$(FRONTEND_TEST_DEVICE),$(FLUTTER_DEVICE)))
APP_ANDROID_ENV ?= production
APP_IOS_ENV ?= production
APP_API_BASE_URL ?=
APP_WS_URL ?=
APP_IOS_CLANG_WRAPPER := $(APP_DIR)/scripts/xcode_clang_probe_wrapper.sh
PATROL_IOS_DEVICE ?= iPhone 17 Pro
PATROL_DEVICE ?= $(PATROL_IOS_DEVICE)
PATROL_JAVA_HOME ?= $(shell /usr/libexec/java_home -v 21 2>/dev/null || true)
PATROL_TEST_SERVER_PORT ?= 19081
PATROL_APP_SERVER_PORT ?= 19082
PATROL_DUAL_DEVICE_A ?=
PATROL_DUAL_DEVICE_B ?=
PATROL_DUAL_ACCOUNT_A ?=
PATROL_DUAL_ACCOUNT_B ?=
PATROL_DUAL_PASSWORD ?=
PATROL_CROSS_IOS_DEVICE ?=
PATROL_CROSS_ANDROID_DEVICE ?=
PATROL_CROSS_IOS_ACCOUNT ?=
PATROL_CROSS_ANDROID_ACCOUNT ?=
PATROL_CROSS_PASSWORD ?=
PATROL_LAYOUT_DEVICE ?= $(PATROL_IOS_DEVICE)
PATROL_LAYOUT_ACCOUNT ?=
PATROL_LAYOUT_PEER_ACCOUNT ?=
PATROL_LAYOUT_PASSWORD ?=
APP_IOS_ACCEPTANCE_DEVICE ?=
APP_IOS_ACCEPTANCE_ACCOUNT ?=
APP_IOS_ACCEPTANCE_PEER_ACCOUNT ?=
APP_IOS_ACCEPTANCE_PASSWORD ?=
PATROL_PERMISSION_DEVICE ?= $(PATROL_IOS_DEVICE)
PATROL_PERMISSION_ACCOUNT ?=
PATROL_PERMISSION_PEER_ACCOUNT ?=
PATROL_PERMISSION_PASSWORD ?=
PATROL_PAGE_DEVICE ?= $(PATROL_IOS_DEVICE)
PATROL_PAGE_ACCOUNT ?=
PATROL_PAGE_PASSWORD ?=

WEBSITE_DIR := $(ROOT_DIR)/website
WEBSITE_SCREEN := website
WEBSITE_PORT := 8015
WEBSITE_LOG := /tmp/redcode-website.log

H5_APP_DIR := $(ROOT_DIR)/h5-app
H5_APP_SCREEN := h5-app
H5_APP_PORT := 8016
H5_APP_LOG := /tmp/redcode-h5-app.log
H5_APP_BASE_URL ?= http://localhost:$(H5_APP_PORT)
H5_APP_API_BASE_URL ?= http://127.0.0.1:$(API_PORT)

IM_UI_DIR := $(ROOT_DIR)/im-ui-html
IM_UI_PORT := 8020

IOS_APP_DIR := $(ROOT_DIR)/ios-app
IOS_APP_PROJECT := $(IOS_APP_DIR)/RedCodeIM.xcodeproj
IOS_APP_SCHEME := RedCodeIM
IOS_APP_TARGET := RedCodeIM
IOS_APP_DERIVED_DATA := $(IOS_APP_DIR)/DerivedData
IOS_APP_BUNDLE_ID := com.redcode.im.iosapp
IOS_APP_SIMULATOR_NAME ?= iPhone 17 Pro
IOS_APP_SIMULATOR_ID ?=
IOS_APP_DEVICE_ID ?=
IOS_APP_DEVELOPMENT_TEAM ?=
IOS_APNS_PROVIDER_CONFIGURED ?=
IOS_APP_LAN_IP ?=
IOS_APP_API_BASE_URL ?=
IOS_APP_WS_URL ?=
IOS_APP_XCODEBUILD_DEVICE_FLAGS ?= -allowProvisioningUpdates

ANDROID_APP_DIR := $(ROOT_DIR)/android-app
ANDROID_GRADLEW := $(APP_DIR)/android/gradlew
ANDROID_GRADLE ?= $(shell command -v gradle 2>/dev/null || find "$$HOME/.gradle/wrapper/dists" -path "*/gradle-9.3.1/bin/gradle" -type f -print -quit 2>/dev/null || printf "%s" "$(ANDROID_GRADLEW)")
ANDROID_SDK_ROOT ?= $(HOME)/Library/Android/sdk
ANDROID_HOME ?= $(ANDROID_SDK_ROOT)
ADB ?= $(ANDROID_HOME)/platform-tools/adb
ANDROID_APP_PREFERRED_DEVICE ?= 3A091FDJG001DN
ANDROID_APP_DEVICE ?= $(shell if [ -x "$(ADB)" ]; then "$(ADB)" devices | awk -v preferred="$(ANDROID_APP_PREFERRED_DEVICE)" 'NR > 1 && $$2 == "device" { if ($$1 == preferred) { print $$1; found = 1; exit } if ($$1 ~ /^emulator-/ && emulator == "") emulator = $$1; if (first == "") first = $$1 } END { if (!found) print (emulator != "" ? emulator : (first != "" ? first : "emulator-5554")) }'; else printf "%s" "emulator-5554"; fi)
ANDROID_APP_LAN_IP ?= $(shell iface="$$(route get default 2>/dev/null | awk '/interface:/{print $$2; exit}')"; if [ -n "$$iface" ]; then ipconfig getifaddr "$$iface" 2>/dev/null; fi)
ANDROID_APP_API_BASE_URL ?= $(shell device="$(ANDROID_APP_DEVICE)"; lan_ip="$(ANDROID_APP_LAN_IP)"; if printf "%s" "$$device" | grep -q '^emulator-'; then printf "http://10.0.2.2:$(API_PORT)"; elif [ -n "$$lan_ip" ]; then printf "http://%s:$(API_PORT)" "$$lan_ip"; else printf "__ANDROID_APP_LAN_IP_REQUIRED__"; fi)
ANDROID_APP_WS_URL ?= $(shell device="$(ANDROID_APP_DEVICE)"; lan_ip="$(ANDROID_APP_LAN_IP)"; if printf "%s" "$$device" | grep -q '^emulator-'; then printf "ws://10.0.2.2:$(API_PORT)/ws"; elif [ -n "$$lan_ip" ]; then printf "ws://%s:$(API_PORT)/ws" "$$lan_ip"; else printf "__ANDROID_APP_LAN_IP_REQUIRED__"; fi)
ANDROID_APP_USE_REMOTE_AUTH ?= false
ANDROID_APP_LIVE_API_BASE_URL ?= http://127.0.0.1:$(API_PORT)
ANDROID_APP_LIVE_WS_URL ?= ws://127.0.0.1:$(API_PORT)/ws
ANDROID_APP_PACKAGE := com.redcode.im.androidapp
ANDROID_APP_APK := $(ANDROID_APP_DIR)/app/build/outputs/apk/debug/app-debug.apk
CRG_VERSION ?= 2.3.7
CRG := uvx --from code-review-graph==$(CRG_VERSION) code-review-graph
CRG_BASE = $(if $(strip $(BASE)),$(BASE),HEAD~1)

define require_cmd
command -v $(1) >/dev/null 2>&1 || { echo "[make] 缺少命令: $(1)"; exit 1; }
endef

define require_android_app_network
if [ "$(ANDROID_APP_API_BASE_URL)" = "__ANDROID_APP_LAN_IP_REQUIRED__" ] || [ "$(ANDROID_APP_WS_URL)" = "__ANDROID_APP_LAN_IP_REQUIRED__" ]; then \
	echo "[android-app] 当前目标设备是物理设备，但未能解析本机 LAN IP；请设置 ANDROID_APP_LAN_IP=<LAN_IP>" >&2; \
	exit 66; \
fi
endef

.PHONY: help status install.all test.all test.live tests.all dev.up dev.down dev.logs crg.build crg.update crg.status crg.review \
	api.up api.down api.restart api.reset api.wait api.logs api.ps api.test api.test.unit api.test.integration api.test.smoke api.test.build api.test.build.release api.test.images api.test.deps.down api.perf api.perf.run api.perf.smoke api.perf.healthz api.perf.readyz api.perf.auth api.perf.ws.connect api.perf.ws.join api.perf.ws.broadcast api.perf.release api.perf.release.small api.perf.release.standard api.perf.release.large api.perf.release.healthz api.perf.release.readyz api.perf.release.auth api.perf.release.ws.connect api.perf.release.ws.join api.perf.release.ws.broadcast api.perf.down api.migration.guard migration.guard \
	admin.install admin.up admin.down admin.wait admin.logs admin.build admin.check admin.test admin.test.e2e admin.test.routes admin.test.routes.default admin.test.routes.data-cleanup admin.test.live \
	desktop.install desktop.up desktop.down desktop.logs desktop.build desktop.check desktop.test desktop.test.unit desktop.test.api desktop.test.store desktop.test.utils desktop.test.live \
	e2ee-core.test e2ee-core.check e2ee-core.check.targets e2ee-core.test.flutter e2ee-core.test.wasm e2ee-core.fixture.generate \
	h5-app.install h5-app.up h5-app.down h5-app.wait h5-app.logs h5-app.build h5-app.check h5-app.test h5-app.test.unit h5-app.test.live h5-app.test.e2e im-ui.install im-ui.test im-ui.test.visual \
	ios-app.describe ios-app.check ios-app.test ios-app.test.live ios-app.test.interop ios-app.resolve.lan-ip ios-app.resolve.device ios-app.build.device ios-app.install.device ios-app.smoke.device ios-app.apns.preflight.local ios-app.smoke.device.local ios-app.build.simulator ios-app.ui-test ios-app.smoke.simulator ios-app.apns.preflight \
	android-app.check android-app.lint android-app.test android-app.test.unit android-app.test.live android-app.test.interop android-app.test.interop.support android-app.coverage android-app.build.debug android-app.connected-test android-app.resolve.device android-app.resolve.network android-app.install android-app.smoke.emulator \
	desktop.package.macos.arm64 desktop.package.macos.intel desktop.package.linux \
	app.install app.run app.check app.test app.test.unit app.test.scripts app.test.api-paths app.test.core app.test.chat app.test.widgets app.test.features app.test.integration.smoke app.test.integration.network app.test.integration.auth app.test.integration.contract app.test.integration.device app.test.integration.device.auth app.test.integration.device.contract app.test.integration.device.reverse app.test.integration.device.auth.reverse app.test.ios-device-acceptance app.test.ios-permission-acceptance app.test.ios-file-picker-acceptance app.test.patrol.harness app.test.patrol.login app.test.patrol.dual app.test.patrol.cross app.test.patrol.cross-offline app.test.patrol.group app.test.patrol.group-mute app.test.patrol.group-member-removal app.test.patrol.image-attachment app.test.patrol.rich-attachment app.test.patrol.network app.test.patrol.contact app.test.patrol.offline app.test.patrol.pages app.test.patrol.layout app.test.patrol.permission app.build.android app.build.ios app.proto \
	website.install website.up website.down website.logs website.build website.test website.test.unit website.test.download \
	tests.all tests.compose.config tests.tooling tests.mocks.external tests.perf.check \
	api-up api-down api-logs api-ps \
	admin-up admin-down admin-logs \
	desktop-up desktop-down desktop-logs \
	h5-app-up h5-app-down h5-app-logs \
	website-up website-down website-logs

im-ui.install: ## 安装 IM UI 预览测试依赖
	@$(call require_cmd,$(BUN))
	@cd "$(IM_UI_DIR)" && $(BUN) install --frozen-lockfile

im-ui.test: ## 运行 IM UI 预览三设备 Playwright 回归
	@$(call require_cmd,$(BUN))
	@if lsof -tiTCP:$(IM_UI_PORT) -sTCP:LISTEN >/dev/null 2>&1; then lsof -tiTCP:$(IM_UI_PORT) -sTCP:LISTEN | xargs kill -9; fi
	@cd "$(IM_UI_DIR)" && $(BUN) run test:e2e

im-ui.test.visual: ## 生成 IM UI 预览三设备人工评审截图
	@$(call require_cmd,$(BUN))
	@if lsof -tiTCP:$(IM_UI_PORT) -sTCP:LISTEN >/dev/null 2>&1; then lsof -tiTCP:$(IM_UI_PORT) -sTCP:LISTEN | xargs kill -9; fi
	@cd "$(IM_UI_DIR)" && $(BUN) run test:e2e:visual

help: ## 显示所有可用命令
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_.-]+:.*## / {printf "%-28s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

crg.build: ## 手工完整构建 Code Review Graph 本地图数据
	@$(call require_cmd,uvx)
	@$(CRG) build --repo "$(ROOT_DIR)"

crg.update: ## 手工增量更新 Code Review Graph 本地图数据
	@$(call require_cmd,uvx)
	@$(CRG) update --repo "$(ROOT_DIR)"

crg.status: ## 手工查看 Code Review Graph 本地图状态
	@$(call require_cmd,uvx)
	@$(CRG) status --repo "$(ROOT_DIR)"

crg.review: ## 手工审查当前改动影响（可传 BASE=<git-ref>，默认 HEAD~1）
	@$(call require_cmd,uvx)
	@echo "[crg] 审查基线: $(CRG_BASE)"
	@$(CRG) detect-changes --repo "$(ROOT_DIR)" --base "$(CRG_BASE)" --brief

status: ## 查看各模块状态（api / admin / desktop / h5-app / app / website）
	@echo "[api]"
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
	@echo "[app]"
	@echo "run command: make app.run APP_ENV=$(APP_ENV) FLUTTER_DEVICE=$(FLUTTER_DEVICE)"
	@echo
	@echo "[h5-app]"
	@if $(SCREEN) -ls 2>/dev/null | grep -q "[[:digit:]]\\.$(H5_APP_SCREEN)"; then echo "screen: running ($(H5_APP_SCREEN))"; else echo "screen: stopped"; fi
	@if lsof -nP -iTCP:$(H5_APP_PORT) -sTCP:LISTEN >/dev/null 2>&1; then echo "port $(H5_APP_PORT): listening"; else echo "port $(H5_APP_PORT): stopped"; fi
	@echo
	@echo "[website]"
	@if $(SCREEN) -ls 2>/dev/null | grep -q "[[:digit:]]\\.$(WEBSITE_SCREEN)"; then echo "screen: running ($(WEBSITE_SCREEN))"; else echo "screen: stopped"; fi
	@if lsof -nP -iTCP:$(WEBSITE_PORT) -sTCP:LISTEN >/dev/null 2>&1; then echo "port $(WEBSITE_PORT): listening"; else echo "port $(WEBSITE_PORT): stopped"; fi
	@echo
	@echo "[android-app]"
	@if [ -x "$(ADB)" ]; then "$(ADB)" devices -l | sed -n '1,6p'; else echo "adb: unavailable ($(ADB))"; fi

install.all: ## 安装 admin / desktop / h5-app / website 依赖，并拉取 app 依赖
	@$(MAKE) admin.install
	@$(MAKE) desktop.install
	@$(MAKE) h5-app.install
	@$(MAKE) website.install
	@$(MAKE) app.install

test.all: ## 运行仓库全量自包含回归（不启动 live dev 联调服务）
	@$(MAKE) api.test
	@$(MAKE) api.test.smoke
	@$(MAKE) api.migration.guard
	@$(MAKE) app.check
	@$(MAKE) app.test.scripts
	@$(MAKE) app.test.unit
	@$(MAKE) app.test.integration.smoke
	@$(MAKE) admin.check
	@$(MAKE) admin.test.routes
	@$(MAKE) desktop.check
	@$(MAKE) desktop.test.unit
	@$(MAKE) h5-app.check
	@$(MAKE) h5-app.test.unit
	@$(MAKE) website.test.unit
	@$(MAKE) tests.compose.config
	@$(MAKE) tests.mocks.external
	@$(MAKE) tests.tooling
	@$(MAKE) tests.perf.check

test.live: ## 启动 api/admin dev 并运行 Flutter app/admin/desktop 真实后端联调 smoke
	@$(MAKE) api.up
	@$(MAKE) api.wait
	@$(MAKE) admin.up
	@$(MAKE) admin.wait
	@$(MAKE) app.test.integration.network
	@$(MAKE) app.test.integration.auth
	@$(MAKE) app.test.integration.contract
	@$(MAKE) admin.test.live
	@$(MAKE) desktop.test.live

dev.up: ## 启动常用开发链路（api + admin + h5-app + website）
	@$(MAKE) api.up
	@$(MAKE) admin.up
	@$(MAKE) h5-app.up
	@$(MAKE) website.up

dev.down: ## 停止常用开发链路（website + h5-app + admin + desktop + api）
	@$(MAKE) website.down
	@$(MAKE) h5-app.down
	@$(MAKE) admin.down
	@$(MAKE) desktop.down
	@$(MAKE) api.down

dev.logs: ## 提示查看各模块日志命令
	@echo "api: make api.logs"
	@echo "admin:   make admin.logs"
	@echo "desktop: make desktop.logs"
	@echo "h5-app:  make h5-app.logs"
	@echo "website: make website.logs"

api.up: ## 启动 api 开发栈（api + postgres + redis）
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_COMPOSE_FILE)" up -d $(API_SERVICE)
	@echo "[api] 已启动，健康检查地址: http://localhost:$(API_PORT)/healthz"

api.down: ## 停止 api 开发栈（保留数据卷）
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_COMPOSE_FILE)" down

api.restart: ## 重启 api 容器
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_COMPOSE_FILE)" restart $(API_SERVICE)

api.reset: ## 停止 api 开发栈并删除数据卷
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_COMPOSE_FILE)" down -v --remove-orphans

api.wait: ## 等待本机 api dev readyz 就绪
	@$(call require_cmd,$(CURL))
	@for i in $$(seq 1 300); do \
		if $(CURL) -fsS "http://127.0.0.1:$(API_PORT)/readyz" >/dev/null 2>&1; then \
			echo "[api] ready: http://127.0.0.1:$(API_PORT)"; \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "[api] 等待 readyz 超时: http://127.0.0.1:$(API_PORT)/readyz" >&2; \
	exit 1

api.logs: ## 跟随查看 api 日志
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_COMPOSE_FILE)" logs -f --tail=200 $(API_SERVICE)

api.ps: ## 查看 api 开发栈容器状态
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_COMPOSE_FILE)" ps

api.test: api.test.unit api.test.integration ## 运行 api 默认 Rust 测试集

api.test.unit: ## 在 Docker Compose 测试容器内运行 api Rust 单元测试（cargo test --lib）
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" run --rm --no-deps rust-tests cargo test --lib

api.test.integration: ## 在 Docker Compose 测试容器内运行 api Rust 集成测试（pg/redis/external-mock 均不映射宿主端口）
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" up -d --wait postgres redis external-mock
	@$(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" run --rm rust-tests cargo test --tests -- --test-threads=1

api.test.deps.down: ## 停止 api 集成测试依赖栈
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" down -v --remove-orphans

api.test.smoke: ## 使用 Docker Compose 启动 api 并在 Compose 网络内执行健康检查
	@$(call require_cmd,$(DOCKER))
	@$(MAKE) api.test.build
	@$(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" rm -sf api-release-local >/dev/null 2>&1 || true
	@$(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" up -d --wait --force-recreate api
	@$(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" run --rm api-smoke

api.test.build: ## 在 Docker Compose 测试容器内编译 api debug 二进制（供 smoke / perf 复用）
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" run --rm --no-deps rust-tests cargo build --bin redcode-im-api

api.test.build.release: ## 在 Docker Compose 测试容器内编译 api release 二进制（供 release perf 复用）
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" run --rm --no-deps rust-tests cargo build --release --bin redcode-im-api

api.test.images: ## 构建 api 测试栈本地镜像（Dockerfile / external-mock 变更后手动执行）
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" build rust-tests external-mock api

api.perf: api.perf.healthz api.perf.readyz api.perf.auth api.perf.ws.connect api.perf.ws.join api.perf.ws.broadcast ## 顺序执行 api 默认性能基线（Compose 内 api + pg + redis + mock）

api.perf.run: ## 运行单个 api 性能场景（覆盖 PERF_SCENARIO / PERF_DURATION_SECONDS / PERF_CONCURRENCY）
	@$(call require_cmd,$(DOCKER))
	@$(MAKE) api.test.build
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" rm -sf api-release-local >/dev/null 2>&1 || true
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" up -d --wait --force-recreate api
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" run --rm --no-deps api-perf

api.perf.smoke: ## 轻量运行 api 性能工具自检（5s / 4 并发）
	@$(call require_cmd,$(DOCKER))
	@$(MAKE) api.test.build
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" rm -sf api-release-local >/dev/null 2>&1 || true
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" up -d --wait --force-recreate api
	@$(API_PERF_ENV) PERF_SCENARIO=healthz PERF_DURATION_SECONDS=5 PERF_WARMUP_SECONDS=0 PERF_CONCURRENCY=4 PERF_REPORT_NAME=smoke-$$(date +%Y%m%d-%H%M%S).json $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" run --rm --no-deps api-perf

api.perf.healthz: ## 压测 /healthz API 框架基线
	@$(call require_cmd,$(DOCKER))
	@$(MAKE) api.test.build
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" rm -sf api-release-local >/dev/null 2>&1 || true
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" up -d --wait --force-recreate api
	@$(API_PERF_ENV) PERF_SCENARIO=healthz PERF_CONCURRENCY=$(PERF_HEALTHZ_CONCURRENCY) PERF_REPORT_NAME=healthz-$$(date +%Y%m%d-%H%M%S).json $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" run --rm --no-deps api-perf

api.perf.readyz: ## 压测 /readyz 依赖就绪基线（DB / Redis）
	@$(call require_cmd,$(DOCKER))
	@$(MAKE) api.test.build
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" rm -sf api-release-local >/dev/null 2>&1 || true
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" up -d --wait --force-recreate api
	@$(API_PERF_ENV) PERF_SCENARIO=readyz PERF_CONCURRENCY=$(PERF_READYZ_CONCURRENCY) PERF_REQUEST_INTERVAL_MS=$(PERF_READYZ_INTERVAL_MS) PERF_REPORT_NAME=readyz-$$(date +%Y%m%d-%H%M%S).json $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" run --rm --no-deps api-perf

api.perf.auth: ## 压测普通账号注册 + 登录业务链路
	@$(call require_cmd,$(DOCKER))
	@$(MAKE) api.test.build
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" rm -sf api-release-local >/dev/null 2>&1 || true
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" up -d --wait --force-recreate api
	@$(API_PERF_ENV) PERF_SCENARIO=auth-register-login PERF_CONCURRENCY=$(PERF_AUTH_CONCURRENCY) PERF_TIMEOUT_MS=$(PERF_AUTH_TIMEOUT_MS) PERF_REPORT_NAME=auth-register-login-$$(date +%Y%m%d-%H%M%S).json $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" run --rm --no-deps api-perf

api.perf.ws.connect: ## 压测 WebSocket 连接认证 + ping/pong
	@$(call require_cmd,$(DOCKER))
	@$(MAKE) api.test.build
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" rm -sf api-release-local >/dev/null 2>&1 || true
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" up -d --wait --force-recreate api
	@$(API_PERF_ENV) PERF_SCENARIO=ws-connect-ping PERF_CONCURRENCY=$(PERF_WS_CONNECT_CONCURRENCY) PERF_TIMEOUT_MS=$(PERF_WS_TIMEOUT_MS) PERF_REPORT_NAME=ws-connect-ping-$$(date +%Y%m%d-%H%M%S).json $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" run --rm --no-deps api-perf

api.perf.ws.join: ## 压测 WebSocket 连接认证 + 房间订阅
	@$(call require_cmd,$(DOCKER))
	@$(MAKE) api.test.build
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" rm -sf api-release-local >/dev/null 2>&1 || true
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" up -d --wait --force-recreate api
	@$(API_PERF_ENV) PERF_SCENARIO=ws-connect-join PERF_CONCURRENCY=$(PERF_WS_CONNECT_CONCURRENCY) PERF_TIMEOUT_MS=$(PERF_WS_TIMEOUT_MS) PERF_REPORT_NAME=ws-connect-join-$$(date +%Y%m%d-%H%M%S).json $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" run --rm --no-deps api-perf

api.perf.ws.broadcast: ## 压测 WebSocket 房间广播链路（REST 发消息 -> Redis PubSub -> WS 推送）
	@$(call require_cmd,$(DOCKER))
	@$(MAKE) api.test.build
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" rm -sf api-release-local >/dev/null 2>&1 || true
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" up -d --wait --force-recreate api
	@$(API_PERF_ENV) PERF_SCENARIO=ws-room-broadcast PERF_WS_CLIENTS=$(PERF_WS_BROADCAST_CLIENTS) PERF_WS_MESSAGES=$(PERF_WS_BROADCAST_MESSAGES) PERF_TIMEOUT_MS=$(PERF_WS_TIMEOUT_MS) PERF_REPORT_NAME=ws-room-broadcast-$$(date +%Y%m%d-%H%M%S).json $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" run --rm --no-deps api-perf

api.perf.release: api.perf.release.healthz api.perf.release.readyz api.perf.release.auth api.perf.release.ws.connect api.perf.release.ws.join api.perf.release.ws.broadcast ## 顺序执行 api release 二进制性能基线

api.perf.release.small: ## 固定小规格 release 基线（API 1C/512M，PG/Redis 给足）
	@$(MAKE) api.perf.release \
		API_SERVICE_CPUS=1.0 API_SERVICE_MEMORY=512m \
		DATABASE_PERF_MAX_CONNECTIONS=40 DATABASE_PERF_MIN_CONNECTIONS=4 \
		PERF_HEALTHZ_CONCURRENCY=32 PERF_AUTH_CONCURRENCY=2 \
		PERF_WS_CONNECT_CONCURRENCY=4 PERF_WS_BROADCAST_CLIENTS=8 \
		API_PERF_REPORT_PREFIX=release-small

api.perf.release.standard: ## 固定标准 release 基线（API 2C/1G，默认对外指标口径）
	@$(MAKE) api.perf.release \
		API_SERVICE_CPUS=2.0 API_SERVICE_MEMORY=1g \
		DATABASE_PERF_MAX_CONNECTIONS=80 DATABASE_PERF_MIN_CONNECTIONS=8 \
		PERF_HEALTHZ_CONCURRENCY=64 PERF_AUTH_CONCURRENCY=4 \
		PERF_WS_CONNECT_CONCURRENCY=8 PERF_WS_BROADCAST_CLIENTS=16 \
		API_PERF_REPORT_PREFIX=release-standard

api.perf.release.large: ## 固定大规格 release 基线（API 4C/2G，PG/Redis 给足）
	@$(MAKE) api.perf.release \
		API_SERVICE_CPUS=4.0 API_SERVICE_MEMORY=2g \
		POSTGRES_PERF_CPUS=6.0 POSTGRES_PERF_MEMORY=6g \
		REDIS_PERF_CPUS=2.0 REDIS_PERF_MEMORY=1g \
		DATABASE_PERF_MAX_CONNECTIONS=160 DATABASE_PERF_MIN_CONNECTIONS=16 \
		PERF_HEALTHZ_CONCURRENCY=128 PERF_AUTH_CONCURRENCY=8 \
		PERF_WS_CONNECT_CONCURRENCY=16 PERF_WS_BROADCAST_CLIENTS=32 \
		API_PERF_REPORT_PREFIX=release-large

api.perf.release.healthz: ## 使用 release 二进制压测 /healthz API 框架基线
	@$(call require_cmd,$(DOCKER))
	@$(MAKE) api.test.build.release
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" rm -sf api >/dev/null 2>&1 || true
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" up -d --wait --force-recreate api-release-local
	@$(API_PERF_ENV) API_RUNTIME=release API_BASE_URL=http://api-release-local:8010 PERF_SCENARIO=healthz PERF_CONCURRENCY=$(PERF_HEALTHZ_CONCURRENCY) PERF_REPORT_NAME=$(API_PERF_REPORT_PREFIX)-healthz-$$(date +%Y%m%d-%H%M%S).json $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" run --rm --no-deps api-perf

api.perf.release.readyz: ## 使用 release 二进制低频探测 /readyz
	@$(call require_cmd,$(DOCKER))
	@$(MAKE) api.test.build.release
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" rm -sf api >/dev/null 2>&1 || true
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" up -d --wait --force-recreate api-release-local
	@$(API_PERF_ENV) API_RUNTIME=release API_BASE_URL=http://api-release-local:8010 PERF_SCENARIO=readyz PERF_CONCURRENCY=$(PERF_READYZ_CONCURRENCY) PERF_REQUEST_INTERVAL_MS=$(PERF_READYZ_INTERVAL_MS) PERF_REPORT_NAME=$(API_PERF_REPORT_PREFIX)-readyz-$$(date +%Y%m%d-%H%M%S).json $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" run --rm --no-deps api-perf

api.perf.release.auth: ## 使用 release 二进制压测普通账号注册 + 登录业务链路
	@$(call require_cmd,$(DOCKER))
	@$(MAKE) api.test.build.release
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" rm -sf api >/dev/null 2>&1 || true
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" up -d --wait --force-recreate api-release-local
	@$(API_PERF_ENV) API_RUNTIME=release API_BASE_URL=http://api-release-local:8010 PERF_SCENARIO=auth-register-login PERF_CONCURRENCY=$(PERF_AUTH_CONCURRENCY) PERF_TIMEOUT_MS=$(PERF_AUTH_TIMEOUT_MS) PERF_REPORT_NAME=$(API_PERF_REPORT_PREFIX)-auth-register-login-$$(date +%Y%m%d-%H%M%S).json $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" run --rm --no-deps api-perf

api.perf.release.ws.connect: ## 使用 release 二进制压测 WebSocket 连接认证 + ping/pong
	@$(call require_cmd,$(DOCKER))
	@$(MAKE) api.test.build.release
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" rm -sf api >/dev/null 2>&1 || true
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" up -d --wait --force-recreate api-release-local
	@$(API_PERF_ENV) API_RUNTIME=release API_BASE_URL=http://api-release-local:8010 PERF_SCENARIO=ws-connect-ping PERF_CONCURRENCY=$(PERF_WS_CONNECT_CONCURRENCY) PERF_TIMEOUT_MS=$(PERF_WS_TIMEOUT_MS) PERF_REPORT_NAME=$(API_PERF_REPORT_PREFIX)-ws-connect-ping-$$(date +%Y%m%d-%H%M%S).json $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" run --rm --no-deps api-perf

api.perf.release.ws.join: ## 使用 release 二进制压测 WebSocket 连接认证 + 房间订阅
	@$(call require_cmd,$(DOCKER))
	@$(MAKE) api.test.build.release
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" rm -sf api >/dev/null 2>&1 || true
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" up -d --wait --force-recreate api-release-local
	@$(API_PERF_ENV) API_RUNTIME=release API_BASE_URL=http://api-release-local:8010 PERF_SCENARIO=ws-connect-join PERF_CONCURRENCY=$(PERF_WS_CONNECT_CONCURRENCY) PERF_TIMEOUT_MS=$(PERF_WS_TIMEOUT_MS) PERF_REPORT_NAME=$(API_PERF_REPORT_PREFIX)-ws-connect-join-$$(date +%Y%m%d-%H%M%S).json $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" run --rm --no-deps api-perf

api.perf.release.ws.broadcast: ## 使用 release 二进制压测 WebSocket 房间广播链路
	@$(call require_cmd,$(DOCKER))
	@$(MAKE) api.test.build.release
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" rm -sf api >/dev/null 2>&1 || true
	@$(API_PERF_ENV) $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" up -d --wait --force-recreate api-release-local
	@$(API_PERF_ENV) API_RUNTIME=release API_BASE_URL=http://api-release-local:8010 PERF_SCENARIO=ws-room-broadcast PERF_WS_CLIENTS=$(PERF_WS_BROADCAST_CLIENTS) PERF_WS_MESSAGES=$(PERF_WS_BROADCAST_MESSAGES) PERF_TIMEOUT_MS=$(PERF_WS_TIMEOUT_MS) PERF_REPORT_NAME=$(API_PERF_REPORT_PREFIX)-ws-room-broadcast-$$(date +%Y%m%d-%H%M%S).json $(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" run --rm --no-deps api-perf

api.perf.down: ## 停止 api 性能测试栈（保留 cargo cache 与报告文件）
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" down --remove-orphans

api.migration.guard: ## 校验 api SQL 迁移只允许新增，禁止修改/重命名/删除已提交迁移
	@bash "$(ROOT_DIR)/api/scripts/migration-guard.sh"

migration.guard: api.migration.guard ## 兼容旧入口：校验 api SQL 迁移

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

admin.wait: ## 等待本机 admin dev 就绪
	@$(call require_cmd,$(CURL))
	@for i in $$(seq 1 90); do \
		if $(CURL) -fsS "$(ADMIN_BASE_URL)" >/dev/null 2>&1; then \
			echo "[admin] ready: $(ADMIN_BASE_URL)"; \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "[admin] 等待 dev server 超时: $(ADMIN_BASE_URL)" >&2; \
	exit 1

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

admin.test.live: ## 执行 admin 真实后端联调 smoke（需 api/admin dev 就绪）
	@$(call require_cmd,$(BUN))
	@cd "$(ADMIN_DIR)" && ADMIN_BASE_URL="$(ADMIN_BASE_URL)" ADMIN_API_BASE_URL="$(ADMIN_API_BASE_URL)" $(BUN) run test:e2e:live

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

desktop.test.live: ## 执行 desktop 真实后端 smoke（healthz + 普通账号注册/登录 + WS open）
	@$(call require_cmd,$(BUN))
	@cd "$(DESKTOP_DIR)" && DESKTOP_LIVE_BACKEND_ENABLED=true DESKTOP_API_BASE_URL="$(DESKTOP_API_BASE_URL)" DESKTOP_WS_URL="$(DESKTOP_WS_URL)" $(BUN) run test -- test/api/live-backend-smoke.test.ts

desktop.package.macos.arm64: ## 打包 macOS Apple Silicon（默认 ad-hoc 签名）
	@cd "$(DESKTOP_DIR)" && ./scripts/build-macos.sh arm64

desktop.package.macos.intel: ## 打包 macOS Intel（默认 ad-hoc 签名）
	@cd "$(DESKTOP_DIR)" && ./scripts/build-macos.sh intel

desktop.package.linux: ## 打包 Linux AppImage
	@cd "$(DESKTOP_DIR)" && ./scripts/build-linux.sh stable-linux

app.install: ## 获取 app Flutter 依赖
	@$(call require_cmd,$(FLUTTER))
	@cd "$(APP_DIR)" && $(FLUTTER) pub get

app.run: ## 运行 app（可覆盖 APP_ENV / FLUTTER_DEVICE）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(APP_DIR)" && if [ -n "$(FLUTTER_DEVICE)" ]; then ./scripts/run.sh --env "$(APP_ENV)" "$(FLUTTER_DEVICE)"; else ./scripts/run.sh --env "$(APP_ENV)"; fi

app.check: ## 执行 app Flutter analyze
	@$(call require_cmd,$(FLUTTER))
	@cd "$(APP_DIR)" && $(FLUTTER) analyze

app.test: app.test.unit ## 执行 app 默认 Flutter 测试

app.test.unit: ## 执行 app 全量 Flutter test
	@$(call require_cmd,$(FLUTTER))
	@cd "$(APP_DIR)" && $(FLUTTER) test

app.test.scripts: ## 执行 app shell 脚本契约测试
	@cd "$(APP_DIR)" && ./scripts/test_integration_contract_test.sh
	@cd "$(APP_DIR)" && ./scripts/xcode_clang_probe_wrapper_contract_test.sh
	@cd "$(APP_DIR)" && ./scripts/test_patrol_dual_device_contract_test.sh
	@cd "$(APP_DIR)" && ./scripts/test_network_fault_proxy.sh
	@$(MAKE) app.test.api-paths

app.test.api-paths: ## 校验 Flutter REST path 均已在 API routes.rs 注册
	@python3 "$(APP_DIR)/scripts/verify_api_paths.py"

app.test.core: ## 执行 app core 测试
	@$(call require_cmd,$(FLUTTER))
	@cd "$(APP_DIR)" && $(FLUTTER) test test/core

app.test.chat: ## 执行 app chat 测试
	@$(call require_cmd,$(FLUTTER))
	@cd "$(APP_DIR)" && $(FLUTTER) test test/chat

app.test.widgets: ## 执行 app widgets 测试
	@$(call require_cmd,$(FLUTTER))
	@cd "$(APP_DIR)" && $(FLUTTER) test test/widgets

app.test.features: ## 执行 app features 模型测试
	@$(call require_cmd,$(FLUTTER))
	@cd "$(APP_DIR)" && $(FLUTTER) test test/features

app.test.integration.smoke: ## 执行 app integration smoke（不访问真实 api）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(APP_DIR)" && APP_TEST_DEVICE="$(APP_SELECTED_TEST_DEVICE)" ./scripts/test_integration.sh smoke

app.test.integration.network: ## 执行 app network integration（默认验收设备；非真机可覆盖 APP_API_BASE_URL / APP_WS_URL）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(APP_DIR)" && APP_TEST_DEVICE="$(APP_SELECTED_TEST_DEVICE)" API_BASE_URL="$(APP_API_BASE_URL)" WS_URL="$(APP_WS_URL)" ./scripts/test_integration.sh network

app.test.integration.auth: ## 执行 app 真实普通账号注册/登录 integration（默认验收设备；非真机可覆盖 APP_API_BASE_URL / APP_WS_URL）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(APP_DIR)" && APP_TEST_DEVICE="$(APP_SELECTED_TEST_DEVICE)" API_BASE_URL="$(APP_API_BASE_URL)" WS_URL="$(APP_WS_URL)" ./scripts/test_integration.sh auth

app.test.integration.contract: ## 执行 app 真实 API 合同 integration（认证/好友/群/消息/设置）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(APP_DIR)" && APP_TEST_DEVICE="$(APP_SELECTED_TEST_DEVICE)" API_BASE_URL="$(APP_API_BASE_URL)" WS_URL="$(APP_WS_URL)" ./scripts/test_integration.sh contract

app.test.integration.device: ## 执行 app 设备 network integration（默认本机 iOS Simulator）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(APP_DIR)" && APP_TEST_DEVICE="$(APP_SELECTED_TEST_DEVICE)" ./scripts/test_integration.sh device

app.test.integration.device.auth: ## 执行 app 设备真实普通账号注册/登录 integration（默认本机 iOS Simulator）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(APP_DIR)" && APP_TEST_DEVICE="$(APP_SELECTED_TEST_DEVICE)" ./scripts/test_integration.sh device --target integration_test/auth_account_flow_test.dart

app.test.integration.device.contract: app.test.integration.contract ## app.test.integration.contract 的设备联调别名

app.test.integration.device.reverse: ## 执行 app Android 真机 network integration（adb reverse，必须显式指定设备）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(APP_DIR)" && APP_TEST_DEVICE="$(APP_SELECTED_TEST_DEVICE)" ./scripts/test_integration.sh device-reverse

app.test.integration.device.auth.reverse: ## 执行 app Android 真机真实普通账号注册/登录 integration（adb reverse，必须显式指定设备）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(APP_DIR)" && APP_TEST_DEVICE="$(APP_SELECTED_TEST_DEVICE)" ./scripts/test_integration.sh device-reverse --target integration_test/auth_account_flow_test.dart

app.test.patrol.harness: ## 执行 app Patrol harness smoke（可覆盖 PATROL_DEVICE / PATROL_*_PORT）
	@$(call require_cmd,$(PATROL))
	@cd "$(APP_DIR)" && PATH="$$HOME/Library/Android/sdk/platform-tools:$$PATH" JAVA_HOME="$${JAVA_HOME:-$(PATROL_JAVA_HOME)}" CC="$(APP_IOS_CLANG_WRAPPER)" $(PATROL) test -t patrol_test/harness_smoke_test.dart -d "$(PATROL_DEVICE)" --test-server-port "$(PATROL_TEST_SERVER_PORT)" --app-server-port "$(PATROL_APP_SERVER_PORT)"

app.test.patrol.login: ## 执行 app Patrol 登录与 P0 导航 smoke（mock 模式，可覆盖 PATROL_DEVICE / PATROL_*_PORT）
	@$(call require_cmd,$(PATROL))
	@cd "$(APP_DIR)" && PATH="$$HOME/Library/Android/sdk/platform-tools:$$PATH" JAVA_HOME="$${JAVA_HOME:-$(PATROL_JAVA_HOME)}" CC="$(APP_IOS_CLANG_WRAPPER)" $(PATROL) test -t patrol_test/login_smoke_test.dart -d "$(PATROL_DEVICE)" --test-server-port "$(PATROL_TEST_SERVER_PORT)" --app-server-port "$(PATROL_APP_SERVER_PORT)" --dart-define USE_MOCK_DATA=true --dart-define API_BASE_URL=http://127.0.0.1:1 --dart-define WS_URL=ws://127.0.0.1:1/ws

app.test.patrol.dual: ## 执行双 iOS Simulator 真实私聊互发（必须传设备 UUID、账号和密码）
	@cd "$(APP_DIR)" && DUAL_DEVICE_A="$(PATROL_DUAL_DEVICE_A)" DUAL_DEVICE_B="$(PATROL_DUAL_DEVICE_B)" DUAL_ACCOUNT_A="$(PATROL_DUAL_ACCOUNT_A)" DUAL_ACCOUNT_B="$(PATROL_DUAL_ACCOUNT_B)" DUAL_PASSWORD="$(PATROL_DUAL_PASSWORD)" ./scripts/test_patrol_dual_device.sh

app.test.patrol.cross: ## 执行 iOS Simulator(A) 与 Android Emulator(B) 真实私聊互发
	@cd "$(APP_DIR)" && JAVA_HOME="$(PATROL_JAVA_HOME)" DUAL_API_BASE_URL_A=http://127.0.0.1:8010 DUAL_WS_URL_A=ws://127.0.0.1:8010/ws DUAL_API_BASE_URL_B=http://10.0.2.2:8010 DUAL_WS_URL_B=ws://10.0.2.2:8010/ws DUAL_DEVICE_A="$(PATROL_CROSS_IOS_DEVICE)" DUAL_DEVICE_B="$(PATROL_CROSS_ANDROID_DEVICE)" DUAL_ACCOUNT_A="$(PATROL_CROSS_IOS_ACCOUNT)" DUAL_ACCOUNT_B="$(PATROL_CROSS_ANDROID_ACCOUNT)" DUAL_PASSWORD="$(PATROL_CROSS_PASSWORD)" ./scripts/test_patrol_dual_device.sh

app.test.patrol.cross-offline: ## 执行 Android Emulator(A) 与 iOS Simulator(B) 前后台重连和离线恢复
	@cd "$(APP_DIR)" && JAVA_HOME="$(PATROL_JAVA_HOME)" DUAL_TEST_TARGET=patrol_test/offline_recovery_test.dart DUAL_API_BASE_URL_A=http://10.0.2.2:8010 DUAL_WS_URL_A=ws://10.0.2.2:8010/ws DUAL_API_BASE_URL_B=http://127.0.0.1:8010 DUAL_WS_URL_B=ws://127.0.0.1:8010/ws DUAL_DEVICE_A="$(PATROL_CROSS_ANDROID_DEVICE)" DUAL_DEVICE_B="$(PATROL_CROSS_IOS_DEVICE)" DUAL_ACCOUNT_A="$(PATROL_CROSS_ANDROID_ACCOUNT)" DUAL_ACCOUNT_B="$(PATROL_CROSS_IOS_ACCOUNT)" DUAL_PASSWORD="$(PATROL_CROSS_PASSWORD)" ./scripts/test_patrol_dual_device.sh

app.test.patrol.group: ## 执行双 iOS Simulator 真实建群与群聊互发（必须传设备 UUID、账号和密码）
	@cd "$(APP_DIR)" && DUAL_TEST_TARGET=patrol_test/group_chat_test.dart DUAL_COMPLETION_EVENT=DUAL_GROUP_COMPLETE DUAL_DEVICE_A="$(PATROL_DUAL_DEVICE_A)" DUAL_DEVICE_B="$(PATROL_DUAL_DEVICE_B)" DUAL_ACCOUNT_A="$(PATROL_DUAL_ACCOUNT_A)" DUAL_ACCOUNT_B="$(PATROL_DUAL_ACCOUNT_B)" DUAL_PASSWORD="$(PATROL_DUAL_PASSWORD)" ./scripts/test_patrol_dual_device.sh

app.test.patrol.group-mute: ## 执行双 iOS Simulator 群聊禁言状态同步（必须传设备 UUID、账号和密码）
	@cd "$(APP_DIR)" && DUAL_TEST_TARGET=patrol_test/group_mute_test.dart DUAL_COMPLETION_EVENT=DUAL_GROUP_MUTE_COMPLETE DUAL_DEVICE_A="$(PATROL_DUAL_DEVICE_A)" DUAL_DEVICE_B="$(PATROL_DUAL_DEVICE_B)" DUAL_ACCOUNT_A="$(PATROL_DUAL_ACCOUNT_A)" DUAL_ACCOUNT_B="$(PATROL_DUAL_ACCOUNT_B)" DUAL_PASSWORD="$(PATROL_DUAL_PASSWORD)" ./scripts/test_patrol_dual_device.sh

app.test.patrol.group-member-removal: ## 执行双 iOS Simulator 群成员移除状态同步（必须传设备 UUID、账号和密码）
	@cd "$(APP_DIR)" && DUAL_TEST_TARGET=patrol_test/group_member_removal_test.dart DUAL_COMPLETION_EVENT=DUAL_GROUP_MEMBER_REMOVAL_COMPLETE DUAL_DEVICE_A="$(PATROL_DUAL_DEVICE_A)" DUAL_DEVICE_B="$(PATROL_DUAL_DEVICE_B)" DUAL_ACCOUNT_A="$(PATROL_DUAL_ACCOUNT_A)" DUAL_ACCOUNT_B="$(PATROL_DUAL_ACCOUNT_B)" DUAL_PASSWORD="$(PATROL_DUAL_PASSWORD)" ./scripts/test_patrol_dual_device.sh

app.test.patrol.image-attachment: ## 执行双 iOS Simulator 图片附件上传与下载（必须传设备 UUID、账号和密码）
	@cd "$(APP_DIR)" && DUAL_TEST_TARGET=patrol_test/image_attachment_test.dart DUAL_COMPLETION_EVENT=DUAL_IMAGE_ATTACHMENT_COMPLETE DUAL_DEVICE_A="$(PATROL_DUAL_DEVICE_A)" DUAL_DEVICE_B="$(PATROL_DUAL_DEVICE_B)" DUAL_ACCOUNT_A="$(PATROL_DUAL_ACCOUNT_A)" DUAL_ACCOUNT_B="$(PATROL_DUAL_ACCOUNT_B)" DUAL_PASSWORD="$(PATROL_DUAL_PASSWORD)" ./scripts/test_patrol_dual_device.sh

app.test.patrol.rich-attachment: ## 执行双 iOS Simulator 文件与语音附件上传、下载（必须传设备 UUID、账号和密码）
	@cd "$(APP_DIR)" && DUAL_TEST_TARGET=patrol_test/rich_attachment_test.dart DUAL_COMPLETION_EVENT=DUAL_RICH_ATTACHMENT_COMPLETE DUAL_DEVICE_A="$(PATROL_DUAL_DEVICE_A)" DUAL_DEVICE_B="$(PATROL_DUAL_DEVICE_B)" DUAL_ACCOUNT_A="$(PATROL_DUAL_ACCOUNT_A)" DUAL_ACCOUNT_B="$(PATROL_DUAL_ACCOUNT_B)" DUAL_PASSWORD="$(PATROL_DUAL_PASSWORD)" ./scripts/test_patrol_dual_device.sh

app.test.patrol.network: ## 执行双 iOS Simulator 真实网络中断与恢复（必须传设备 UUID、账号和密码）
	@cd "$(APP_DIR)" && DUAL_DEVICE_A="$(PATROL_DUAL_DEVICE_A)" DUAL_DEVICE_B="$(PATROL_DUAL_DEVICE_B)" DUAL_ACCOUNT_A="$(PATROL_DUAL_ACCOUNT_A)" DUAL_ACCOUNT_B="$(PATROL_DUAL_ACCOUNT_B)" DUAL_PASSWORD="$(PATROL_DUAL_PASSWORD)" ./scripts/test_patrol_dual_network.sh

app.test.patrol.contact: ## 执行双 iOS Simulator 联系人申请、备注与删除闭环（必须传设备 UUID、账号和密码）
	@cd "$(APP_DIR)" && DUAL_TEST_TARGET=patrol_test/contact_lifecycle_test.dart DUAL_IDENTITY_PREFIX=contact DUAL_DEVICE_A="$(PATROL_DUAL_DEVICE_A)" DUAL_DEVICE_B="$(PATROL_DUAL_DEVICE_B)" DUAL_ACCOUNT_A="$(PATROL_DUAL_ACCOUNT_A)" DUAL_ACCOUNT_B="$(PATROL_DUAL_ACCOUNT_B)" DUAL_PASSWORD="$(PATROL_DUAL_PASSWORD)" ./scripts/test_patrol_dual_device.sh

app.test.patrol.offline: ## 执行双 iOS Simulator 前后台重连与离线消息恢复（必须传设备 UUID、账号和密码）
	@cd "$(APP_DIR)" && DUAL_TEST_TARGET=patrol_test/offline_recovery_test.dart DUAL_DEVICE_A="$(PATROL_DUAL_DEVICE_A)" DUAL_DEVICE_B="$(PATROL_DUAL_DEVICE_B)" DUAL_ACCOUNT_A="$(PATROL_DUAL_ACCOUNT_A)" DUAL_ACCOUNT_B="$(PATROL_DUAL_ACCOUNT_B)" DUAL_PASSWORD="$(PATROL_DUAL_PASSWORD)" ./scripts/test_patrol_dual_device.sh

app.test.patrol.pages: ## 执行真实账号 P0 页面导航与滚动巡检（必须传设备 UUID、账号和密码）
	@$(call require_cmd,$(PATROL))
	@test -n "$(PATROL_PAGE_DEVICE)" -a -n "$(PATROL_PAGE_ACCOUNT)" -a -n "$(PATROL_PAGE_PASSWORD)" || (echo "缺少 PATROL_PAGE_DEVICE/ACCOUNT/PASSWORD" >&2; exit 2)
	@cd "$(APP_DIR)" && CC="$(APP_IOS_CLANG_WRAPPER)" $(PATROL) test -t patrol_test/page_navigation_test.dart -d "$(PATROL_PAGE_DEVICE)" --test-server-port "$(PATROL_TEST_SERVER_PORT)" --app-server-port "$(PATROL_APP_SERVER_PORT)" --dart-define PAGE_ACCOUNT="$(PATROL_PAGE_ACCOUNT)" --dart-define PAGE_PASSWORD="$(PATROL_PAGE_PASSWORD)" --dart-define API_BASE_URL=http://127.0.0.1:8010 --dart-define WS_URL=ws://127.0.0.1:8010/ws

app.test.patrol.layout: ## 执行真实账号聊天布局与焦点返回回归（必须传账号、对端账号和密码）
	@$(call require_cmd,$(PATROL))
	@cd "$(APP_DIR)" && CC="$(APP_IOS_CLANG_WRAPPER)" $(PATROL) test -t patrol_test/device_layout_test.dart -d "$(PATROL_LAYOUT_DEVICE)" --test-server-port "$(PATROL_TEST_SERVER_PORT)" --app-server-port "$(PATROL_APP_SERVER_PORT)" --dart-define LAYOUT_ACCOUNT="$(PATROL_LAYOUT_ACCOUNT)" --dart-define LAYOUT_PEER_ACCOUNT="$(PATROL_LAYOUT_PEER_ACCOUNT)" --dart-define LAYOUT_PASSWORD="$(PATROL_LAYOUT_PASSWORD)" --dart-define API_BASE_URL=http://127.0.0.1:8010 --dart-define WS_URL=ws://127.0.0.1:8010/ws

app.test.ios-device-acceptance: ## 执行 iOS Simulator 真实软键盘、遮挡与返回优先级验收
	@test -n "$(APP_IOS_ACCEPTANCE_DEVICE)" -a -n "$(APP_IOS_ACCEPTANCE_ACCOUNT)" -a -n "$(APP_IOS_ACCEPTANCE_PEER_ACCOUNT)" -a -n "$(APP_IOS_ACCEPTANCE_PASSWORD)" || (echo "缺少 APP_IOS_ACCEPTANCE_DEVICE/ACCOUNT/PEER_ACCOUNT/PASSWORD" >&2; exit 2)
	@xcrun simctl bootstatus "$(APP_IOS_ACCEPTANCE_DEVICE)" -b
	@xcrun simctl uninstall "$(APP_IOS_ACCEPTANCE_DEVICE)" com.chatlyme.app 2>/dev/null || true
	@cd "$(APP_DIR)/ios" && result="../build/ios-device-acceptance-$$(date +%s).xcresult" && dart_defines="$$(printf '%s' 'API_BASE_URL=http://127.0.0.1:8010' | base64),$$(printf '%s' 'WS_URL=ws://127.0.0.1:8010/ws' | base64)" && REDCODE_TEST_ACCOUNT="$(APP_IOS_ACCEPTANCE_ACCOUNT)" REDCODE_TEST_PEER_ACCOUNT="$(APP_IOS_ACCEPTANCE_PEER_ACCOUNT)" REDCODE_TEST_PASSWORD="$(APP_IOS_ACCEPTANCE_PASSWORD)" xcodebuild test -quiet -workspace Runner.xcworkspace -scheme Runner -testPlan TestPlan -destination "platform=iOS Simulator,id=$(APP_IOS_ACCEPTANCE_DEVICE)" -only-testing:RunnerUITests/RedCodeDeviceAcceptanceTests/testSystemKeyboardLayoutAndBackPriority -resultBundlePath "$$result" DART_DEFINES="$$dart_defines" 'GCC_PREPROCESSOR_DEFINITIONS=$$(inherited) CLEAR_PERMISSIONS=0 FULL_ISOLATION=0' && echo "iOS 设备验收证据: $(APP_DIR)/$${result#../}"

app.test.ios-permission-acceptance: ## 执行 iOS Simulator 照片/麦克风首次拒绝与设置恢复验收
	@test -n "$(APP_IOS_ACCEPTANCE_DEVICE)" -a -n "$(APP_IOS_ACCEPTANCE_ACCOUNT)" -a -n "$(APP_IOS_ACCEPTANCE_PEER_ACCOUNT)" -a -n "$(APP_IOS_ACCEPTANCE_PASSWORD)" || (echo "缺少 APP_IOS_ACCEPTANCE_DEVICE/ACCOUNT/PEER_ACCOUNT/PASSWORD" >&2; exit 2)
	@xcrun simctl bootstatus "$(APP_IOS_ACCEPTANCE_DEVICE)" -b
	@xcrun simctl terminate "$(APP_IOS_ACCEPTANCE_DEVICE)" com.chatlyme.app 2>/dev/null || true
	@xcrun simctl terminate "$(APP_IOS_ACCEPTANCE_DEVICE)" com.apple.Preferences 2>/dev/null || true
	@xcrun simctl privacy "$(APP_IOS_ACCEPTANCE_DEVICE)" reset all com.chatlyme.app
	@cd "$(APP_DIR)/ios" && result="../build/ios-photo-permission-acceptance-$$(date +%s).xcresult" && dart_defines="$$(printf '%s' 'API_BASE_URL=http://127.0.0.1:8010' | base64),$$(printf '%s' 'WS_URL=ws://127.0.0.1:8010/ws' | base64)" && REDCODE_TEST_ACCOUNT="$(APP_IOS_ACCEPTANCE_ACCOUNT)" REDCODE_TEST_PEER_ACCOUNT="$(APP_IOS_ACCEPTANCE_PEER_ACCOUNT)" REDCODE_TEST_PASSWORD="$(APP_IOS_ACCEPTANCE_PASSWORD)" xcodebuild test -quiet -workspace Runner.xcworkspace -scheme Runner -testPlan TestPlan -destination "platform=iOS Simulator,id=$(APP_IOS_ACCEPTANCE_DEVICE)" -only-testing:RunnerUITests/RedCodeDeviceAcceptanceTests/testPhotoDenialAndSettingsRecovery -resultBundlePath "$$result" DART_DEFINES="$$dart_defines" 'GCC_PREPROCESSOR_DEFINITIONS=$$(inherited) CLEAR_PERMISSIONS=0 FULL_ISOLATION=0' && echo "iOS 照片权限验收证据: $(APP_DIR)/$${result#../}"
	@xcrun simctl terminate "$(APP_IOS_ACCEPTANCE_DEVICE)" com.chatlyme.app 2>/dev/null || true
	@xcrun simctl terminate "$(APP_IOS_ACCEPTANCE_DEVICE)" com.apple.Preferences 2>/dev/null || true
	@xcrun simctl privacy "$(APP_IOS_ACCEPTANCE_DEVICE)" reset microphone com.chatlyme.app
	@cd "$(APP_DIR)/ios" && result="../build/ios-microphone-permission-acceptance-$$(date +%s).xcresult" && dart_defines="$$(printf '%s' 'API_BASE_URL=http://127.0.0.1:8010' | base64),$$(printf '%s' 'WS_URL=ws://127.0.0.1:8010/ws' | base64)" && REDCODE_TEST_ACCOUNT="$(APP_IOS_ACCEPTANCE_ACCOUNT)" REDCODE_TEST_PEER_ACCOUNT="$(APP_IOS_ACCEPTANCE_PEER_ACCOUNT)" REDCODE_TEST_PASSWORD="$(APP_IOS_ACCEPTANCE_PASSWORD)" xcodebuild test -quiet -workspace Runner.xcworkspace -scheme Runner -testPlan TestPlan -destination "platform=iOS Simulator,id=$(APP_IOS_ACCEPTANCE_DEVICE)" -only-testing:RunnerUITests/RedCodeDeviceAcceptanceTests/testMicrophoneDenialAndSettingsRecovery -resultBundlePath "$$result" DART_DEFINES="$$dart_defines" 'GCC_PREPROCESSOR_DEFINITIONS=$$(inherited) CLEAR_PERMISSIONS=0 FULL_ISOLATION=0' && echo "iOS 麦克风权限验收证据: $(APP_DIR)/$${result#../}"
	@xcrun simctl terminate "$(APP_IOS_ACCEPTANCE_DEVICE)" com.chatlyme.app 2>/dev/null || true

app.test.ios-file-picker-acceptance: ## 执行 iOS Simulator 系统文件选择器打开与取消验收
	@test -n "$(APP_IOS_ACCEPTANCE_DEVICE)" -a -n "$(APP_IOS_ACCEPTANCE_ACCOUNT)" -a -n "$(APP_IOS_ACCEPTANCE_PEER_ACCOUNT)" -a -n "$(APP_IOS_ACCEPTANCE_PASSWORD)" || (echo "缺少 APP_IOS_ACCEPTANCE_DEVICE/ACCOUNT/PEER_ACCOUNT/PASSWORD" >&2; exit 2)
	@xcrun simctl bootstatus "$(APP_IOS_ACCEPTANCE_DEVICE)" -b
	@xcrun simctl terminate "$(APP_IOS_ACCEPTANCE_DEVICE)" com.chatlyme.app 2>/dev/null || true
	@cd "$(APP_DIR)/ios" && result="../build/ios-file-picker-acceptance-$$(date +%s).xcresult" && dart_defines="$$(printf '%s' 'API_BASE_URL=http://127.0.0.1:8010' | base64),$$(printf '%s' 'WS_URL=ws://127.0.0.1:8010/ws' | base64)" && REDCODE_TEST_ACCOUNT="$(APP_IOS_ACCEPTANCE_ACCOUNT)" REDCODE_TEST_PEER_ACCOUNT="$(APP_IOS_ACCEPTANCE_PEER_ACCOUNT)" REDCODE_TEST_PASSWORD="$(APP_IOS_ACCEPTANCE_PASSWORD)" xcodebuild test -quiet -workspace Runner.xcworkspace -scheme Runner -testPlan TestPlan -destination "platform=iOS Simulator,id=$(APP_IOS_ACCEPTANCE_DEVICE)" -only-testing:RunnerUITests/RedCodeDeviceAcceptanceTests/testSystemFilePickerCanCancel -resultBundlePath "$$result" DART_DEFINES="$$dart_defines" 'GCC_PREPROCESSOR_DEFINITIONS=$$(inherited) CLEAR_PERMISSIONS=0 FULL_ISOLATION=0' && echo "iOS 文件选择器验收证据: $(APP_DIR)/$${result#../}"
	@xcrun simctl terminate "$(APP_IOS_ACCEPTANCE_DEVICE)" com.chatlyme.app 2>/dev/null || true

app.test.patrol.permission: ## 执行 iOS 相册与麦克风永久拒绝降级验收（必须传 Simulator UUID、账号和密码）
	@$(call require_cmd,$(PATROL))
	@test -n "$(PATROL_PERMISSION_DEVICE)" -a -n "$(PATROL_PERMISSION_ACCOUNT)" -a -n "$(PATROL_PERMISSION_PEER_ACCOUNT)" -a -n "$(PATROL_PERMISSION_PASSWORD)" || (echo "缺少 PATROL_PERMISSION_DEVICE/ACCOUNT/PEER_ACCOUNT/PASSWORD" >&2; exit 2)
	@xcrun simctl privacy "$(PATROL_PERMISSION_DEVICE)" revoke photos com.chatlyme.app
	@xcrun simctl privacy "$(PATROL_PERMISSION_DEVICE)" revoke microphone com.chatlyme.app
	@cd "$(APP_DIR)" && CC="$(APP_IOS_CLANG_WRAPPER)" $(PATROL) test -t patrol_test/permission_flow_test.dart -d "$(PATROL_PERMISSION_DEVICE)" --test-server-port "$(PATROL_TEST_SERVER_PORT)" --app-server-port "$(PATROL_APP_SERVER_PORT)" --dart-define PERMISSION_ACCOUNT="$(PATROL_PERMISSION_ACCOUNT)" --dart-define PERMISSION_PEER_ACCOUNT="$(PATROL_PERMISSION_PEER_ACCOUNT)" --dart-define PERMISSION_PASSWORD="$(PATROL_PERMISSION_PASSWORD)" --dart-define API_BASE_URL=http://127.0.0.1:8010 --dart-define WS_URL=ws://127.0.0.1:8010/ws

app.build.android: ## 构建 Android 安装包（默认 production）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(APP_DIR)" && ./scripts/build_android.sh "$(APP_ANDROID_ENV)"

app.build.ios: ## 构建 iOS IPA（无签名，默认 production）
	@$(call require_cmd,$(FLUTTER))
	@cd "$(APP_DIR)" && ./scripts/build_ipa.sh "$(APP_IOS_ENV)"

app.proto: ## 重新生成 Flutter WebSocket proto
	@cd "$(APP_DIR)" && ./scripts/gen_ws_proto.sh

h5-app.install: ## 安装 h5-app 依赖（bun install）
	@$(call require_cmd,$(BUN))
	@cd "$(H5_APP_DIR)" && $(BUN) install

h5-app.up: ## 启动 h5-app 开发服务（screen: h5-app，port: 8016）
	@$(call require_cmd,$(SCREEN))
	@$(call require_cmd,$(BUN))
	@if $(SCREEN) -ls 2>/dev/null | grep -q "[[:digit:]]\\.$(H5_APP_SCREEN)"; then \
		echo "[h5-app] 停止已有 screen 会话 $(H5_APP_SCREEN)"; \
		$(SCREEN) -S $(H5_APP_SCREEN) -X quit || true; \
	fi
	@if lsof -tiTCP:$(H5_APP_PORT) -sTCP:LISTEN >/dev/null 2>&1; then \
		echo "[h5-app] 清理占用端口 $(H5_APP_PORT) 的进程"; \
		lsof -tiTCP:$(H5_APP_PORT) -sTCP:LISTEN | xargs kill -9; \
	fi
	@echo "[h5-app] 启动中，日志: $(H5_APP_LOG)"
	@$(SCREEN) -dmS $(H5_APP_SCREEN) bash -lc 'cd "$(H5_APP_DIR)" && VITE_API_BASE_URL="$(H5_APP_API_BASE_URL)" exec $(BUN) run dev > "$(H5_APP_LOG)" 2>&1'

h5-app.down: ## 停止 h5-app 开发服务
	@if $(SCREEN) -ls 2>/dev/null | grep -q "[[:digit:]]\\.$(H5_APP_SCREEN)"; then \
		$(SCREEN) -S $(H5_APP_SCREEN) -X quit || true; \
	fi
	@if lsof -tiTCP:$(H5_APP_PORT) -sTCP:LISTEN >/dev/null 2>&1; then \
		lsof -tiTCP:$(H5_APP_PORT) -sTCP:LISTEN | xargs kill -9; \
	fi
	@echo "[h5-app] 已停止"

h5-app.wait: ## 等待 h5-app dev 就绪
	@$(call require_cmd,$(CURL))
	@for i in $$(seq 1 90); do \
		if $(CURL) -fsS "$(H5_APP_BASE_URL)" >/dev/null 2>&1; then \
			echo "[h5-app] ready: $(H5_APP_BASE_URL)"; \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "[h5-app] 等待 dev server 超时: $(H5_APP_BASE_URL)" >&2; \
	exit 1

h5-app.logs: ## 跟随查看 h5-app 日志
	@$(call require_cmd,$(TAIL))
	@test -f "$(H5_APP_LOG)" || { echo "[h5-app] 日志不存在: $(H5_APP_LOG)"; exit 1; }
	@$(TAIL) -n 200 -f "$(H5_APP_LOG)"

e2ee-core.test: ## 运行 E2EE 核心 host 协议测试
	@$(call require_cmd,$(CARGO))
	@$(CARGO) test --manifest-path "$(E2EE_CORE_DIR)/Cargo.toml"

e2ee-core.check: ## 检查 E2EE 核心格式与 host 构建
	@$(call require_cmd,$(CARGO))
	@$(CARGO) fmt --manifest-path "$(E2EE_CORE_DIR)/Cargo.toml" -- --check
	@$(CARGO) check --manifest-path "$(E2EE_CORE_DIR)/Cargo.toml"

e2ee-core.check.targets: ## 检查 E2EE 核心 iOS、Android 与 WASM 目标构建
	@$(call require_cmd,$(CARGO))
	@$(CARGO) check --manifest-path "$(E2EE_CORE_DIR)/Cargo.toml" --target aarch64-apple-ios
	@$(CARGO) check --manifest-path "$(E2EE_CORE_DIR)/Cargo.toml" --target aarch64-linux-android
	@$(CARGO) check --manifest-path "$(E2EE_CORE_DIR)/Cargo.toml" --target wasm32-unknown-unknown

e2ee-core.test.flutter: ## 运行 E2EE 核心 Flutter FFI smoke
	@$(call require_cmd,$(FLUTTER))
	@cd "$(E2EE_CORE_DIR)/flutter" && $(FLUTTER) test

e2ee-core.test.wasm: ## 在 Chrome 中运行 E2EE 核心 WASM 协议测试
	@$(call require_cmd,wasm-pack)
	@set -eu; \
	tmp_dir="$$(mktemp -d)"; \
	receiver_pid=""; \
	cleanup() { \
		if [ -n "$$receiver_pid" ]; then kill "$$receiver_pid" 2>/dev/null || true; fi; \
		rm -rf "$$tmp_dir"; \
	}; \
	trap cleanup EXIT INT TERM; \
	$(CARGO) run --quiet --manifest-path "$(E2EE_CORE_DIR)/Cargo.toml" --example cross_runtime_fixture -- \
		receive "$$tmp_dir/port" "$$tmp_dir/state" & \
	receiver_pid="$$!"; \
	for _ in $$(seq 1 100); do \
		if [ -s "$$tmp_dir/port" ]; then break; fi; \
		sleep 0.05; \
	done; \
	test -s "$$tmp_dir/port"; \
	receiver_url="http://127.0.0.1:$$(cat "$$tmp_dir/port")"; \
	if [ -n "$(CHROMEDRIVER)" ]; then \
		RC_E2EE_STATE_RECEIVER="$$receiver_url" wasm-pack test --chrome --headless --chromedriver "$(CHROMEDRIVER)" "$(E2EE_CORE_DIR)" --test wasm_browser; \
	else \
		RC_E2EE_STATE_RECEIVER="$$receiver_url" wasm-pack test --chrome --headless "$(E2EE_CORE_DIR)" --test wasm_browser; \
	fi; \
	wait "$$receiver_pid"; \
	receiver_pid=""; \
	$(CARGO) run --quiet --manifest-path "$(E2EE_CORE_DIR)/Cargo.toml" --example cross_runtime_fixture -- \
		verify "$(E2EE_CORE_DIR)/interop/fixtures/native_to_wasm.bin" "$$tmp_dir/state"

e2ee-core.build.h5: ## 生成 H5 使用的 E2EE WASM binding
	@$(call require_cmd,wasm-pack)
	@wasm-pack build "$(E2EE_CORE_DIR)" --target web --release --out-dir "$(H5_APP_DIR)/src/e2ee/core-wasm"

e2ee-core.fixture.generate: ## 重新生成 Native 到 WASM 的 E2EE 测试 fixture
	@$(call require_cmd,$(CARGO))
	@$(CARGO) run --manifest-path "$(E2EE_CORE_DIR)/Cargo.toml" --example cross_runtime_fixture -- \
		generate "$(E2EE_CORE_DIR)/interop/fixtures/native_to_wasm.bin"

h5-app.build: ## 构建 h5-app 生产包
	@$(call require_cmd,$(BUN))
	@cd "$(H5_APP_DIR)" && $(BUN) run build

h5-app.check: ## 执行 h5-app 类型检查
	@$(call require_cmd,$(BUN))
	@cd "$(H5_APP_DIR)" && $(BUN) run type-check

h5-app.test: h5-app.test.unit ## 执行 h5-app 默认 Vitest

h5-app.test.unit: ## 执行 h5-app 全量 Vitest
	@$(call require_cmd,$(BUN))
	@cd "$(H5_APP_DIR)" && VITE_USE_MOCK_DATA=true $(BUN) run test

h5-app.test.live: ## 执行 h5-app 真实后端普通账号注册/登录 smoke（需 api dev 就绪）
	@$(call require_cmd,$(BUN))
	@cd "$(H5_APP_DIR)" && H5_APP_API_BASE_URL="$(H5_APP_API_BASE_URL)" VITE_API_BASE_URL="$(H5_APP_API_BASE_URL)" $(BUN) run test:live

h5-app.test.e2e: ## 执行 h5-app 浏览器 E2E smoke（需 api dev 就绪；默认 Chrome channel）
	@$(call require_cmd,$(BUN))
	@cd "$(H5_APP_DIR)" && H5_APP_API_BASE_URL="$(H5_APP_API_BASE_URL)" VITE_API_BASE_URL="$(H5_APP_API_BASE_URL)" $(BUN) run test:e2e

ios-app.describe: ## 查看 ios-app SwiftPM package 描述
	@$(call require_cmd,$(SWIFT))
	@cd "$(IOS_APP_DIR)" && $(SWIFT) package describe

ios-app.test: ## 运行 ios-app SwiftPM 单元测试
	@$(call require_cmd,$(SWIFT))
	@cd "$(IOS_APP_DIR)" && $(SWIFT) test

ios-app.test.live: ## 执行 ios-app 真实后端 smoke（认证 + WS + 聊天互发，需 api dev 就绪）
	@$(call require_cmd,$(SWIFT))
	@cd "$(IOS_APP_DIR)" && RED_CODE_IOS_LIVE_API_SMOKE=1 $(SWIFT) test --filter AuthAPIClientLiveTests
	@cd "$(IOS_APP_DIR)" && RED_CODE_IOS_LIVE_WS_SMOKE=1 $(SWIFT) test --filter WebSocketClientLiveTests
	@cd "$(IOS_APP_DIR)" && RED_CODE_IOS_LIVE_CHAT_SMOKE=1 $(SWIFT) test --filter ChatAPIClientLiveTests
	@cd "$(IOS_APP_DIR)" && RED_CODE_IOS_LIVE_FRIEND_SMOKE=1 $(SWIFT) test --filter FriendAPIClientLiveTests
	@cd "$(IOS_APP_DIR)" && RED_CODE_IOS_LIVE_ROOM_SMOKE=1 $(SWIFT) test --filter RoomAPIClientLiveTests
	@cd "$(IOS_APP_DIR)" && RED_CODE_IOS_LIVE_MEDIA_SMOKE=1 $(SWIFT) test --filter MediaAPIClientLiveTests

ios-app.test.interop: h5-app.test.live ios-app.test.live ## 执行 H5/API/iOS 联调 smoke（需 api dev 就绪）

ios-app.apns.preflight: ## 检查 iPhone 真机/APNs 验收前置条件
	@$(call require_cmd,$(XCRUN))
	@IOS_APP_DEVICE_ID="$(IOS_APP_DEVICE_ID)" IOS_APP_API_BASE_URL="$(IOS_APP_API_BASE_URL)" IOS_APP_WS_URL="$(IOS_APP_WS_URL)" IOS_APNS_PROVIDER_CONFIGURED="$(IOS_APNS_PROVIDER_CONFIGURED)" "$(IOS_APP_DIR)/scripts/apns_real_device_preflight.sh"

ios-app.resolve.device: ## 输出当前可用 iPhone 真机标识
	@$(call require_cmd,$(XCRUN))
	@$(call require_cmd,$(RUBY))
	@IOS_APP_DEVICE_ID="$(IOS_APP_DEVICE_ID)" "$(IOS_APP_DIR)/scripts/resolve_real_device.sh"

ios-app.resolve.lan-ip: ## 输出当前本机局域网 IPv4（真机验收用）
	@IOS_APP_LAN_IP="$(IOS_APP_LAN_IP)" "$(IOS_APP_DIR)/scripts/resolve_lan_ip.sh"

ios-app.apns.preflight.local: ## 自动检测 LAN IP 后执行 iPhone/APNs 预检
	@LAN_IP="$$(IOS_APP_LAN_IP="$(IOS_APP_LAN_IP)" "$(IOS_APP_DIR)/scripts/resolve_lan_ip.sh")"; \
	echo "[ios-app] LAN_IP=$$LAN_IP"; \
	$(MAKE) ios-app.apns.preflight \
		IOS_APP_DEVICE_ID="$(IOS_APP_DEVICE_ID)" \
		IOS_APP_API_BASE_URL="http://$$LAN_IP:$(API_PORT)" \
		IOS_APP_WS_URL="ws://$$LAN_IP:$(API_PORT)/ws" \
		IOS_APNS_PROVIDER_CONFIGURED="$(IOS_APNS_PROVIDER_CONFIGURED)"

ios-app.build.device: ## 构建 ios-app iPhone 真机 Debug app（需签名 Team）
	@$(call require_cmd,$(XCODEBUILD))
	@[ -n "$(IOS_APP_DEVELOPMENT_TEAM)" ] || { echo "[ios-app] 缺少 IOS_APP_DEVELOPMENT_TEAM；真机构建需传 Apple Developer Team ID。" >&2; exit 66; }
	@[ -n "$(IOS_APP_API_BASE_URL)" ] || { echo "[ios-app] 缺少 IOS_APP_API_BASE_URL；真机 App 不能使用默认 loopback API。" >&2; exit 66; }
	@[ -n "$(IOS_APP_WS_URL)" ] || { echo "[ios-app] 缺少 IOS_APP_WS_URL；真机 App 不能使用默认 loopback WS。" >&2; exit 66; }
	@if [[ ! "$(IOS_APP_API_BASE_URL)" =~ ^https?:// ]]; then echo "[ios-app] IOS_APP_API_BASE_URL 必须使用 http/https: $(IOS_APP_API_BASE_URL)" >&2; exit 66; fi
	@if [[ ! "$(IOS_APP_WS_URL)" =~ ^wss?:// ]]; then echo "[ios-app] IOS_APP_WS_URL 必须使用 ws/wss: $(IOS_APP_WS_URL)" >&2; exit 66; fi
	@if [[ "$(IOS_APP_API_BASE_URL)" =~ ://(localhost|127\.|0\.0\.0\.0|\[::1\]) ]]; then echo "[ios-app] 真机构建不能使用 loopback API 地址: $(IOS_APP_API_BASE_URL)" >&2; exit 66; fi
	@if [[ "$(IOS_APP_WS_URL)" =~ ://(localhost|127\.|0\.0\.0\.0|\[::1\]) ]]; then echo "[ios-app] 真机构建不能使用 loopback WS 地址: $(IOS_APP_WS_URL)" >&2; exit 66; fi
	@$(XCODEBUILD) -project "$(IOS_APP_PROJECT)" -scheme "$(IOS_APP_SCHEME)" -configuration Debug -sdk iphoneos -destination "generic/platform=iOS" SYMROOT="$(IOS_APP_DERIVED_DATA)/Build/Products" OBJROOT="$(IOS_APP_DERIVED_DATA)/Build/Intermediates.noindex" REDCODE_API_BASE_URL="$(IOS_APP_API_BASE_URL)" REDCODE_WS_URL="$(IOS_APP_WS_URL)" DEVELOPMENT_TEAM="$(IOS_APP_DEVELOPMENT_TEAM)" CODE_SIGN_STYLE=Automatic $(IOS_APP_XCODEBUILD_DEVICE_FLAGS) build

ios-app.install.device: ios-app.apns.preflight ios-app.build.device ## 安装 ios-app 到 iPhone 真机
	@$(call require_cmd,$(XCRUN))
	@DEVICE_ID="$$(IOS_APP_DEVICE_ID="$(IOS_APP_DEVICE_ID)" "$(IOS_APP_DIR)/scripts/resolve_real_device.sh")"; \
	echo "[ios-app] installing device: $$DEVICE_ID"; \
	$(XCRUN) devicectl device install app --device "$$DEVICE_ID" "$(IOS_APP_DERIVED_DATA)/Build/Products/Debug-iphoneos/$(IOS_APP_SCHEME).app"

ios-app.smoke.device: ios-app.install.device ## 安装并启动 ios-app 到 iPhone 真机
	@$(call require_cmd,$(XCRUN))
	@DEVICE_ID="$$(IOS_APP_DEVICE_ID="$(IOS_APP_DEVICE_ID)" "$(IOS_APP_DIR)/scripts/resolve_real_device.sh")"; \
	echo "[ios-app] launching device: $$DEVICE_ID"; \
	DEVICECTL_CHILD_REDCODE_API_BASE_URL="$(IOS_APP_API_BASE_URL)" DEVICECTL_CHILD_REDCODE_WS_URL="$(IOS_APP_WS_URL)" \
	$(XCRUN) devicectl device process launch --device "$$DEVICE_ID" --terminate-existing "$(IOS_APP_BUNDLE_ID)"

ios-app.smoke.device.local: ## 自动检测 LAN IP 后构建、安装并启动到 iPhone 真机
	@LAN_IP="$$(IOS_APP_LAN_IP="$(IOS_APP_LAN_IP)" "$(IOS_APP_DIR)/scripts/resolve_lan_ip.sh")"; \
	echo "[ios-app] LAN_IP=$$LAN_IP"; \
	$(MAKE) ios-app.smoke.device \
		IOS_APP_DEVICE_ID="$(IOS_APP_DEVICE_ID)" \
		IOS_APP_DEVELOPMENT_TEAM="$(IOS_APP_DEVELOPMENT_TEAM)" \
		IOS_APNS_PROVIDER_CONFIGURED="$(IOS_APNS_PROVIDER_CONFIGURED)" \
		IOS_APP_API_BASE_URL="http://$$LAN_IP:$(API_PORT)" \
		IOS_APP_WS_URL="ws://$$LAN_IP:$(API_PORT)/ws"

ios-app.build.simulator: ## 构建 ios-app 本机 iOS Simulator Debug app
	@$(call require_cmd,$(XCODEBUILD))
	@$(XCODEBUILD) -project "$(IOS_APP_PROJECT)" -target "$(IOS_APP_TARGET)" -configuration Debug -sdk iphonesimulator SYMROOT="$(IOS_APP_DERIVED_DATA)/Build/Products" OBJROOT="$(IOS_APP_DERIVED_DATA)/Build/Intermediates.noindex" REDCODE_API_BASE_URL="$(IOS_APP_API_BASE_URL)" REDCODE_WS_URL="$(IOS_APP_WS_URL)" build

ios-app.ui-test: ## 运行 ios-app 本机 iOS Simulator XCUITest
	@$(call require_cmd,$(XCODEBUILD))
	@$(call require_cmd,$(XCRUN))
	@$(call require_cmd,$(RUBY))
	@DEVICE_ID="$(IOS_APP_SIMULATOR_ID)"; \
	if [ -z "$$DEVICE_ID" ]; then \
		DEVICE_ID="$$( $(XCRUN) simctl list devices available -j | $(RUBY) -rjson -e 'data = JSON.parse(STDIN.read); preferred = ARGV.fetch(0); devices = data.fetch("devices").values.flatten.select { |device| device["isAvailable"] }; selected = devices.find { |device| device["name"] == preferred } || devices.find { |device| device["name"].start_with?("iPhone") }; abort("[ios-app] 未找到可用 iOS Simulator") unless selected; puts selected["udid"]' "$(IOS_APP_SIMULATOR_NAME)")"; \
	fi; \
	echo "[ios-app] ui-test simulator: $$DEVICE_ID"; \
	$(XCRUN) simctl boot "$$DEVICE_ID" 2>/dev/null || true; \
	$(XCRUN) simctl bootstatus "$$DEVICE_ID" -b; \
	DESTINATION="platform=iOS Simulator,id=$$DEVICE_ID"; \
	DESTINATION_STATUS="$$( $(XCODEBUILD) -project "$(IOS_APP_PROJECT)" -scheme "$(IOS_APP_SCHEME)" -configuration Debug -destination "$$DESTINATION" -showdestinations 2>&1 || true )"; \
	if ! printf "%s\n" "$$DESTINATION_STATUS" | grep -q "Available destinations"; then \
		echo "[ios-app] xcodebuild 当前无法使用该 Simulator 运行 XCUITest。"; \
		echo "[ios-app] 常见原因：Xcode SDK 与已安装 Simulator runtime 不匹配；请在 Xcode > Settings > Components 安装匹配 runtime。"; \
		printf "%s\n" "$$DESTINATION_STATUS"; \
		exit 70; \
	fi; \
	$(XCODEBUILD) -project "$(IOS_APP_PROJECT)" -scheme "$(IOS_APP_SCHEME)" -configuration Debug -sdk iphonesimulator -destination "platform=iOS Simulator,id=$$DEVICE_ID" SYMROOT="$(IOS_APP_DERIVED_DATA)/Build/Products" OBJROOT="$(IOS_APP_DERIVED_DATA)/Build/Intermediates.noindex" test

ios-app.smoke.simulator: ios-app.build.simulator ## 安装并启动 ios-app 到本机 iOS Simulator
	@$(call require_cmd,$(XCRUN))
	@$(call require_cmd,$(RUBY))
	@DEVICE_ID="$(IOS_APP_SIMULATOR_ID)"; \
	if [ -z "$$DEVICE_ID" ]; then \
		DEVICE_ID="$$( $(XCRUN) simctl list devices available -j | $(RUBY) -rjson -e 'data = JSON.parse(STDIN.read); preferred = ARGV.fetch(0); devices = data.fetch("devices").values.flatten.select { |device| device["isAvailable"] }; selected = devices.find { |device| device["name"] == preferred } || devices.find { |device| device["name"].start_with?("iPhone") }; abort("[ios-app] 未找到可用 iOS Simulator") unless selected; puts selected["udid"]' "$(IOS_APP_SIMULATOR_NAME)")"; \
	fi; \
	echo "[ios-app] simulator: $$DEVICE_ID"; \
	$(XCRUN) simctl boot "$$DEVICE_ID" 2>/dev/null || true; \
	$(XCRUN) simctl bootstatus "$$DEVICE_ID" -b; \
	$(XCRUN) simctl install "$$DEVICE_ID" "$(IOS_APP_DERIVED_DATA)/Build/Products/Debug-iphonesimulator/$(IOS_APP_SCHEME).app"; \
	$(XCRUN) simctl launch "$$DEVICE_ID" "$(IOS_APP_BUNDLE_ID)"; \
	$(XCRUN) simctl get_app_container "$$DEVICE_ID" "$(IOS_APP_BUNDLE_ID)" app

ios-app.check: ios-app.test ios-app.build.simulator ## 运行 ios-app 当前可用检查

android-app.test: android-app.test.unit ## 运行 android-app 默认 JVM 单元测试

android-app.test.unit: ## 运行 android-app JVM 单元测试
	@$(call require_cmd,$(ANDROID_GRADLE))
	@ANDROID_HOME="$(ANDROID_HOME)" "$(ANDROID_GRADLE)" -p "$(ANDROID_APP_DIR)" testDebugUnitTest

android-app.test.live: ## 执行 android-app 真实后端聊天/好友 smoke（需 api dev 就绪）
	@$(call require_cmd,$(ANDROID_GRADLE))
	@ANDROID_HOME="$(ANDROID_HOME)" \
		RED_CODE_ANDROID_LIVE_SMOKE=1 \
		ANDROID_APP_LIVE_API_BASE_URL="$(ANDROID_APP_LIVE_API_BASE_URL)" \
		ANDROID_APP_LIVE_WS_URL="$(ANDROID_APP_LIVE_WS_URL)" \
		"$(ANDROID_GRADLE)" -p "$(ANDROID_APP_DIR)" testDebugUnitTest --rerun-tasks --tests 'com.redcode.im.androidapp.live.*'

android-app.test.interop.support: ## 执行 H5/API/Android 联调所需的 Android 本地能力定向测试
	@$(call require_cmd,$(ANDROID_GRADLE))
	@echo "[android-app] interop support: avatar cache + emoji cache + permission recovery + audio playback"
	@ANDROID_HOME="$(ANDROID_HOME)" "$(ANDROID_GRADLE)" -p "$(ANDROID_APP_DIR)" testDebugUnitTest --rerun-tasks \
		--tests 'com.redcode.im.androidapp.data.AvatarCacheRepositoryTest' \
		--tests 'com.redcode.im.androidapp.data.EmojiRepositoryTest' \
		--tests 'com.redcode.im.androidapp.feature.PermissionRecoveryTest' \
		--tests 'com.redcode.im.androidapp.feature.ChatViewModelTest'

android-app.test.interop: ## 执行 H5/API/Android 聊天/好友/媒体互通 smoke（自动启动 api dev 栈）
	@echo "[android-app] interop: start Compose API stack"
	@$(MAKE) api.up || { echo "[android-app] interop failed during api.up"; echo "[hint] API logs: make api.logs"; exit 1; }
	@$(MAKE) api.wait || { echo "[android-app] interop failed during api.wait"; echo "[hint] API status: make api.ps"; echo "[hint] API logs: make api.logs"; exit 1; }
	@echo "[android-app] interop: run H5 live smoke"
	@$(MAKE) h5-app.test.live || { echo "[android-app] interop failed during h5-app.test.live"; echo "[hint] H5 live log: rerun make h5-app.test.live and inspect Vitest output"; echo "[hint] API logs: make api.logs"; exit 1; }
	@echo "[android-app] interop: run Android live smoke"
	@$(MAKE) android-app.test.live || { echo "[android-app] interop failed during android-app.test.live"; echo "[hint] Android unit report: $(ANDROID_APP_DIR)/app/build/reports/tests/testDebugUnitTest/index.html"; echo "[hint] Android test results: $(ANDROID_APP_DIR)/app/build/test-results/testDebugUnitTest"; echo "[hint] API logs: make api.logs"; exit 1; }
	@echo "[android-app] interop: run Android local support tests"
	@$(MAKE) android-app.test.interop.support || { echo "[android-app] interop failed during android-app.test.interop.support"; echo "[hint] Android unit report: $(ANDROID_APP_DIR)/app/build/reports/tests/testDebugUnitTest/index.html"; echo "[hint] Android coverage report: $(ANDROID_APP_DIR)/app/build/reports/jacoco/jacocoDebugUnitTestReport/html/index.html"; exit 1; }
	@echo "[android-app] interop ok"
	@echo "[android-app] reports: $(ANDROID_APP_DIR)/app/build/reports/tests/testDebugUnitTest/index.html"
	@echo "[android-app] coverage: $(ANDROID_APP_DIR)/app/build/reports/jacoco/jacocoDebugUnitTestReport/html/index.html"

android-app.coverage: ## 生成 android-app JVM 单元测试覆盖率报告
	@$(call require_cmd,$(ANDROID_GRADLE))
	@ANDROID_HOME="$(ANDROID_HOME)" "$(ANDROID_GRADLE)" -p "$(ANDROID_APP_DIR)" coverageDebugUnitTest
	@echo "[android-app] coverage: $(ANDROID_APP_DIR)/app/build/reports/jacoco/jacocoDebugUnitTestReport/html/index.html"

android-app.build.debug: ## 构建 android-app Debug APK（默认指向 Android Emulator 的 10.0.2.2，可传真机 LAN API/WS）
	@$(call require_cmd,$(ANDROID_GRADLE))
	@$(require_android_app_network)
	@ANDROID_HOME="$(ANDROID_HOME)" "$(ANDROID_GRADLE)" -p "$(ANDROID_APP_DIR)" \
		-Predcode.apiBaseUrl="$(ANDROID_APP_API_BASE_URL)" \
		-Predcode.wsUrl="$(ANDROID_APP_WS_URL)" \
		-Predcode.useRemoteAuth="$(ANDROID_APP_USE_REMOTE_AUTH)" \
		assembleDebug

android-app.lint: ## 运行 android-app Android Lint
	@$(call require_cmd,$(ANDROID_GRADLE))
	@ANDROID_HOME="$(ANDROID_HOME)" "$(ANDROID_GRADLE)" -p "$(ANDROID_APP_DIR)" lintDebug

android-app.resolve.device: ## 输出当前 Android 设备 ID（优先 Pixel 8 Pro，缺失时回退 Emulator）
	@$(call require_cmd,$(ADB))
	@DEVICE_ID="$$( "$(ADB)" devices | awk -v preferred="$(ANDROID_APP_PREFERRED_DEVICE)" 'NR > 1 && $$2 == "device" { if ($$1 == preferred) { print $$1; found = 1; exit } if ($$1 ~ /^emulator-/ && emulator == "") emulator = $$1; if (first == "") first = $$1 } END { if (!found) print (emulator != "" ? emulator : first) }' )"; \
	if [ -z "$$DEVICE_ID" ]; then echo "[android-app] 未找到已连接 Android 设备" >&2; exit 66; fi; \
	echo "$$DEVICE_ID"

android-app.resolve.network: ## 输出当前 android-app 设备和 API/WS 地址
	@$(require_android_app_network)
	@echo "ANDROID_APP_DEVICE=$(ANDROID_APP_DEVICE)"
	@echo "ANDROID_APP_LAN_IP=$(ANDROID_APP_LAN_IP)"
	@echo "ANDROID_APP_API_BASE_URL=$(ANDROID_APP_API_BASE_URL)"
	@echo "ANDROID_APP_WS_URL=$(ANDROID_APP_WS_URL)"

android-app.connected-test: ## 在当前 Android 设备上运行 Compose instrumented tests
	@$(call require_cmd,$(ANDROID_GRADLE))
	@$(call require_cmd,$(ADB))
	@$(require_android_app_network)
	@"$(ADB)" -s "$(ANDROID_APP_DEVICE)" wait-for-device
	@ANDROID_HOME="$(ANDROID_HOME)" "$(ANDROID_GRADLE)" -p "$(ANDROID_APP_DIR)" \
		-Predcode.apiBaseUrl="$(ANDROID_APP_API_BASE_URL)" \
		-Predcode.wsUrl="$(ANDROID_APP_WS_URL)" \
		-Predcode.useRemoteAuth="$(ANDROID_APP_USE_REMOTE_AUTH)" \
		connectedDebugAndroidTest

android-app.install: android-app.build.debug ## 安装 android-app Debug APK 到当前 Android 设备
	@$(call require_cmd,$(ADB))
	@"$(ADB)" -s "$(ANDROID_APP_DEVICE)" wait-for-device
	@"$(ADB)" -s "$(ANDROID_APP_DEVICE)" install -r "$(ANDROID_APP_APK)"

android-app.smoke.emulator: android-app.install ## 安装并启动 android-app 到当前 Android 设备
	@$(call require_cmd,$(ADB))
	@"$(ADB)" -s "$(ANDROID_APP_DEVICE)" shell am start -n "$(ANDROID_APP_PACKAGE)/.MainActivity"
	@echo "[android-app] launched on $(ANDROID_APP_DEVICE)"

android-app.check: android-app.test.unit android-app.lint android-app.build.debug ## 运行 android-app 当前可用检查

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

tests.compose.config: ## 校验 api 测试栈 docker compose 配置可渲染
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_TEST_COMPOSE_FILE)" config >/dev/null

tests.tooling: ## 执行仓库级 tooling 守护测试
	@$(call require_cmd,$(GO))
	@cd "$(ROOT_DIR)/tests/go" && $(GO) test ./tooling/

tests.mocks.external: ## 执行外部依赖 mock 服务自测（B2/FCM/APNs/IPInfo）
	@$(call require_cmd,$(GO))
	@cd "$(ROOT_DIR)/tests/mocks/external" && $(GO) test ./...

tests.perf.check: ## 执行 api 压测工具 Go 自检
	@$(call require_cmd,$(GO))
	@cd "$(ROOT_DIR)/tests/perf" && $(GO) test ./...

tests.all: test.all ## 运行仓库全量本地测试入口（别名）

# 兼容旧命令 ---------------------------------------------------------------

api-up: api.up ## 兼容旧命令：启动 api 开发栈
api-down: api.down ## 兼容旧命令：停止 api 开发栈
api-logs: api.logs ## 兼容旧命令：查看 api 日志
api-ps: api.ps ## 兼容旧命令：查看 api 容器状态

admin-up: admin.up ## 兼容旧命令：启动 admin
admin-down: admin.down ## 兼容旧命令：停止 admin
admin-logs: admin.logs ## 兼容旧命令：查看 admin 日志

desktop-up: desktop.up ## 兼容旧命令：启动 desktop
desktop-down: desktop.down ## 兼容旧命令：停止 desktop
desktop-logs: desktop.logs ## 兼容旧命令：查看 desktop 日志

h5-app-up: h5-app.up ## 兼容旧命令：启动 h5-app
h5-app-down: h5-app.down ## 兼容旧命令：停止 h5-app
h5-app-logs: h5-app.logs ## 兼容旧命令：查看 h5-app 日志

website-up: website.up ## 兼容旧命令：启动 website
website-down: website.down ## 兼容旧命令：停止 website
website-logs: website.logs ## 兼容旧命令：查看 website 日志
