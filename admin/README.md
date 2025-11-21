# Admin 管理后台

基于 Arco Design Pro Vue 的管理后台系统。

## 项目介绍

这是一个使用 Vue 3 + TypeScript + Vite + Arco Design 构建的现代化管理后台应用。

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
- ✅ 服务器端自动解压和部署
- ✅ 自动备份旧版本
- ✅ 设置文件权限

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

在服务器上解压并部署...
备份旧文件到: /home/ubuntu/admin_backup_20241121-153010
部署完成!

清理本地文件...

========================================
部署成功! 🎉
========================================
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

#### 5. 部署后访问 403

设置正确的文件权限:
```bash
sudo chown -R www-data:www-data /home/ubuntu/admin
sudo chmod -R 755 /home/ubuntu/admin
```

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
