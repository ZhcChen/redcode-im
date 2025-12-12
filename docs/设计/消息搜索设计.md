# 消息搜索功能设计文档

## 概述

RedCode IM 实现了混合搜索架构，结合本地搜索和服务器搜索的优势，为用户提供高效、便捷的消息搜索体验。

## 架构设计

### 1. 混合搜索策略

**本地搜索（SQLite + FTS5）**
- ✅ 实时搜索，无延迟
- ✅ 离线可用
- ✅ 减轻服务器压力
- ✅ 支持复杂搜索语法（FTS5全文搜索）
- ⚠️ 只能搜索已加载的消息

**服务器搜索**
- ✅ 搜索完整历史记录
- ✅ 跨设备同步
- ✅ 支持高级过滤
- ⚠️ 需要网络连接
- ⚠️ 产生服务器压力

### 2. 搜索流程

```
用户输入搜索 → 本地FTS5搜索 → 显示本地结果
              ↓
           如果需要更多 → 服务器搜索 → 合并结果
```

## 功能特性

### 1. 搜索语法支持

#### 基础搜索
- **关键词搜索**: `关键词` - 搜索包含特定词语的消息
- **多词搜索**: `词1 词2` - 搜索同时包含多个词语的消息
- **短语搜索**: `"完整短语"` - 搜索包含完整短语的消息

#### 高级搜索
- **AND 操作符**: `词1 AND 词2` - 搜索同时包含两个词语的消息
- **OR 操作符**: `词1 OR 词2` - 搜索包含任一词语的消息
- **NOT 操作符**: `词1 NOT 词2` - 排除包含特定词语的消息
- **前缀搜索**: `词*` - 搜索以指定词开头的内容
- **组合搜索**: `"短语" AND (词1 OR 词2)`

### 2. 搜索过滤器

- **房间过滤**: 指定特定房间的消息
- **发送者过滤**: 指定特定用户的消息
- **消息类型过滤**: 文本、图片、文件、视频、语音
- **日期范围过滤**: 指定时间范围内的消息
- **分页支持**: 支持分页加载结果

### 3. 搜索结果

- **相关性评分**: 根据匹配程度排序
- **高亮显示**: 匹配关键词高亮
- **上下文片段**: 显示匹配片段及上下文
- **快速定位**: 点击结果自动跳转到消息
- **结果统计**: 显示搜索耗时和结果数量

## 实现细节

### 1. 本地搜索实现

#### FTS5 表结构
```sql
CREATE VIRTUAL TABLE message_search USING fts5(
    id UNINDEXED,
    room_id UNINDEXED,
    room_name,
    sender_id UNINDEXED,
    sender_name,
    content,
    message_type UNINDEXED,
    timestamp UNINDEXED
);
```

#### 索引机制
- **自动索引**: 使用触发器自动同步消息表
- **批量索引**: 初始化时批量索引已有消息
- **异步索引**: 新消息异步索引，不阻塞UI

#### 查询示例
```sql
SELECT
    id, room_id, room_name, sender_id, sender_name,
    snippet(message_search, 5, '<mark>', '</mark>', '...', 20) as matched_text,
    content, message_type, timestamp,
    bm25(message_search) as relevance_score
FROM message_search
WHERE message_search MATCH '"关键词"*'
ORDER BY relevance_score, timestamp DESC
LIMIT 50
```

### 2. 服务器搜索实现

#### 数据库查询
```sql
SELECT
    m.id, m.room_id, r.name as room_name,
    m.sender_id, u.username, u.nickname,
    m.content, m.message_type, m.created_at,
    CASE
        WHEN m.content ILIKE $1 THEN 1.0
        WHEN u.username ILIKE $1 OR u.nickname ILIKE $1 THEN 0.8
        ELSE 0.5
    END as relevance_score
FROM messages m
JOIN users u ON m.sender_id = u.id
JOIN rooms r ON m.room_id = r.id
WHERE m.deleted_at IS NULL
  AND (m.content ILIKE $1 OR u.username ILIKE $1 OR u.nickname ILIKE $1)
ORDER BY relevance_score DESC, m.created_at DESC
LIMIT 50
```

#### 搜索建议
- **前缀匹配**: 基于历史消息提供自动补全
- **热门关键词**: 显示近期热门搜索词
- **用户行为学习**: 根据用户搜索习惯优化建议

## API 设计

### 1. 本地搜索 API

#### 索引消息
```rust
// 索引单个消息
async fn index_message(message: IndexMessage) -> Result<(), String>

// 批量索引消息
async fn index_messages(messages: Vec<IndexMessage>) -> Result<(), String>
```

#### 搜索消息
```rust
async fn search_messages(
    params: SearchParams
) -> Result<(Vec<MessageSearchResult>, SearchStats), String>
```

#### 搜索建议
```rust
async fn get_search_suggestions(
    prefix: String,
    limit: Option<i32>
) -> Result<Vec<String>, String>
```

### 2. 服务器搜索 API

#### 搜索消息
```
GET /messages/search
Query:
  - query: 搜索关键词
  - room_id: 房间ID（可选）
  - sender_id: 发送者ID（可选）
  - message_type: 消息类型（可选）
  - date_from: 开始时间戳（可选）
  - date_to: 结束时间戳（可选）
  - limit: 限制数量（默认50，最大100）
  - offset: 偏移量（用于分页）
```

#### 获取搜索建议
```
GET /messages/search/suggestions
Query:
  - prefix: 前缀
  - limit: 限制数量（默认10，最大20）
```

#### 获取热门关键词
```
GET /messages/search/trending
```

## 前端实现

### 1. 搜索组件

#### MessageSearch.vue
- 搜索输入框
- 搜索建议
- 过滤器面板
- 搜索结果展示
- 分页加载

#### SearchDialog.vue
- 搜索对话框
- 模态窗口
- 结果导航

### 2. 搜索服务

#### MessageSearchService
- 单例模式
- 消息索引管理
- 异步索引队列
- 批量索引优化

### 3. 搜索集成

#### Chat.vue 集成
- 消息加载时自动索引
- WebSocket消息实时索引
- 搜索结果快速定位
- 搜索高亮效果

## 性能优化

### 1. 本地搜索优化

- **分批索引**: 避免一次性索引大量消息
- **异步处理**: 索引操作不阻塞主线程
- **数据库优化**: WAL模式，适当的缓存大小
- **定期维护**: 定期优化FTS5索引

### 2. 服务器搜索优化

- **索引优化**: 适当的数据库索引
- **查询优化**: 减少N+1查询
- **缓存策略**: 缓存热门搜索结果
- **分页加载**: 避免一次加载过多数据

### 3. 内存管理

- **索引大小控制**: 限制本地索引的消息数量
- **LRU淘汰**: 最近最少使用策略
- **压缩存储**: 合理的数据结构

## 使用示例

### 1. 基础搜索

```typescript
// 搜索消息
const params = {
  query: "你好",
  limit: 50
};
const [results, stats] = await SearchApi.searchMessages(params);

// 显示结果
results.forEach(result => {
  console.log(`[${result.roomName}] ${result.senderName}: ${result.content}`);
});
```

### 2. 高级搜索

```typescript
// 搜索特定房间的消息
const params = {
  query: "重要 AND 会议",
  roomId: "room-123",
  dateFrom: Date.now() - 7 * 24 * 60 * 60 * 1000, // 最近7天
  limit: 30
};
const [results] = await SearchApi.searchMessages(params);
```

### 3. 搜索建议

```typescript
// 获取搜索建议
const suggestions = await SearchApi.getSearchSuggestions("项目", 10);
console.log("建议:", suggestions);
// 输出: ["项目进度", "项目计划", "项目文档", ...]
```

## 最佳实践

### 1. 搜索体验

- **输入提示**: 提供实时搜索建议
- **快速响应**: 本地搜索 < 100ms
- **智能排序**: 按相关性排序
- **高亮显示**: 匹配内容高亮

### 2. 数据管理

- **增量索引**: 只索引新消息
- **定期清理**: 删除过期索引
- **备份索引**: 重要索引定期备份
- **版本兼容**: 索引格式版本管理

### 3. 错误处理

- **索引失败**: 重试机制
- **搜索超时**: 降级策略
- **数据一致性**: 定期检查索引
- **用户反馈**: 搜索失败的友好提示

## 监控与统计

### 1. 搜索统计

- **搜索频率**: 每天搜索次数
- **热门查询**: 最常见的搜索词
- **无结果查询**: 搜索失败统计
- **响应时间**: 搜索性能监控

### 2. 索引统计

- **索引大小**: 索引占用的磁盘空间
- **索引速度**: 索引性能
- **索引完整性**: 索引与实际数据的一致性
- **内存使用**: 索引占用的内存

## 未来规划

### 1. 功能增强

- **智能搜索**: AI驱动的语义搜索
- **图片搜索**: 搜索图片内容
- **语音搜索**: 搜索语音消息
- **多语言支持**: 多语言搜索

### 2. 性能提升

- **分布式搜索**: 多节点分布式搜索
- **增量同步**: 索引增量同步
- **预加载**: 智能预加载搜索结果
- **压缩优化**: 更高效的索引压缩

### 3. 用户体验

- **搜索历史**: 保存搜索历史
- **收藏搜索**: 收藏常用搜索
- **搜索模板**: 预设搜索模板
- **语音输入**: 语音搜索

## 总结

RedCode IM 的消息搜索功能采用了混合架构，结合了本地搜索的快速响应和服务器搜索的全面性。通过 FTS5 全文搜索、实时索引和智能排序，为用户提供了优秀的搜索体验。

主要优势：
1. **性能优异**: 本地搜索无延迟
2. **功能完整**: 支持复杂搜索语法
3. **可扩展性**: 支持服务器端扩展
4. **用户友好**: 直观的搜索界面
5. **智能优化**: 自动索引和性能优化

该系统具有良好的可维护性和扩展性，能够满足不同规模用户的需求。
