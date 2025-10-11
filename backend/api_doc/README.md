# RedCode IM API 文档

## 概述

这是一个美观、现代化的API文档系统，用于展示RedCode IM后端项目的所有API接口。

## 文件结构

```
api_doc/
├── index.html        # 主文档页面
├── styles.css        # 样式文件
├── app.js           # 应用主脚本
├── api-data.js      # API数据定义
└── README.md        # 说明文档
```

## 功能特性

### 🎨 界面特性
- **现代化设计**: 采用简洁美观的UI设计
- **响应式布局**: 支持桌面和移动设备
- **交互式导航**: 侧边栏快速导航
- **搜索功能**: 实时搜索API接口
- **代码高亮**: 支持JSON代码高亮显示
- **复制功能**: 一键复制示例代码

### 📚 文档特性
- **完整API信息**: 包含请求参数、响应格式、认证要求等
- **示例代码**: 提供完整的请求/响应示例
- **参数表格**: 清晰展示所有参数信息
- **状态标识**: 明确标识API状态和认证要求

## 使用方法

### 1. 直接打开文档
在浏览器中打开 `index.html` 文件即可查看完整的API文档。

### 2. 本地服务器访问
```bash
# 在backend目录下启动服务器
cargo run

# 然后在浏览器中访问
open http://localhost:8080
# 并打开 api_doc/index.html
```

## 添加新API

当开发新的API接口时，请按照以下步骤更新文档：

### 1. 更新 `api-data.js`
在对应的模块中添加新的API定义：

```javascript
// 示例：添加新的用户API
{
    id: "update-profile",
    method: "PUT",
    path: "/user/profile",
    title: "更新用户资料",
    description: "更新当前登录用户的个人信息。",
    authentication: true,
    requestBody: {
        // 请求体定义
    },
    responses: [
        // 响应定义
    ]
}
```

### 2. API字段说明

- `id`: API唯一标识符
- `method`: HTTP方法 (GET, POST, PUT, DELETE等)
- `path`: API路径
- `title`: API标题（中文）
- `description`: API详细描述
- `authentication`: 是否需要认证 (true/false)
- `requestBody`: 请求体定义（可选）
- `responses`: 响应定义数组

### 3. 请求体定义格式
```javascript
requestBody: {
    contentType: "application/json",
    schema: {
        type: "object",
        required: ["field1", "field2"],
        properties: {
            field1: {
                type: "string",
                description: "字段描述",
                example: "示例值"
            }
        }
    },
    example: {
        field1: "示例值",
        field2: "示例值2"
    }
}
```

### 4. 响应定义格式
```javascript
responses: [
    {
        status: 200,
        description: "成功响应",
        example: {
            success: true,
            data: {}
        }
    },
    {
        status: 400,
        description: "错误响应",
        example: {
            error: "错误信息"
        }
    }
]
```

## 自定义样式

可以通过修改 `styles.css` 来自定义文档的外观：

### 主要颜色变量
```css
:root {
    --primary-color: #2563eb;      /* 主色调 */
    --success-color: #10b981;      /* 成功色 */
    --warning-color: #f59e0b;      /* 警告色 */
    --danger-color: #ef4444;       /* 错误色 */
}
```

### 字体设置
```css
body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
}
```

## 浏览器支持

- Chrome 60+
- Firefox 60+
- Safari 12+
- Edge 79+

## 快捷键

- `Ctrl/Cmd + K`: 聚焦搜索框
- `ESC`: 清空搜索并失焦

## 维护说明

1. **每次API更新后**: 及时更新 `api-data.js` 中的对应API定义
2. **定期检查**: 确保文档中的示例代码与实际API保持一致
3. **版本管理**: 更新文档版本号和更新日期
4. **测试验证**: 定期测试文档中的示例是否可以正常工作

## 技术栈

- **HTML5**: 语义化标签
- **CSS3**: 现代样式特性
- **JavaScript ES6+**: 模块化开发
- **Font Awesome**: 图标库
- **Prism.js**: 代码高亮

## 许可证

本API文档系统遵循项目的整体许可证。