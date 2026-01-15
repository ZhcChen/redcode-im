# Playwright 测试脚本

本目录包含使用 Playwright 进行自动化测试的脚本和资源文件。

## 目录结构

```
playwright-tests/
├── README.md                 # 本文件，说明各脚本的作用
├── test-login.js             # 基础登录页面测试脚本
├── test-login-full.js        # 完整登录流程测试脚本
├── test-login-updated.js     # 更新后的登录测试脚本（使用正确的选择器）
├── check-login-page.js       # 检查登录页面元素属性的脚本
├── login-page.png            # 登录页面截图
└── after-login.png           # 登录后页面截图
```

## 脚本说明

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
