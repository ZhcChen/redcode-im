# Admin 前端部署配置

这个目录包含了用于部署 admin 前端应用的 Nginx 配置。

## 文件说明

- `nginx.conf` - Nginx 服务器配置文件
- `Dockerfile` - Docker 镜像构建文件
- `docker-compose.yml` - Docker Compose 编排文件
- `README.md` - 本说明文件

## 配置特性

### Nginx 配置特性

1. **Gzip 压缩** - 自动压缩静态资源,减少传输大小
2. **静态资源缓存** - JS/CSS/图片等资源缓存 30 天
3. **HTML 不缓存** - 确保应用更新后立即生效
4. **SPA 路由支持** - 支持 Vue Router 的 history 模式
5. **API 代理** - 预留了 API 代理配置(需要时取消注释)

## 使用方式

### 方式一: 直接使用 Nginx

1. 构建前端项目:
```bash
cd /path/to/admin
pnpm run build
```

2. 将 `dist` 目录部署到 `/usr/share/nginx/html`

3. 复制配置文件:
```bash
sudo cp nginx/nginx.conf /etc/nginx/conf.d/admin.conf
```

4. 重启 Nginx:
```bash
sudo nginx -s reload
```

### 方式二: 使用 Docker

1. 构建镜像:
```bash
cd /path/to/admin
docker build -t redcode-admin -f nginx/Dockerfile .
```

2. 运行容器:
```bash
docker run -d -p 8080:80 --name redcode-admin redcode-admin
```

### 方式三: 使用 Docker Compose (推荐)

```bash
cd /path/to/admin/nginx
docker-compose up -d
```

访问 http://localhost:8080 即可查看应用

## 配置说明

### 修改端口

编辑 `docker-compose.yml` 中的端口映射:
```yaml
ports:
  - "8080:80"  # 将 8080 改为你想要的端口
```

### 配置 API 代理

如果需要代理后端 API,编辑 `nginx.conf` 并取消注释以下部分:

```nginx
location /api/ {
    proxy_pass http://backend:8080;  # 修改为你的后端地址
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

### HTTPS 配置

如果需要启用 HTTPS,修改 `nginx.conf` 添加:

```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # ... 其他配置保持不变
}

# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}
```

## 常用命令

### Docker 相关

```bash
# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down

# 重启服务
docker-compose restart

# 重新构建并启动
docker-compose up -d --build
```

### Nginx 相关

```bash
# 测试配置文件
nginx -t

# 重载配置
nginx -s reload

# 查看错误日志
tail -f /var/log/nginx/error.log
```

## 故障排查

### 404 错误
- 确保 `dist` 目录已正确构建
- 检查 Nginx 配置中的 root 路径是否正确

### 路由刷新 404
- 确保配置了 `try_files $uri $uri/ /index.html;`
- 检查 Vue Router 是否使用 history 模式

### 静态资源加载失败
- 检查 `publicPath` 配置
- 确认资源路径是否正确

### API 代理失败
- 检查后端服务是否正常运行
- 确认 proxy_pass 地址是否正确
- 查看 Nginx 错误日志
