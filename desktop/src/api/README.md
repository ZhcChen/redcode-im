# Bear Chat API 接口文档

本目录包含了 Bear Chat PC 客户端的所有 API 接口定义，从手机版 UniApp 项目移植而来，使用 TypeScript 重新实现。

## 目录结构

```
api/
├── config.ts           # API 配置文件
├── http.ts             # HTTP 请求工具类
├── system.ts           # 系统相关接口（登录、注册等）
├── user.ts             # 用户相关接口（用户信息、权限等）
├── friend.ts           # 好友管理接口
├── account.ts          # 账户记录接口
├── group.ts            # 群聊相关接口
├── message.ts          # 消息相关接口
├── friendCircle.ts     # 朋友圈相关接口
├── chatgpt.ts          # AI 聊天接口
├── music.ts            # 音乐相关接口
├── file.ts             # 文件管理接口
├── index.ts            # 统一导出文件
└── README.md           # 本文档
```

## 快速开始

### 1. 基础配置

在 `config.ts` 中配置 API 基础信息：

```typescript
import { apiConfig } from '@/api/config';

// 当前配置会自动根据环境选择对应的服务器地址
console.log(apiConfig.BASE_API); // 输出当前 API 基础地址
```

### 2. 使用方式

#### 方式一：直接导入 API 类

```typescript
import { SystemApi, UserApi, GroupApi } from '@/api';

// 用户登录
const loginResult = await SystemApi.login({
  username: 'testuser',
  password: '123456'
});

// 获取用户信息
const userInfo = await UserApi.getUserAccountInfo();

// 获取群聊列表
const groupList = await GroupApi.getMyChatGroupList();
```

#### 方式二：使用统一 API 对象

```typescript
import { api } from '@/api';

// 用户登录
const loginResult = await api.system.login({
  username: 'testuser',
  password: '123456'
});

// 获取用户信息
const userInfo = await api.user.getUserAccountInfo();

// 获取群聊列表
const groupList = await api.group.getMyChatGroupList();
```

#### 方式三：默认导入

```typescript
import api from '@/api';

const loginResult = await api.system.login({
  username: 'testuser',
  password: '123456'
});
```

## 主要功能模块

### 1. 系统模块 (SystemApi)

- **用户认证**：登录、注册、Token 登录
- **系统配置**：获取应用配置、版本检查
- **短信服务**：发送验证码、手机号验证

```typescript
// 用户登录
const result = await api.system.login({
  username: 'user@example.com',
  password: 'password123'
});

// 检查最新版本
const version = await api.system.getLatestVersion();
```

### 2. 用户模块 (UserApi)

- **用户信息**：获取、更新用户资料
- **权限管理**：检查、更新用户权限
- **密码管理**：修改登录密码、交易密码

```typescript
// 获取用户账户信息
const userInfo = await api.user.getUserAccountInfo();

// 更新用户信息
await api.user.updateUserInfo({
  nickname: '新昵称',
  signature: '个性签名'
});
```

### 3. 好友模块 (FriendApi)

- **好友管理**：添加、删除、搜索好友
- **好友申请**：发送、处理好友申请
- **黑名单**：拉黑、取消拉黑好友

```typescript
// 获取好友列表
const friends = await api.friend.getMyFriendList();

// 添加好友
await api.friend.addFriend({
  friendId: 'user123',
  message: '我是通过搜索添加的'
});
```

### 4. 群聊模块 (GroupApi)

- **群聊管理**：创建、解散、退出群聊
- **成员管理**：添加、删除群成员
- **红包转账**：发送、接收红包和转账

```typescript
// 创建群聊
await api.group.launchChatGroup({
  name: '我的群聊',
  memberIds: ['user1', 'user2', 'user3']
});

// 发送群红包
await api.group.redPacket.sendRedBagForGroup({
  groupId: 'group123',
  amount: 100,
  count: 5,
  message: '恭喜发财'
});
```

### 5. 消息模块 (MessageApi)

- **消息管理**：发送、撤回、删除消息
- **消息类型**：文本、图片、语音、视频、文件
- **消息查询**：获取聊天记录、搜索消息

```typescript
// 获取群聊消息
const messages = await api.message.getMessageListByChatGroupId({
  groupId: 'group123',
  page: 1,
  size: 20
});

// 撤回消息
await api.message.revertMsg({
  messageId: 'msg123',
  groupId: 'group123'
});
```

### 6. 朋友圈模块 (FriendCircleApi)

- **朋友圈管理**：发布、删除朋友圈
- **互动功能**：点赞、评论、回复
- **隐私设置**：设置可见范围

```typescript
// 发布朋友圈
await api.friendCircle.releaseFriendCircle({
  content: '今天天气真好！',
  images: ['image1.jpg', 'image2.jpg'],
  isPublic: true
});

// 点赞朋友圈
await api.friendCircle.clickThumb({
  circleId: 'circle123',
  isLike: true
});
```

### 7. AI 聊天模块 (ChatGptApi)

- **对话功能**：ChatGPT 对话、流式响应
- **图像生成**：文字转图片
- **会话管理**：保存、删除对话记录

```typescript
// ChatGPT 对话
const response = await api.chatgpt.chatGpt({
  message: '你好，请介绍一下自己',
  model: 'gpt-3.5-turbo'
});

// 生成图片
const images = await api.chatgpt.chatToImage({
  prompt: '一只可爱的小猫咪',
  size: '512x512'
});
```

### 8. 音乐模块 (MusicApi)

- **音乐搜索**：搜索歌曲、艺术家、专辑
- **音乐播放**：获取播放链接、歌词
- **音乐下载**：下载歌曲到本地

```typescript
// 搜索音乐
const musicList = await api.music.searchMusicList({
  keyword: '周杰伦',
  page: 1,
  size: 20
});

// 获取播放链接
const playInfo = await api.music.getSongSrc({
  musicId: 'music123',
  quality: 'high'
});
```

### 9. 文件模块 (FileApi)

- **文件上传**：单文件、批量上传
- **文件管理**：查看、删除、更新文件信息
- **图片处理**：压缩、生成缩略图

```typescript
// 上传文件
const uploadResult = await api.file.uploadFile({
  file: fileObject,
  category: 'chat_image',
  isPublic: false
});

// 批量上传
const batchResult = await api.file.uploadMultipleFiles(
  [file1, file2, file3],
  { category: 'chat_file' }
);
```

## 错误处理

所有 API 接口都返回统一的响应格式：

```typescript
interface ApiResponse<T = any> {
  code: number;        // 状态码
  message: string;     // 响应消息
  data: T;            // 响应数据
  success: boolean;   // 是否成功
}
```

使用示例：

```typescript
try {
  const result = await api.system.login({
    username: 'test',
    password: '123456'
  });
  
  if (result.success) {
    console.log('登录成功', result.data);
  } else {
    console.error('登录失败', result.message);
  }
} catch (error) {
  console.error('请求异常', error);
}
```

## 认证机制

系统使用 Token 认证，登录成功后会自动设置认证头：

```typescript
import { httpClient } from '@/api/http';

// 登录成功后设置 Token
const loginResult = await api.system.login({ username, password });
if (loginResult.success) {
  httpClient.setAuthToken(loginResult.data.token);
}

// 登出时移除 Token
httpClient.removeAuthToken();
```

## 环境配置

在 `config.ts` 中可以切换不同的环境配置：

```typescript
// 测试环境
const testConfig = { ... };

// 开发环境  
const devConfig = { ... };

// 生产环境
const prodConfig = { ... };

// 当前使用的配置
const currentConfig = prodConfig; // 修改这里切换环境
```

## 注意事项

1. **类型安全**：所有接口都有完整的 TypeScript 类型定义
2. **错误处理**：请务必处理 API 调用的异常情况
3. **认证状态**：需要认证的接口请确保已设置有效的 Token
4. **请求频率**：注意控制 API 请求频率，避免触发限流
5. **文件上传**：大文件上传建议使用分片上传或压缩后上传

## 新增功能

### 🔄 自动重试机制

支持网络错误、超时错误、5xx服务器错误的自动重试：

```typescript
// 使用默认重试配置（3次重试，间隔1秒）
const result = await api.system.login({ username, password });

// 自定义重试配置
const result = await httpClient.post('api/endpoint', data, {
  retryTimes: 5,    // 重试5次
  retryDelay: 2000, // 每次间隔2秒
  retry: true       // 启用重试（默认true）
});

// 禁用重试
const result = await httpClient.get('realtime/data', {
  retry: false
});
```

### 🎯 请求/响应拦截器

支持请求和响应的统一处理：

```typescript
import { addRequestInterceptor, addResponseInterceptor, addErrorInterceptor } from '@/api/http';

// 添加认证拦截器
addRequestInterceptor((config) => {
  const token = localStorage.getItem('token');
  return {
    ...config,
    headers: {
      ...config.headers,
      'Authorization': `Bearer ${token}`
    }
  };
});

// 添加响应处理拦截器
addResponseInterceptor((response) => {
  // 统一处理响应数据
  if (response.code === 401) {
    // 自动跳转登录页
    window.location.href = '/login';
  }
  return response;
});

// 添加错误处理拦截器
addErrorInterceptor((error) => {
  if (error.message.includes('HTTP 404')) {
    return new Error('请求的资源不存在');
  }
  return error;
});
```

### 🎛️ 拦截器管理

```typescript
import { clearInterceptors } from '@/api/http';

// 清除所有拦截器
clearInterceptors();
```

### 📝 自动日志记录

默认添加了请求日志拦截器，自动记录：
- 请求ID和时间戳
- 请求成功/失败状态
- 错误分类和友好提示

## 使用示例

详细的使用示例请参考：`src/api/examples/http-features-demo.ts`

## 更新日志

- **v1.1.0** - 新增拦截器系统和自动重试机制
- **v1.0.0** - 初始版本，完成所有基础 API 接口移植
- 后续版本更新请查看项目 CHANGELOG.md
