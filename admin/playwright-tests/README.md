# Playwright 测试（Admin E2E）

本目录用于管理后台（admin）的 Playwright E2E 测试，分为 **标准化测试** 与 **历史脚本** 两类：

- **标准化测试（推荐）**：`playwright-tests/specs/*.spec.ts`（使用 Playwright Test Runner）
- **历史脚本**：`playwright-tests/*.js`（node 直跑，保留做参考/排障）

## 目录结构

```
playwright-tests/
├── README.md
├── specs/                    # Playwright Test Runner 标准化用例
│   └── login.spec.ts
├── *.js                      # 历史脚本（node 直跑）
└── *.png / *.json            # 历史截图与分析文件
```

## 推荐运行方式（Test Runner）

```bash
cd admin
pnpm install
pnpm test:e2e
```

默认会读取以下环境变量（可选）：

- `ADMIN_BASE_URL`（默认 `http://localhost:8011`）
- `ADMIN_USERNAME`（默认 `admin`）
- `ADMIN_PASSWORD`（默认 `admin123`）
- `ADMIN_E2E_ENABLED=true` 才会执行用例（避免环境未就绪时误失败）

## 历史脚本说明（参考/排障）

### test-login.js
- **作用**: 基础测试脚本，用于打开登录页面并截图
- **功能**: 
  - 使用本地Chrome浏览器打开登录页面
  - 等待2秒页面加载
  - 截图并保存为login-page.png
- **使用方法**: `node test-login.js`

### test-login-full.js
- **作用**: 完整登录流程测试脚本（初版）
- **功能**:
  - 打开登录页面
  - 尝试填写用户名和密码
  - 点击登录按钮
  - 截图保存登录后页面
- **注意**: 此版本使用了不正确的选择器，测试失败
- **使用方法**: `node test-login-full.js`

### test-login-updated.js
- **作用**: 更新后的登录测试脚本（使用正确的选择器）
- **功能**:
  - 使用本地Chrome浏览器打开登录页面
  - 使用正确的选择器填写用户名和密码
  - 点击登录按钮
  - 验证登录成功（检查URL跳转）
  - 截图保存登录后页面
- **特点**: 成功完成登录流程，页面跳转到dashboard/workplace
- **使用方法**: `node test-login-updated.js`

### check-login-page.js
- **作用**: 检查登录页面元素属性
- **功能**:
  - 打开登录页面
  - 获取页面HTML内容
  - 检查所有输入框的type和placeholder属性
  - 输出元素信息用于确定正确的选择器
- **使用方法**: `node check-login-page.js`

## 配置说明

所有脚本都配置为使用本地Chrome浏览器，路径为：
```
/Applications/Google Chrome.app/Contents/MacOS/Google Chrome
```

## 运行环境

- Node.js v22.20.0
- Playwright
- 本地Chrome浏览器

## 测试结果

- 登录功能正常工作
- 成功跳转到dashboard/workplace页面
- 用户名: admin
- 密码: admin123

## 注意事项

1. 运行脚本前确保后端服务（`http://localhost:8010`）和管理后台前端（`http://localhost:8011`）都已启动
2. 管理后台登录走 `/auth/admin/login`，需要存在管理员账号。推荐本地开启一次性初始化：
   - 在后端 `.env` 中设置：`ALLOW_INSECURE_ADMIN_BOOTSTRAP=true`
   - 执行：`curl -sS -X POST "http://localhost:8010/api/admin/init-default-admin"`
3. 默认管理员账号为 `admin/admin123`；如需修改账号/地址，建议通过环境变量注入（脚本会优先读取）：
   - `ADMIN_BASE_URL`（默认 `http://localhost:8011`）
   - `ADMIN_USERNAME`（默认 `admin`）
   - `ADMIN_PASSWORD`（默认 `admin123`）
