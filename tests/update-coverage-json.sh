#!/usr/bin/env bash
# 生成测试覆盖率数据供 Dashboard 使用
# 输出: docs/reports/test-coverage.json
#
# 用法:
#   ./tests/update-coverage-json.sh          # 完整运行（含测试）
#   SKIP_TESTS=1 ./tests/update-coverage-json.sh  # 仅解析现有数据

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_FILE="${ROOT_DIR}/docs/reports/test-coverage.json"
COMPOSE_FILE="${ROOT_DIR}/tests/docker-compose.yml"

# 确保输出目录存在
mkdir -p "$(dirname "$OUTPUT_FILE")"

# 获取当前时间
UPDATED_AT=$(date -Iseconds)

echo "[coverage-json] 生成测试覆盖率 JSON 数据..." >&2

# 如果没有跳过测试，先运行测试收集数据
if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
  echo "[coverage-json] 运行测试并收集覆盖率..." >&2

  # 启动依赖
  docker-compose -f "$COMPOSE_FILE" up -d postgres redis-session redis-cache >/dev/null 2>&1 || true

  # 运行测试并获取覆盖率摘要
  COVERAGE_OUTPUT=$(docker-compose -f "$COMPOSE_FILE" run --rm rust-tests \
    cargo llvm-cov --lib --tests 2>&1) || true
fi

# 解析 Rust 测试结果
echo "[coverage-json] 解析测试结果..." >&2

# 获取测试统计
TEST_STATS=$(docker-compose -f "$COMPOSE_FILE" run --rm rust-tests \
  cargo test -- --list 2>/dev/null | grep -E "^[0-9]+ tests" || echo "0 tests")

TOTAL_TESTS=$(echo "$TEST_STATS" | grep -oE "^[0-9]+" | head -1 || echo "0")

# 获取覆盖率摘要
COVERAGE_SUMMARY=$(docker-compose -f "$COMPOSE_FILE" run --rm rust-tests \
  cargo llvm-cov --lib --tests 2>&1 | tail -20) || true

# 解析行覆盖率
LINE_COVERAGE=$(echo "$COVERAGE_SUMMARY" | grep -E "TOTAL" | awk '{print $NF}' | tr -d '%' || echo "0")
if [[ -z "$LINE_COVERAGE" || "$LINE_COVERAGE" == "0" ]]; then
  LINE_COVERAGE="0"
fi

# 统计各模块测试数
API_TESTS=$(docker-compose -f "$COMPOSE_FILE" run --rm rust-tests \
  cargo test --test api -- --list 2>/dev/null | grep -c "test$" || echo "0")
STORE_TESTS=$(docker-compose -f "$COMPOSE_FILE" run --rm rust-tests \
  cargo test --test stores -- --list 2>/dev/null | grep -c "test$" || echo "0")
WS_TESTS=$(docker-compose -f "$COMPOSE_FILE" run --rm rust-tests \
  cargo test --test ws_tests -- --list 2>/dev/null | grep -c "test$" || echo "0")
E2EE_TESTS=$(docker-compose -f "$COMPOSE_FILE" run --rm rust-tests \
  cargo test --test e2ee_key_store_tests -- --list 2>/dev/null | grep -c "test$" || echo "0")
FILE_UPLOAD_TESTS=$(docker-compose -f "$COMPOSE_FILE" run --rm rust-tests \
  cargo test --test file_upload_test -- --list 2>/dev/null | grep -c "test$" || echo "0")
UNIT_TESTS=$(docker-compose -f "$COMPOSE_FILE" run --rm rust-tests \
  cargo test --lib -- --list 2>/dev/null | grep -c "test$" || echo "0")

# 获取 Go 测试统计
GO_TESTS=$(docker-compose -f "$COMPOSE_FILE" run --rm go-tests \
  go test -v ./... -list '.*' 2>/dev/null | grep -c "^Test" || echo "0")

# 生成 JSON
cat > "$OUTPUT_FILE" << EOF
{
  "updatedAt": "${UPDATED_AT}",
  "rust": {
    "lineCoverage": ${LINE_COVERAGE:-0},
    "totalTests": ${TOTAL_TESTS:-0},
    "modules": {
      "unit": ${UNIT_TESTS:-0},
      "api": ${API_TESTS:-0},
      "stores": ${STORE_TESTS:-0},
      "websocket": ${WS_TESTS:-0},
      "e2ee": ${E2EE_TESTS:-0},
      "fileUpload": ${FILE_UPLOAD_TESTS:-0}
    }
  },
  "go": {
    "totalTests": ${GO_TESTS:-0}
  },
  "summary": {
    "totalTests": $((${TOTAL_TESTS:-0} + ${GO_TESTS:-0})),
    "rustTests": ${TOTAL_TESTS:-0},
    "goTests": ${GO_TESTS:-0}
  }
}
EOF

echo "[coverage-json] ✅ 已生成: ${OUTPUT_FILE}" >&2
