# IP地理位置解析开关功能

## 功能概述

本功能为项目的IP地理位置解析添加了一个Redis控制的开关，用于管理员控制是否启用用户IP解析用于数据统计。

## 关键特性

### 1. Redis开关控制
- **键名**：`redcode:config:ip_geolocation_enabled`
- **默认值**：关闭（未设置或值为0时关闭）
- **开启值**：1
- **关闭值**：0

### 2. 开关行为
- ✅ **开（值为1）**：正常进行IP地理位置解析，用于管理员数据统计
- ❌ **关（key不存在或值为0）**：跳过IP解析，不记录地理位置信息

### 3. 影响范围
开关控制以下功能的IP解析：
- WebSocket心跳时的IP变化检测和地理位置更新
- 用户首次连接时的地理位置初始化

## API接口

### 查询开关状态
```bash
GET /api/admin/ip-geolocation/enabled
```

**响应示例**：
```json
{
  "enabled": true,
  "description": "控制是否启用用户IP地理位置解析功能，用于管理员数据统计"
}
```

### 设置开关状态
```bash
PATCH /api/admin/ip-geolocation/enabled
Content-Type: application/json

{
  "enabled": true
}
```

**响应示例**：
```json
{
  "enabled": true,
  "description": "控制是否启用用户IP地理位置解析功能，用于管理员数据统计"
}
```

## 代码实现

### 1. Redis配置管理 (`src/redis/mod.rs`)
- 添加了配置键名前缀：`CONFIG_PREFIX`
- 添加了IP解析开关键名：`IP_GEOLOCATION_ENABLED_KEY`
- 新增 `get_config_client()` 方法获取配置Redis连接

### 2. 地理位置服务 (`src/services/geolocation.rs`)
新增两个函数：
- `is_ip_geolocation_enabled()` - 检查开关状态
- `set_ip_geolocation_enabled()` - 设置开关状态

### 3. WebSocket模块 (`src/websocket/mod.rs`)
修改了两个位置的IP解析逻辑：
- 心跳更新时的IP变化检测（第255行）
- 首次连接时的地理位置初始化（第478行）

都添加了开关检查，只有开关开启时才进行IP解析。

### 4. Admin API (`src/handlers/admin.rs`)
新增两个API端点：
- `get_ip_geolocation_enabled()` - 查询开关状态
- `set_ip_geolocation_enabled()` - 设置开关状态

### 5. 路由配置 (`src/routes.rs`)
添加了路由：
```rust
.route(
    "/api/admin/ip-geolocation/enabled",
    get(admin::get_ip_geolocation_enabled)
        .patch(admin::set_ip_geolocation_enabled),
)
```

## 使用示例

### 开启IP解析
```bash
curl -X PATCH http://localhost:3000/api/admin/ip-geolocation/enabled \
  -H "Content-Type: application/json" \
  -d '{"enabled": true}'
```

### 关闭IP解析
```bash
curl -X PATCH http://localhost:3000/api/admin/ip-geolocation/enabled \
  -H "Content-Type: application/json" \
  -d '{"enabled": false}'
```

### 查询当前状态
```bash
curl http://localhost:3000/api/admin/ip-geolocation/enabled
```

## 性能影响

### 开关开启时
- 正常进行IP地理位置解析
- 调用第三方IP地理位置API
- 消耗IPinfo token额度
- 增加数据库写入操作

### 开关关闭时
- 完全跳过IP解析流程
- 不调用第三方API
- 不消耗token额度
- 无额外数据库写入

## 安全性

1. **默认安全**：开关默认关闭，避免不必要的IP解析
2. **Redis隔离**：配置存储在独立的Redis命名空间
3. **访问控制**：API需要管理员权限访问

## 监控与日志

### 开关状态日志
```
INFO IP地理位置解析功能开关已设置为: 开启
INFO 查询IP地理位置解析功能开关状态: 关闭
```

### 功能执行日志
- 开启时：`检测到用户 {user_id} IP变化: {ip}`
- 关闭时：静默跳过，无日志输出

## 注意事项

1. **Token消耗**：开启开关后会消耗IPinfo API token额度
2. **数据库写入**：每次IP变化都会写入用户地理位置表
3. **隐私保护**：关闭开关后不会记录用户地理位置信息
4. **配置持久性**：开关状态存储在Redis中，带1年过期时间

## 部署建议

1. **开发环境**：建议开启开关用于测试
2. **生产环境**：
   - 如果需要地理位置统计，开启开关
   - 如果不需要或担心隐私问题，关闭开关
   - 定期检查Redis中的开关状态

## 技术细节

### Redis键格式
```
redcode:config:ip_geolocation_enabled
```

### 数据类型
- String类型
- 值："0"（关闭）或"1"（开启）
- TTL：365天（可选）

### 错误处理
- Redis连接失败：默认关闭功能
- 读取失败：记录警告日志，默认关闭
- 设置失败：返回500错误

## 相关文件

- `src/redis/mod.rs` - Redis配置管理
- `src/services/geolocation.rs` - 地理位置服务和开关逻辑
- `src/websocket/mod.rs` - WebSocket连接处理
- `src/handlers/admin.rs` - Admin API实现
- `src/routes.rs` - 路由配置

---

**注意**：本功能需要Redis服务正常运行，且IPinfo API token配置正确才能正常工作。
