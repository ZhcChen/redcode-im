# Admin 管理后台

基于 Arco Design Pro Vue 的管理后台系统。

## 项目介绍

这是一个使用 Vue 3 + TypeScript + Vite + Arco Design 构建的现代化管理后台应用。

## 开发规范速查（MUST）
- 完整规范见 `admin/docs/开发规范.md`（开始工作前先阅读）。
- 组件内禁止直接 axios/fetch，所有 API 封装在 `admin/src/api/` 并补齐 TypeScript 类型。
- 开发端口 8010/8011，Vite 代理与 axios `baseURL` 必须指向后端；异步流程需 loading 与统一错误处理（401/403 由拦截器处理）。

### 技术栈

- **框架**: Vue 3.2
- **构建工具**: Vite 3.2
- **UI 组件库**: Arco Design Vue 2.44
- **状态管理**: Pinia 2.0
- **路由**: Vue Router 4.0
- **图表**: ECharts 5.4
- **国际化**: Vue I18n 9.2
- **CSS 预处理器**: Less
- **代码规范**: ESLint + Prettier + Stylelint
- **Git Hooks**: Husky + Lint-staged
- **包管理器**: Bun

## 快速开始

### 环境要求

- Bun >= 1.0.0
- Node.js >= 16.0.0

### 安装依赖

```bash
bun install
```

### 开发

启动开发服务器:

```bash
bun run dev
```

访问 http://localhost:5173

### 构建

构建生产环境:

```bash
bun run build
```

构建并进行类型检查:

```bash
bun run build:check
```

### 预览

预览构建产物:

```bash
bun run preview
```

### 代码检查

类型检查:

```bash
bun run type:check
```

### 构建分析

生成构建分析报告:

```bash
bun run report
```

## 项目结构

```
admin/
├── config/              # Vite 配置文件
├── dist/                # 构建输出目录
├── nginx/               # Nginx 部署配置
│   ├── nginx.conf       # Nginx 配置文件
│   ├── Dockerfile       # Docker 镜像配置
│   ├── docker-compose.yml
│   └── README.md        # Nginx 部署说明
├── public/              # 静态资源
├── src/                 # 源代码
│   ├── api/             # API 接口
│   ├── assets/          # 资源文件
│   ├── components/      # 公共组件
│   ├── hooks/           # 组合式函数
│   ├── locale/          # 国际化文件
│   ├── router/          # 路由配置
│   ├── store/           # 状态管理
│   ├── types/           # TypeScript 类型定义
│   ├── utils/           # 工具函数
│   ├── views/           # 页面组件
│   ├── App.vue          # 根组件
│   └── main.ts          # 入口文件
├── deploy.sh            # 自动部署脚本
├── deploy.config.example # 部署配置模板
├── .env.development     # 开发环境变量
├── .env.production      # 生产环境变量
├── package.json         # 项目配置
└── README.md            # 项目文档
```

## 环境变量

### 开发环境 (.env.development)

```
VITE_API_BASE_URL=开发环境 API 地址
```

### 生产环境 (.env.production)

```
VITE_API_BASE_URL=https://api.chatlyme.com
```

## 部署

本项目提供了自动化部署脚本,支持一键构建、压缩和部署到服务器。

### 快速部署

1. **配置部署信息**

```bash
# 复制配置文件模板
cp deploy.config.example deploy.config

# 编辑配置文件,填入服务器信息
vim deploy.config
```

配置示例:
```bash
# 使用 SSH config 中配置的别名
SERVER_HOST="xin-im-prod-0"
SERVER_PATH="/home/ubuntu/admin"

# 或者直接使用 user@host 格式
# SERVER_HOST="user@192.168.1.100"
```

2. **执行部署**

```bash
./deploy.sh
```

脚本会自动完成以下步骤:
- ✅ 构建项目 (`bun run build`)
- ✅ 压缩 dist 目录 (使用 7z)
- ✅ 上传到服务器 (通过 SCP)
- 📋 显示服务器端部署命令 (需要手动执行)

脚本执行完成后,会显示一条可以直接复制的服务器端部署命令,在服务器上执行即可完成部署

### 部署前置要求

#### 本地环境

1. **Bun** - 项目构建工具
   ```bash
   curl -fsSL https://bun.sh/install | bash
   ```

2. **7-Zip** - 文件压缩工具
   ```bash
   # macOS
   brew install p7zip

   # Ubuntu/Debian
   sudo apt-get install p7zip-full

   # CentOS/RHEL
   sudo yum install p7zip
   ```

3. **SSH 配置** - 配置服务器连接

   方式一: 使用 SSH config 别名 (推荐)
   ```bash
   # 编辑 SSH 配置文件
   vim ~/.ssh/config

   # 添加服务器配置
   Host xin-im-prod-0
       HostName your-server-ip
       User root
       Port 22
       IdentityFile ~/.ssh/id_rsa
   ```

   方式二: 使用免密登录
   ```bash
   # 生成 SSH 密钥
   ssh-keygen -t rsa -b 4096

   # 复制公钥到服务器
   ssh-copy-id user@your-server-ip
   ```

#### 服务器环境

1. **7-Zip** - 文件解压工具
   ```bash
   # Ubuntu/Debian
   sudo apt-get install p7zip-full

   # CentOS/RHEL
   sudo yum install p7zip
   ```

2. **Nginx** - Web 服务器

   参考 [nginx/README.md](./nginx/README.md) 配置 Nginx

### 部署输出示例

```
加载配置文件: /path/to/admin/deploy.config
========================================
开始部署 Admin 前端
========================================

[1/3] 构建项目...
✓ 构建完成

[2/3] 压缩文件...
✓ 压缩完成: admin-dist-20241121-153000.7z

[3/3] 上传到服务器...
服务器: xin-im-prod-0
目标路径: /home/ubuntu/admin
✓ 上传完成

清理本地文件...

========================================
上传成功! 🎉
========================================

下一步: 登录服务器手动部署
========================================

实际命令 (复制粘贴执行):

ssh xin-im-prod-0 << 'REMOTE_CMD'
# 备份
[ -d "/home/ubuntu/admin" ] && cp -r /home/ubuntu/admin /home/ubuntu/admin_backup_$(date +%Y%m%d-%H%M%S)

# 重新部署
rm -rf /home/ubuntu/admin
mkdir -p /home/ubuntu/admin
7z x /tmp/admin-dist-20241121-153000.7z -o/home/ubuntu/admin -y

# 设置权限
sudo chmod 755 /home /home/ubuntu
find /home/ubuntu/admin -type d -exec chmod 755 {} \;
find /home/ubuntu/admin -type f -exec chmod 644 {} \;

# 清理
rm -f /tmp/admin-dist-20241121-153000.7z

echo "部署完成!"
REMOTE_CMD

访问地址: http://admin.chatlyme.com
```

### Docker 部署

项目也支持使用 Docker 部署,详见 [nginx/README.md](./nginx/README.md)

### 常见问题

#### 1. 找不到 7z 命令

安装 p7zip:
```bash
# macOS
brew install p7zip

# Ubuntu/Debian
sudo apt-get install p7zip-full
```

#### 2. SSH 连接失败

配置 SSH 密钥认证:
```bash
ssh-copy-id user@server-ip
```

#### 3. 服务器权限不足

确保 SSH 用户有目标目录的写权限,或使用 sudo

#### 4. 构建失败

检查依赖是否安装:
```bash
bun install
```

#### 5. 部署后页面加载但部分 JS 文件 404

**现象**: 页面可以访问(200),但是部分 JS/CSS 文件返回 404

**可能的根本原因** ⚠️:

1. **部署脚本权限设置失败** (最常见)
   - 如果看到 `chmod: changing permissions of '/home': Operation not permitted`
   - 说明普通用户无法修改 /home 目录权限
   - 需要手动执行: `sudo chmod 755 /home /home/ubuntu`

2. **压缩命令问题** (已修复)
   - 旧版本使用 `7z a ... *` 可能不完整
   - 新版本使用 `7z a ... . -r` 递归压缩所有内容

3. **浏览器缓存**
   - 浏览器缓存了旧的 404 响应
   - 需要硬刷新或清除缓存

**快速修复** (在服务器上执行):
```bash
# 1. 设置父目录权限 (最关键!)
sudo chmod 755 /home /home/ubuntu

# 2. 设置部署目录权限
find /home/ubuntu/admin -type d -exec chmod 755 {} \;
find /home/ubuntu/admin -type f -exec chmod 644 {} \;

# 3. 重新加载 nginx
sudo systemctl reload nginx

# 4. 清除浏览器缓存并测试 (Ctrl+Shift+R / Cmd+Shift+R)
```

**诊断步骤**:
```bash
# 1. 检查父目录权限 (最重要!)
ls -ld /home /home/ubuntu /home/ubuntu/admin
# 应该都显示 drwxr-xr-x (755)

# 2. 检查所有 JS 文件是否都存在
ls -lh /home/ubuntu/admin/assets/*.js | wc -l

# 3. 查看 nginx 访问日志,找出哪些文件 404
sudo tail -50 /var/log/nginx/access.log | grep "\.js"

# 4. 测试 nginx 用户能否访问文件
sudo -u www-data cat /home/ubuntu/admin/index.html >/dev/null && echo "✓ 可访问" || echo "✗ 无法访问"

# 5. 运行完整诊断脚本
./diagnose-js-404.sh
```

**常见原因**:
1. **浏览器缓存** - 浏览器缓存了旧的 404 响应
   ```bash
   # 解决: 清除浏览器缓存或硬刷新 (Ctrl+Shift+R / Cmd+Shift+R)
   ```

2. **index.html 中的路径错误** - 构建时生成的路径不正确
   ```bash
   # 检查 index.html 中的资源引用路径
   grep -o 'src="[^"]*"' /home/ubuntu/admin/index.html
   grep -o 'href="[^"]*"' /home/ubuntu/admin/index.html
   ```

3. **Vite 构建配置问题** - base 路径配置不正确
   ```javascript
   // vite.config.ts 应该配置:
   export default defineConfig({
     base: '/',  // 确保是根路径
   })
   ```

4. **文件名大小写敏感** - Linux 区分大小写
   ```bash
   # 检查文件名是否与引用一致
   # 例如: App.js vs app.js
   ```

#### 6. 部署后访问 403/404

**快速诊断工具**:
```bash
# 运行诊断脚本
cd admin
./diagnose-403.sh
```

**常见原因和解决方案**:

1. **Nginx 配置路径错误** ⚠️ 最常见
   ```bash
   # 检查 nginx 配置
   sudo nginx -t
   sudo grep "root" /etc/nginx/sites-enabled/admin.conf

   # 确保 root 指向正确路径
   root /home/ubuntu/admin;  # 应该是这个路径

   # 修改后重启
   sudo systemctl reload nginx
   ```

2. **父目录权限不足** ⚠️ 最常见！

   **问题**: `/home/ubuntu` 默认权限是 750，其他用户(nginx)无法进入

   **错误日志**:
   ```
   stat() "/home/ubuntu/admin/" failed (13: Permission denied)
   ```

   **解决方案**:
   ```bash
   # 关键: 设置父目录权限,让 Nginx 能进入
   sudo chmod 755 /home
   sudo chmod 755 /home/ubuntu
   sudo chmod 755 /home/ubuntu/admin

   # 验证: 测试 nginx 用户能否访问
   sudo -u www-data cat /home/ubuntu/admin/index.html

   # 检查整个路径权限
   namei -l /home/ubuntu/admin/index.html
   ```

   **说明**: Nginx 需要对从根目录到目标文件的**整个路径**都有 x (执行/进入) 权限！

3. **文件和目录权限**:
   ```bash
   # 目录权限: 755 (Nginx 需要 x 权限进入目录)
   find /home/ubuntu/admin -type d -exec chmod 755 {} \;

   # 文件权限: 644 (Nginx 只需要读权限)
   find /home/ubuntu/admin -type f -exec chmod 644 {} \;
   ```

4. **SELinux 阻止** (CentOS/RHEL):
   ```bash
   # 检查 SELinux
   getenforce

   # 临时关闭测试
   sudo setenforce 0

   # 或设置正确的上下文
   sudo chcon -R -t httpd_sys_content_t /home/ubuntu/admin
   ```

5. **Nginx 错误日志**:
   ```bash
   # 查看详细错误
   sudo tail -50 /var/log/nginx/error.log
   ```

**权限说明**:
- `755` (目录) = `rwxr-xr-x` - 所有者全部权限,其他人可读可执行
- `644` (文件) = `rw-r--r--` - 所有者可读写,其他人只读
- ❌ 不要使用 `600` 或 `700` - Nginx 无法访问

## 开发规范

### 代码风格

项目使用 ESLint + Prettier + Stylelint 进行代码规范检查。

提交代码前会自动执行 lint 检查和格式化:

```bash
# 自动触发 (git commit 时)
bun run lint-staged
```

### Git Commit 规范

遵循 Conventional Commits 规范:

- `feat`: 新功能
- `fix`: 修复 bug
- `docs`: 文档更新
- `style`: 代码格式调整
- `refactor`: 重构
- `perf`: 性能优化
- `test`: 测试相关
- `chore`: 构建/工具相关

示例:
```
feat(user): 添加用户管理页面
fix(login): 修复登录状态异常问题
docs(readme): 更新部署文档
```

## 安全建议

1. **不要提交敏感配置**
   - `deploy.config` 已添加到 `.gitignore`
   - 不要在代码中硬编码密钥和密码

2. **使用环境变量**
   - API 地址等配置使用环境变量
   - 不同环境使用不同的配置文件

3. **SSH 密钥认证**
   - 部署时使用 SSH 密钥而非密码
   - 定期更换 SSH 密钥

4. **限制服务器权限**
   - 使用专门的部署用户
   - 避免直接使用 root 用户

5. **定期备份**
   - 部署脚本会自动备份旧版本
   - 建议定期备份到异地

## 相关文档

- [Nginx 部署配置](./nginx/README.md) - Nginx 配置和 Docker 部署说明
- [Arco Design Vue](https://arco.design/vue/docs/start) - UI 组件库文档
- [Vite](https://vitejs.dev/) - 构建工具文档
- [Vue 3](https://v3.vuejs.org/) - Vue.js 官方文档
- [Pinia](https://pinia.vuejs.org/) - 状态管理文档

## License

MIT
