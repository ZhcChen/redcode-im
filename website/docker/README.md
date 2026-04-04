# Website Docker 配置说明

本目录包含 website 项目的 Docker 配置文件。

## 文件说明

- `Dockerfile` - Docker 运行时镜像（用于解压和运行构建产物）
- `docker-compose.yml` - Docker Compose 配置
- `.dockerignore` - Docker 构建忽略文件

## 部署流程

### 方式一：使用自动部署脚本（推荐）

在 `website` 目录下运行：

```bash
# 1. 配置服务器信息（首次使用）
cp .deploy.env.example .deploy.env
# 编辑 .deploy.env 文件，设置服务器地址、用户名和路径

# 2. 执行部署脚本（会自动构建、压缩、上传）
./deploy.sh
```

### 方式二：手动部署

#### 1. 本地构建打包

在 `website` 目录下运行：

```bash
./build.sh
```

这会生成一个带时间戳的压缩包，例如：`website-build-20240101-120000.7z`

#### 2. 上传并解压到服务器

将压缩包上传到服务器，解压到 docker 目录：

```bash
# 在服务器上
cd /path/to/website/docker
# 上传压缩包后解压
tar -xzf website-build-*.tar.gz -C .  # 如果是 tar.gz
# 或
7z x -y website-build-*.7z -o.  # 如果是 7z（-y 参数自动确认覆盖）
```

#### 3. 构建和运行

```bash
cd /path/to/website/docker
docker compose up -d --build
```

访问: http://localhost:8015

### 4. 管理服务

```bash
# 停止服务
docker compose down

# 查看日志
docker compose logs -f website

# 重启服务
docker compose restart website
```

## 注意事项

- Dockerfile 直接复制已解压的构建产物（`.output`、`public`、`nuxt.config.ts`、`package.json`）
- 需要在服务器上先解压构建产物压缩包，确保这些文件和目录存在于 docker 目录下
- 使用 `deploy.sh` 脚本可以自动完成构建、压缩和上传
- 使用 `build.sh` 脚本仅进行本地构建打包
- 端口 8015 需要在宿主机上可用
- 需要确保 SSH 密钥已配置，可以通过 scp 访问服务器


