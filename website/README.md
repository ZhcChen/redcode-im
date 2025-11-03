# Website

Nuxt.js 项目

## 安装依赖

```bash
bun install
```

## 开发

启动开发服务器（默认运行在 `http://localhost:8015`）：

```bash
bun run dev
```

## 构建

构建生产版本：

```bash
bun run build
```

## 预览

预览生产构建：

```bash
bun run preview
```

## 部署

### 方式一：自动部署脚本（推荐）

自动完成构建、压缩和上传到服务器：

```bash
# 1. 首次使用前配置服务器信息
cp .deploy.env.example .deploy.env
# 编辑 .deploy.env 文件，设置：
# SERVER_HOST=your-server.com
# SERVER_USER=root
# SERVER_PATH=/path/to/website/docker

# 2. 执行部署脚本
./deploy.sh
```

部署脚本会：
1. 执行 `bun run build` 构建应用
2. 使用 7z 压缩构建产物（`.output`、`public`、`nuxt.config.ts`、`package.json`）
3. 通过 scp 上传到服务器指定目录
4. 提示下一步操作

**注意事项：**
- 需要安装 7z：`brew install p7zip`（macOS）或 `apt-get install p7zip-full`（Linux）
- 需要配置 SSH 密钥，确保可以通过 scp 访问服务器
- 服务器上需要已安装 Docker 和 docker-compose

### 方式二：本地构建打包

仅本地构建和打包，不上传：

```bash
./build.sh
```

这会生成一个带时间戳的压缩包（`.7z` 或 `.tar.gz`），然后可以手动上传到服务器。

### 方式三：Docker 部署

在服务器上部署：

```bash
# 1. 上传构建产物压缩包到服务器
# 将 build.7z 或 build.tar.gz 放到 website/docker/ 目录

# 2. 在服务器上构建和运行
cd website/docker
docker-compose up -d --build

# 3. 管理服务
docker-compose down          # 停止服务
docker-compose logs -f website  # 查看日志
docker-compose restart website  # 重启服务
```

详细说明请参考 [docker/README.md](./docker/README.md)
