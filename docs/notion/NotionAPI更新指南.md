# Notion API 文档批量更新指南

## ✅ 已完成

1. **数据库结构已更新** - 添加了两个新字段:
   - `请求参数` - 存储 API 请求参数的 JSON 格式说明
   - `响应示例` - 存储 API 响应数据的 JSON 格式示例

2. **示例 API 已更新** - 以下 API 已添加完整的请求参数和响应示例:
   - ✅ 用户注册 (POST /auth/register)
   - ✅ 用户登录 (POST /auth/login)
   - ✅ 发送消息 (POST /rooms/:room_id/messages)

## 📋 数据源

详细的 API 参数信息位于: `/Users/chen/code/redcode-im/docs/API.md`

该文档包含了所有 API 的:
- 请求参数 (Request Parameters)
- 响应示例 (Response Examples)
- 查询参数 (Query Parameters)

## 🔄 批量更新方案

由于有 60+ 个 API 需要更新,建议采用以下方式之一:

### 方案 A: 手动在 Notion 中更新 (推荐给重要 API)
1. 打开 Notion 数据库
2. 找到对应的 API 记录
3. 从 `API.md` 文档中复制对应的请求参数和响应示例
4. 粘贴到相应字段中

**优先更新的核心 API**:
- 认证相关 (注册、登录、获取用户信息等)
- 消息相关 (发送、获取、删除消息等)
- 房间/群组管理 (创建、加入、成员管理等)

### 方案 B: 使用 Notion API 批量更新
如果需要批量更新所有 API,可以:
1. 从 `API.md` 提取所有 API 的详细信息
2. 创建一个 JSON 映射文件
3. 使用脚本调用 Notion API 批量更新

## 📝 更新模板

当手动更新时,使用以下格式:

### 请求参数格式
```json
{
  "param1": "type",  // 参数说明
  "param2": "type"   // 参数说明，可选
}
```

### 响应示例格式
```json
{
  "success": true,
  "code": 200,
  "message": "操作成功",
  "data": {
    // 返回数据
  }
}
```

## 🎯 API 优先级建议

### 高优先级 (建议立即更新)
- ✅ 用户注册
- ✅ 用户登录
- ✅ 发送消息
- 获取消息列表
- 创建房间
- 加入房间
- 好友请求相关

### 中优先级
- 用户信息更新
- 消息已读
- 文件上传
- 群组管理

### 低优先级
- 管理后台 API
- 系统监控 API
- 测试相关 API

## 💡 小贴士

1. **格式保持一致**: 确保所有 JSON 格式的代码块都使用换行和缩进
2. **注释清晰**: 在参数后面添加注释说明其用途和是否必填
3. **完整性**: 尽量包含所有可能的参数和响应字段
4. **实际示例**: 使用实际的数据示例而不是占位符

## 📊 当前进度

- **数据库结构**: ✅ 完成
- **示例 API**: ✅ 3个已完成
- **待更新 API**: 约 57个

## 🔗 相关资源

- Notion 数据库 ID: `2a4f81d1-d74f-8065-9d42-c47c70c56040`
- API 详细文档: `/Users/chen/code/redcode-im/docs/API.md`
- API 简要参考: `/Users/chen/code/redcode-im/docs/API_REFERENCE.md`
