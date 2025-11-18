# RedCode Test Go Makefile

.PHONY: build run clean test help

# 默认目标
all: build

# 构建程序
build:
	mkdir -p bin
	go build -o bin/server0 ./cmd/server0

# 运行程序
run: build
	./bin/server0

# 清理构建文件
clean:
	rm -rf bin/
	go clean

# 运行测试（如果有）
test:
	go test ./...

# 显示帮助信息
help:
	@echo "RedCode Test Go - 构建和运行命令"
	@echo ""
	@echo "可用命令:"
	@echo "  make build    - 编译程序到 bin/server0"
	@echo "  make run      - 编译并运行程序"
	@echo "  make clean    - 清理编译文件"
	@echo "  make test     - 运行测试（如果有）"
	@echo "  make help     - 显示此帮助信息"
	@echo ""
	@echo "直接运行:"
	@echo "  go run ./cmd/server0    - 直接运行（无需编译）"
	@echo "  ./bin/server0           - 运行编译后的程序"
