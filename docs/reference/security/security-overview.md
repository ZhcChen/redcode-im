# 安全配置指南

## 概述

RedCode IM 采用了多层次的安全防护措施，确保系统安全可靠地运行。本文档详细介绍了系统的安全配置和最佳实践。

## 🛡️ 安全架构

### 认证与授权

#### 1. JWT Token 认证
- **算法**: RS256 (RSA with SHA-256)
- **密钥管理**:
  - 私钥: 仅服务器持有
  - 公钥: 可安全分发
- **Token 结构**:
  - 用户ID (`sub`)
  - 用户名 (`username`)
  - 发行者 (`iss`)
  - 受众 (`aud`)
  - 过期时间 (`exp`)
  - 签发时间 (`iat`)
  - 令牌ID (`jti`) - 用于撤销

#### 2. 密码安全
- **加密算法**: Argon2id (推荐) / bcrypt
- **参数配置**:
  - 内存成本: 64 MB
  - 时间成本: 3 次迭代
  - 并行度: CPU 核心数
- **盐值**: 每个密码使用随机盐值

#### 3. API 密钥
- **格式**: 32 字节十六进制字符串
- **存储**: 加密存储
- **轮换**: 建议每 30 天轮换一次

### 网络安全

#### 1. HTTPS 强制
- **HSTS**: 启用 HTTP 严格传输安全
- **配置**:
  ```
  Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
  ```

#### 2. CORS 配置
仅允许信任的域名：

```rust
.allow_origin([
    "https://redcode-im.com",
    "https://www.redcode-im.com",
    "http://localhost:8010",  // 开发环境
    "http://localhost:1420",  // 开发环境
])
```

#### 3. 安全头
自动添加以下安全头：

- `X-Content-Type-Options: nosniff`
  - 防止 MIME 类型嗅探

- `X-XSS-Protection: 1; mode=block`
  - 启用 XSS 保护

- `X-Frame-Options: DENY`
  - 防止点击劫持

- `Content-Security-Policy`
  - 防止 XSS 攻击和代码注入
  - 默认策略: 仅允许同源资源

- `Referrer-Policy: strict-origin-when-cross-origin`
  - 控制引用者信息泄露

- `Permissions-Policy`
  - 限制浏览器功能访问
  - 禁用相机、麦克风、地理位置等

### 数据保护

#### 1. 敏感数据加密
- **密码**: 使用 Argon2id 哈希
- **JWT 私钥**: 加密存储
- **API 密钥**: 加密存储

#### 2. 数据库安全
- **连接加密**: 使用 SSL 连接数据库
- **最小权限**: 数据库用户只具有必要权限
- **参数化查询**: 防止 SQL 注入

#### 3. 缓存安全
- **Redis 认证**: 使用密码保护
- **网络隔离**: Redis 仅监听内网
- **数据过期**: 合理设置 TTL

### 输入验证

#### 1. 请求参数验证
- **必填字段**: 检查所有必填参数
- **类型验证**: 确保数据类型正确
- **长度限制**: 设置合理的字符串长度限制
- **格式验证**: 验证邮箱、手机号等格式

#### 2. 文件上传验证
- **文件类型**: 严格限制允许的类型
- **文件大小**: 限制最大上传大小
- **文件内容**: 检查文件头和内容
- **杀毒扫描**: 集成杀毒软件扫描

#### 3. SQL 注入防护
- **参数化查询**: 所有数据库查询使用参数化
- **ORM**: 优先使用 ORM 框架
- **输入转义**: 特殊字符转义

### 访问控制

#### 1. 速率限制
- **接口限流**: 不同接口设置不同限流
- **IP 限制**: 基于 IP 的请求限制
- **用户限制**: 基于用户的请求限制

默认配置：
```
- GET 请求: 1000/分钟
- POST 请求: 100/分钟
- 文件上传: 10/分钟
```

#### 2. 权限控制
- **RBAC**: 基于角色的访问控制
- **最小权限**: 用户只具有必要权限
- **资源隔离**: 不同用户的数据严格隔离

#### 3. API 访问控制
- **API 密钥**: 第三方服务需要 API 密钥
- **白名单**: 关键接口可配置 IP 白名单
- **审计日志**: 记录所有关键操作

## 🔒 环境配置

### 开发环境

1. **环境变量**:
```bash
# .env.development
DATABASE_URL=postgresql://user:password@localhost:5432/redcode_im_dev
REDIS_SESSION_URL=redis://localhost:6381
REDIS_PUBSUB_URL=redis://localhost:6381
REDIS_CACHE_URL=redis://localhost:6381
JWT_SECRET=development-secret-not-for-production
JWT_PRIVATE_KEY_PATH=./keys/private.pem
JWT_PUBLIC_KEY_PATH=./keys/public.pem
```

2. **安全设置**:
   - 使用测试数据库
   - 启用详细日志
   - 允许本地网络访问

### 生产环境

1. **环境变量**:
```bash
# .env.production
DATABASE_URL=postgresql://user:strong-password@prod-db:5432/redcode_im
REDIS_SESSION_URL=redis://:strong-redis-password@prod-redis:6379
REDIS_PUBSUB_URL=redis://:strong-redis-password@prod-redis:6379
REDIS_CACHE_URL=redis://:strong-redis-password@prod-redis:6379
JWT_SECRET=<从密钥管理服务获取>
JWT_PRIVATE_KEY_PATH=/secure/keys/private.pem
JWT_PUBLIC_KEY_PATH=/secure/keys/public.pem
API_KEY_ENCRYPTION_KEY=<32字节密钥>
```

2. **安全设置**:
   - 禁用调试模式
   - 隐藏错误详情
   - 严格 CORS 策略
   - 启用所有安全头

### 密钥管理

#### 1. 生成 RSA 密钥对
```bash
# 生成 2048 位 RSA 私钥
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out private.pem

# 从私钥生成公钥
openssl rsa -pubout -in private.pem -out public.pem
```

#### 2. 密钥存储
- **私钥**: 存储在安全的密钥管理系统
- **API 密钥**: 加密存储在数据库
- **密码**: 仅存储哈希值

#### 3. 密钥轮换
- **JWT 密钥**: 每年轮换
- **API 密钥**: 每季度轮换
- **数据库密码**: 每半年轮换

## 📋 安全检查清单

### 部署前检查

- [ ] 生产环境所有配置已更新
- [ ] 所有默认密码已更改
- [ ] HTTPS 证书已安装
- [ ] 防火墙已配置
- [ ] 安全头已启用
- [ ] 速率限制已配置
- [ ] 审计日志已启用

### 日常监控

- [ ] 异常登录监控
- [ ] 失败认证监控
- [ ] 速率限制触发监控
- [ ] 错误日志分析
- [ ] 性能指标监控

### 定期安全审计

- [ ] 用户权限审查
- [ ] API 访问审计
- [ ] 数据备份测试
- [ ] 漏洞扫描
- [ ] 渗透测试

## 🚨 安全事件响应

### 事件分类

1. **低危**:
   - 单个失败登录
   - 轻微的速率限制触发
   - 非关键信息泄露

2. **中危**:
   - 密码泄露
   - API 密钥泄露
   - 权限绕过

3. **高危**:
   - 数据库泄露
   - 私钥泄露
   - 系统被入侵

### 响应流程

1. **检测**: 监控系统告警
2. **评估**: 确定事件影响范围
3. **隔离**: 隔离受影响系统
4. **根除**: 消除威胁
5. **恢复**: 恢复正常服务
6. **总结**: 记录经验教训

### 联系方式

- **安全团队**: security@redcode-im.com
- **紧急联系**: +86-xxx-xxxx-xxxx (24/7)
- **PGP 公钥**: [security-pubkey.asc](https://redcode-im.com/security-pubkey.asc)

## 📚 安全最佳实践

### 开发者指南

1. **代码安全**:
   - 避免硬编码敏感信息
   - 使用安全的随机数生成器
   - 避免反序列化不可信数据
   - 及时更新依赖

2. **数据库安全**:
   - 使用参数化查询
   - 最小数据库权限
   - 定期备份数据
   - 加密敏感数据

3. **API 安全**:
   - 验证所有输入
   - 使用 HTTPS
   - 设置合理的超时
   - 记录审计日志

### 运维指南

1. **服务器安全**:
   - 定期更新系统
   - 禁用不必要的服务
   - 配置防火墙
   - 使用入侵检测系统

2. **网络安全**:
   - 使用 VPN
   - 限制 SSH 访问
   - 定期更换密码
   - 监控网络流量

3. **数据安全**:
   - 定期备份
   - 加密存储
   - 安全传输
   - 定期测试恢复

## 🔧 配置示例

### nginx 配置

```nginx
server {
    listen 443 ssl http2;
    server_name api.redcode-im.com;

    # SSL 证书
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # 安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # 安全头
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload";
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";

    # 上游服务器
    location / {
        proxy_pass http://127.0.0.1:8010;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### PostgreSQL 配置

```sql
-- 创建专用用户
CREATE USER redcode_app WITH PASSWORD 'strong_password';
GRANT CONNECT ON DATABASE redcode_im TO redcode_app;
GRANT USAGE ON SCHEMA public TO redcode_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO redcode_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO redcode_app;
```

### Redis 配置

```conf
# redis.conf
requirepass strong_redis_password
bind 127.0.0.1
port 6379
timeout 300
maxmemory 2gb
maxmemory-policy allkeys-lru
```

## 📖 参考资料

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Mozilla Security Guidelines](https://infosec.mozilla.org/guidelines/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [Rust Security Guide](https://cargo-audit.daemon.xyz/)
- [JWT Security Best Practices](https://tools.ietf.org/html/rfc8725)

## 🆕 更新日志

### v1.0.0 (2024-01-01)
- 初始安全配置
- 实现基础认证和授权
- 添加安全头和 CORS
- 实现速率限制

### 计划中
- [ ] 端到端加密
- [ ] 多因素认证 (MFA)
- [ ] 单点登录 (SSO)
- [ ] 行为分析
- [ ] 威胁情报集成

---

**注意**: 请定期更新此文档以反映最新的安全配置和最佳实践。
