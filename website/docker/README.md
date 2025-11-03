# Website Docker 配置说明

本目录包含 website 项目的 Docker 配置文件。

## 文件说明

- `Dockerfile` - 生产环境构建文件
- `Dockerfile.dev` - 开发环境构建文件
- `docker-compose.yml` - 开发环境配置
- `docker-compose.prod.yml` - 生产环境配置
- `.dockerignore` - Docker 构建忽略文件

## 使用方法

### 开发环境

在 `website` 目录下运行：

```bash
cd docker
docker-compose up -d
```

或使用完整路径：

```bash
cd website/docker
docker-compose -f docker-compose.yml up -d
```

访问: http://localhost:8015

### 生产环境

```bash
cd website/docker
docker-compose -f docker-compose.prod.yml up -d --build
```

### 停止服务

```bash
cd website/docker
docker-compose down
# 或生产环境
docker-compose -f docker-compose.prod.yml down
```

## 注意事项

- 开发环境会挂载源代码目录，支持热重载
- 生产环境需要先构建镜像
- 端口 8015 需要在宿主机上可用
- 开发环境会排除 `node_modules` 和 `.nuxt` 目录的挂载，使用容器内的依赖

