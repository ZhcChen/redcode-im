# Redis多实例配置指南

## 概述

redcode-im项目使用Redis多实例架构，将不同功能的数据分离到独立的Redis实例中，提高性能和可靠性。

## Redis实例配置

### 1. 主Redis实例 (端口: 6379)
- **用途**: 基础Redis操作和连接管理
- **模式**: 标准模式
- **持久化**: 开启AOF
- **配置**: 默认Redis配置

### 2. Session专用Redis (端口: 6381)
- **用途**: 用户会话存储、节点心跳管理
- **模式**: 持久化模式
- **持久化**: AOF + RDB (多重保障)
- **内存限制**: 128MB
- **淘汰策略**: volatile-lru (只淘汰设置TTL的键)

### 3. Streams专用Redis (端口: 6382)
- **用途**: Redis Streams消息流存储，消息推送和订阅
- **模式**: 持久化流模式
- **持久化**: AOF + RDB (双重保障，数据不丢失)
- **内存限制**: 512MB
- **淘汰策略**: volatile-lru (保护未设置TTL的流数据)

### 4. Cache专用Redis (端口: 6383)
- **用途**: 用户/房间信息缓存，高频读写
- **模式**: 纯缓存模式
- **持久化**: 关闭
- **内存限制**: 512MB
- **淘汰策略**: allkeys-lru

## 快速启动

### 方式一：使用启动脚本 (推荐)

```bash
# 启动所有Redis实例
./start-redis.sh start

# 检查状态
./start-redis.sh status

# 停止所有实例
./start-redis.sh stop
```

### 方式二：使用Docker Compose (仅Redis)

```bash
# 启动所有Redis实例
docker-compose -f docker-compose-redis.yml up -d

# 查看日志
docker-compose -f docker-compose-redis.yml logs -f

# 停止所有实例
docker-compose -f docker-compose-redis.yml down
```

### 方式三：使用完整Docker环境 (推荐)

```bash
# 启动完整环境 (PostgreSQL + 4个Redis实例 + 后端服务)
./docker-start.sh start

# 启动包含管理工具的环境
./docker-start.sh start-with-tools

# 检查服务状态
./docker-start.sh status

# 查看服务信息
./docker-start.sh info

# 查看日志
./docker-start.sh logs [service]
```

### 方式四：手动启动

```bash
# 启动主Redis
redis-server --port 6379 --appendonly yes

# 启动Session Redis
redis-server --port 6381 --appendonly yes \
  --save 900 1 --save 300 10 --save 60 10000 \
  --maxmemory 128mb --maxmemory-policy volatile-lru

# 启动Streams Redis
redis-server --port 6382 \
  --appendonly yes --aof-use-rdb-preamble yes \
  --save 900 1 --save 300 10 \
  --maxmemory 512mb --maxmemory-policy volatile-lru

# 启动Cache Redis
redis-server --port 6383 \
  --maxmemory 512mb --maxmemory-policy allkeys-lru \
  --save ""
```

## 环境配置

在`.env`文件中配置Redis连接：

```bash
REDIS_URL=redis://localhost:6379
REDIS_SESSION_URL=redis://localhost:6381
REDIS_STREAM_URL=redis://localhost:6382
REDIS_CACHE_URL=redis://localhost:6383
```

## 数据结构说明

### Session Redis数据结构
```
session:{user_id}           # 用户会话信息
node_sessions:{node_id}     # 节点会话列表
node_heartbeat:{node_id}    # 节点心跳信息
active_nodes                # 活跃节点集合
```

### Streams Redis数据结构
```
stream:room:{room_id}       # 房间消息流 (持久化存储)
consumer_group:node_{id}    # 节点消费者组
```
**重要**: Streams Redis存储关键的消息推送和订阅数据，必须确保持久化配置正确，避免消息丢失。

### Cache Redis数据结构
```
cache:user:{user_id}        # 用户信息缓存
cache:room:{room_id}        # 房间信息缓存
cache:room_members:{id}     # 房间成员缓存
user_online:{user_id}       # 用户在线状态
```

## 监控和维护

### 检查实例状态
```bash
# 检查所有Redis实例
./start-redis.sh status

# 或手动检查
redis-cli -p 6379 ping
redis-cli -p 6381 ping
redis-cli -p 6382 ping
redis-cli -p 6383 ping
```

### 查看内存使用
```bash
redis-cli -p 6379 info memory
redis-cli -p 6381 info memory
redis-cli -p 6382 info memory
redis-cli -p 6383 info memory
```

### 清理数据
```bash
# 清空缓存数据 (Cache Redis)
redis-cli -p 6383 flushall

# 清理过期的Stream数据 (Streams Redis)
redis-cli -p 6382 xtrim stream:room:* MAXLEN 1000
```

## 故障排除

### 端口占用
```bash
# 检查端口占用
lsof -i :6379
lsof -i :6381
lsof -i :6382
lsof -i :6383

# 强制停止Redis
pkill -f redis-server
```

### 连接问题
1. 检查Redis实例是否运行
2. 检查防火墙设置
3. 验证.env配置文件
4. 查看Redis日志

### 内存不足
1. 增加maxmemory限制
2. 调整maxmemory-policy
3. 清理不必要的键

## 生产环境建议

1. **持久化**: Session Redis必须开启持久化
2. **监控**: 监控内存使用和连接数
3. **备份**: 定期备份Session Redis数据
4. **集群**: 考虑Redis Cluster提高可用性
5. **安全**: 配置密码认证和网络访问控制

## 性能优化

1. **连接池**: 在应用中使用连接池
2. **pipeline**: 批量操作使用pipeline
3. **TTL设置**: 合理设置缓存过期时间
4. **内存优化**: 监控和优化内存使用

## 更多资源

- [Redis官方文档](https://redis.io/documentation)
- [Redis Streams文档](https://redis.io/topics/streams-intro)
- [Docker Compose文档](https://docs.docker.com/compose/)