# Website Docker 配置说明

本目录包含 website 项目的 Docker 配置文件。

## 文件说明

- `Dockerfile` - Docker 运行时镜像（用于解压和运行构建产物）
- `docker-compose.yml` - Docker Compose 配置
- `.dockerignore` - Docker 构建忽略文件

## 部署流程

### 1. 本地构建打包

在 `website` 目录下运行：

```bash
chmod +x build.sh
./build.sh
```

这会生成一个带时间戳的压缩包，例如：`website-build-20240101-120000.tar.gz`

### 2. 上传到服务器

将压缩包上传到服务器的 `website/docker` 目录，并重命名为 `build.tar.gz`：

```bash
# 在服务器上
cd /path/to/website/docker
mv /path/to/website-build-*.tar.gz build.tar.gz
```

### 3. 构建和运行

```bash
cd /path/to/website/docker
docker-compose up -d --build
```

访问: http://localhost:8015

### 4. 管理服务

```bash
# 停止服务
docker-compose down

# 查看日志
docker-compose logs -f website

# 重启服务
docker-compose restart website
```

## 注意事项

- Dockerfile 期望在构建上下文中存在 `build.tar.gz` 文件
- 压缩包应包含以下文件：`.output`、`public`、`nuxt.config.ts`、`package.json`
- 使用 `build.sh` 脚本可以自动生成正确的压缩包
- 端口 8015 需要在宿主机上可用
- 构建产物通过本地 `build.sh` 脚本生成并上传


