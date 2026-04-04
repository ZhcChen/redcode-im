# 根目录统一开发入口。
# 约定：
# 1. API 使用 backend/docker/dev/docker-compose.yml 管理开发环境。
# 2. admin / desktop / website 统一通过 screen 后台运行，日志落到 /tmp。
# 3. 端口冲突时先清理旧进程，再按项目既定端口重启，避免随意改端口。

.DEFAULT_GOAL := help
SHELL := /bin/bash

ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

DOCKER := docker
BUN := bun
SCREEN := screen
CURL := curl
TAIL := tail

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

WEBSITE_DIR := $(ROOT_DIR)/website
WEBSITE_SCREEN := website
WEBSITE_PORT := 8015
WEBSITE_LOG := /tmp/redcode-website.log

TESTS_SCRIPT := $(ROOT_DIR)/tests/run.sh

define require_cmd
command -v $(1) >/dev/null 2>&1 || { echo "[make] 缺少命令: $(1)"; exit 1; }
endef

.PHONY: help status \
	api-up api-down api-logs api-ps \
	admin-up admin-down admin-logs \
	desktop-up desktop-down desktop-logs \
	website-up website-down website-logs \
	tests

help: ## 显示所有可用命令
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_.-]+:.*## / {printf "%-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

status: ## 查看各模块当前状态（API、screen 会话、端口监听）
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
	@echo "[website]"
	@if $(SCREEN) -ls 2>/dev/null | grep -q "[[:digit:]]\\.$(WEBSITE_SCREEN)"; then echo "screen: running ($(WEBSITE_SCREEN))"; else echo "screen: stopped"; fi
	@if lsof -nP -iTCP:$(WEBSITE_PORT) -sTCP:LISTEN >/dev/null 2>&1; then echo "port $(WEBSITE_PORT): listening"; else echo "port $(WEBSITE_PORT): stopped"; fi

api-up: ## 启动本地 API 开发栈（backend + postgres + redis）
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_COMPOSE_FILE)" up -d $(API_SERVICE)
	@echo "[api] 已启动，健康检查地址: http://localhost:$(API_PORT)/healthz"

api-down: ## 停止本地 API 开发栈
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_COMPOSE_FILE)" down

api-logs: ## 跟随查看 API 日志
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_COMPOSE_FILE)" logs -f --tail=200 $(API_SERVICE)

api-ps: ## 查看 API 开发栈容器状态
	@$(call require_cmd,$(DOCKER))
	@$(DOCKER) compose -f "$(API_COMPOSE_FILE)" ps

admin-up: ## 启动管理后台开发服务（screen 会话: admin，端口: 8011）
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

admin-down: ## 停止管理后台开发服务
	@if $(SCREEN) -ls 2>/dev/null | grep -q "[[:digit:]]\\.$(ADMIN_SCREEN)"; then \
		$(SCREEN) -S $(ADMIN_SCREEN) -X quit || true; \
	fi
	@if lsof -tiTCP:$(ADMIN_PORT) -sTCP:LISTEN >/dev/null 2>&1; then \
		lsof -tiTCP:$(ADMIN_PORT) -sTCP:LISTEN | xargs kill -9; \
	fi
	@echo "[admin] 已停止"

admin-logs: ## 跟随查看管理后台日志
	@$(call require_cmd,$(TAIL))
	@test -f "$(ADMIN_LOG)" || { echo "[admin] 日志不存在: $(ADMIN_LOG)"; exit 1; }
	@$(TAIL) -n 200 -f "$(ADMIN_LOG)"

desktop-up: ## 启动桌面端开发服务（screen 会话: desktop，端口: 1420）
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

desktop-down: ## 停止桌面端开发服务
	@if $(SCREEN) -ls 2>/dev/null | grep -q "[[:digit:]]\\.$(DESKTOP_SCREEN)"; then \
		$(SCREEN) -S $(DESKTOP_SCREEN) -X quit || true; \
	fi
	@if lsof -tiTCP:$(DESKTOP_PORT) -sTCP:LISTEN >/dev/null 2>&1; then \
		lsof -tiTCP:$(DESKTOP_PORT) -sTCP:LISTEN | xargs kill -9; \
	fi
	@echo "[desktop] 已停止"

desktop-logs: ## 跟随查看桌面端日志
	@$(call require_cmd,$(TAIL))
	@test -f "$(DESKTOP_LOG)" || { echo "[desktop] 日志不存在: $(DESKTOP_LOG)"; exit 1; }
	@$(TAIL) -n 200 -f "$(DESKTOP_LOG)"

website-up: ## 启动官网开发服务（screen 会话: website，端口: 8015）
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

website-down: ## 停止官网开发服务
	@if $(SCREEN) -ls 2>/dev/null | grep -q "[[:digit:]]\\.$(WEBSITE_SCREEN)"; then \
		$(SCREEN) -S $(WEBSITE_SCREEN) -X quit || true; \
	fi
	@if lsof -tiTCP:$(WEBSITE_PORT) -sTCP:LISTEN >/dev/null 2>&1; then \
		lsof -tiTCP:$(WEBSITE_PORT) -sTCP:LISTEN | xargs kill -9; \
	fi
	@echo "[website] 已停止"

website-logs: ## 跟随查看官网日志
	@$(call require_cmd,$(TAIL))
	@test -f "$(WEBSITE_LOG)" || { echo "[website] 日志不存在: $(WEBSITE_LOG)"; exit 1; }
	@$(TAIL) -n 200 -f "$(WEBSITE_LOG)"

tests: ## 运行测试栈脚本（tests/run.sh）
	@bash "$(TESTS_SCRIPT)"
