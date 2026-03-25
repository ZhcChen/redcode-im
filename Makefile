SHELL := /bin/bash
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
DESKTOP_EL_SCREEN := desktop-el-$(shell printf '%s' "$(ROOT_DIR)" | cksum | awk '{print $$1}')

.PHONY: help status \
	api-up api-down api-logs \
	admin-up admin-down admin-logs \
	desktop-up desktop-down desktop-logs \
	website-up website-down website-logs \
	tests-up tests-down tests-logs \
	desktop-el-up desktop-el-down desktop-el-logs \
	desktop-el-test desktop-el-core-test desktop-el-build desktop-el-verify

help: ## 显示所有可用命令
	@echo "RedCode IM 统一命令入口"
	@grep -E '^[a-zA-Z0-9_.-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-18s %s\n", $$1, $$2}'

status: ## 查看关键服务状态
	@echo "[docker compose] backend(dev) status"
	@docker compose -f backend/docker/dev/docker-compose.yml ps || true
	@echo
	@echo "[docker compose] tests stack status"
	@docker compose -f tests/docker-compose.yml ps || true
	@echo
	@echo "[screen] session status"
	@screen -ls || true

api-up: ## 启动后端开发栈（backend/docker/dev）
	docker compose -f backend/docker/dev/docker-compose.yml up -d

api-down: ## 停止后端开发栈（backend/docker/dev）
	docker compose -f backend/docker/dev/docker-compose.yml down

api-logs: ## 查看后端开发栈日志（backend/docker/dev）
	docker compose -f backend/docker/dev/docker-compose.yml logs -f --tail=200

admin-up: ## 后台启动 admin（screen 会话：admin）
	screen -dmS admin bash -lc 'cd admin && npm run dev'

admin-down: ## 停止 admin（screen 会话：admin）
	screen -S admin -X quit || true

admin-logs: ## 连接到 admin 日志（screen -r admin）
	screen -r admin

desktop-up: ## 启动旧桌面端 desktop（Tauri，screen 会话：desktop）
	screen -dmS desktop bash -lc 'cd desktop && bun install && bun run tauri dev'

desktop-down: ## 停止旧桌面端 desktop（screen 会话：desktop）
	screen -S desktop -X quit || true

desktop-logs: ## 连接到旧桌面端日志（screen -r desktop）
	screen -r desktop

website-up: ## 启动 website（screen 会话：website）
	screen -dmS website bash -lc 'cd website && bun install && bun run dev'

website-down: ## 停止 website（screen 会话：website）
	screen -S website -X quit || true

website-logs: ## 连接到 website 日志（screen -r website）
	screen -r website

tests-up: ## 启动测试栈（tests/docker-compose.yml）
	docker compose -f tests/docker-compose.yml up -d

tests-down: ## 停止测试栈（tests/docker-compose.yml）
	docker compose -f tests/docker-compose.yml down

tests-logs: ## 查看测试栈日志（tests/docker-compose.yml）
	docker compose -f tests/docker-compose.yml logs -f --tail=200

desktop-el-up: ## 启动 desktop-el 全部开发进程（当前 worktree 独立 screen 会话）
	@$(MAKE) desktop-el-down >/dev/null
	screen -dmS $(DESKTOP_EL_SCREEN) bash -lc 'cd desktop-el && bun install && bun run dev'

desktop-el-down: ## 停止当前 worktree 的 desktop-el 开发进程
	@screen -ls 2>/dev/null | awk '/\.$(DESKTOP_EL_SCREEN)[[:space:]]/ {print $$1}' | xargs -I{} sh -c 'screen -S "$$1" -X quit >/dev/null 2>&1 || true' _ {} || true
	@screen -wipe >/dev/null 2>&1 || true
	@pkill -f '$(ROOT_DIR)/desktop-el/node_modules/.bin/electron' || true
	@pkill -f '$(ROOT_DIR)/desktop-el/node_modules/electron/dist/Electron.app/Contents/MacOS/Electron' || true

desktop-el-logs: ## 连接到当前 worktree 的 desktop-el 日志
	screen -r $(DESKTOP_EL_SCREEN)

desktop-el-test: ## 运行 desktop-el Bun 自动化测试
	cd desktop-el && bun run test

desktop-el-core-test: ## 运行 desktop-el Go core 测试
	cd desktop-el && bun run test:core

desktop-el-build: ## 构建 desktop-el
	cd desktop-el && bun run build

desktop-el-verify: ## 运行 desktop-el 固定验收脚本（Go core + Bun test + build）
	cd desktop-el && bun run verify
