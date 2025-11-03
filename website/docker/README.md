# Website Docker 配置说明

本目录包含 website 项目的 Docker 配置文件。

## 文件说明

- `Dockerfile` - Docker 构建文件
- `docker-compose.yml` - Docker Compose 配置
- `.dockerignore` - Docker 构建忽略文件

## 使用方法

### 启动服务

在 `website/docker` 目录下运行：

```bash
cd docker
docker-compose up -d
```

访问: http://localhost:8015

### 停止服务

```bash
cd docker
docker-compose down
```

### 查看日志

```bash
cd docker
docker-compose logs -f website
```

## 注意事项

- 配置会挂载源代码目录，支持热重载
- `node_modules` 和 `.nuxt` 目录使用容器内的依赖，避免挂载冲突
- 端口 8015 需要在宿主机上可用


