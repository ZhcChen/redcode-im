// RedCode IM API 数据定义
// 这个文件包含所有API的详细定义，后续新增API需要在这里添加

const API_DATA = {
    // 基础信息
    baseUrl: "http://localhost:8080",
    version: "1.0.0",
    lastUpdated: "2025-10-13",

    // 认证模块 APIs
    auth: [
        {
            id: "register",
            method: "POST",
            path: "/auth/register",
            title: "用户注册",
            description: "创建新的用户账户，包含用户名、邮箱和密码等信息。",
            authentication: false,
            requestBody: {
                contentType: "application/json",
                schema: {
                    type: "object",
                    required: ["username", "email", "password"],
                    properties: {
                        username: {
                            type: "string",
                            description: "用户名，长度至少3个字符",
                            minLength: 3,
                            example: "testuser"
                        },
                        email: {
                            type: "string",
                            format: "email",
                            description: "有效的邮箱地址",
                            example: "user@example.com"
                        },
                        password: {
                            type: "string",
                            description: "密码，长度至少6个字符",
                            minLength: 6,
                            example: "password123"
                        },
                        nickname: {
                            type: "string",
                            description: "用户昵称（可选）",
                            example: "测试用户"
                        }
                    }
                },
                example: {
                    username: "testuser",
                    email: "test@example.com",
                    password: "password123",
                    nickname: "测试用户"
                }
            },
            responses: [
                {
                    status: 200,
                    description: "注册成功",
                    example: {
                        id: "550e8400-e29b-41d4-a716-446655440000",
                        username: "testuser",
                        email: "test@example.com",
                        nickname: "测试用户",
                        avatar_url: null,
                        status: "active"
                    }
                },
                {
                    status: 400,
                    description: "请求参数错误",
                    example: {
                        error: "Username must be at least 3 characters"
                    }
                },
                {
                    status: 409,
                    description: "用户名或邮箱已存在",
                    example: {
                        error: "Username already exists"
                    }
                }
            ]
        },
        {
            id: "login",
            method: "POST",
            path: "/auth/login",
            title: "用户登录",
            description: "使用用户名和密码进行身份验证，成功后返回JWT token。",
            authentication: false,
            requestBody: {
                contentType: "application/json",
                schema: {
                    type: "object",
                    required: ["username", "password"],
                    properties: {
                        username: {
                            type: "string",
                            description: "用户名",
                            example: "testuser"
                        },
                        password: {
                            type: "string",
                            description: "密码",
                            example: "password123"
                        }
                    }
                },
                example: {
                    username: "testuser",
                    password: "password123"
                }
            },
            responses: [
                {
                    status: 200,
                    description: "登录成功",
                    example: {
                        token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                        user: {
                            id: "550e8400-e29b-41d4-a716-446655440000",
                            username: "testuser",
                            email: "test@example.com",
                            nickname: "测试用户",
                            avatar_url: null,
                            status: "active"
                        }
                    }
                },
                {
                    status: 401,
                    description: "用户名或密码错误",
                    example: {
                        error: "Invalid username or password"
                    }
                }
            ]
        },
        {
            id: "me",
            method: "GET",
            path: "/auth/me",
            title: "获取当前用户信息",
            description: "获取当前登录用户的详细信息，需要提供有效的JWT token。",
            authentication: true,
            requestBody: null,
            responses: [
                {
                    status: 200,
                    description: "成功获取用户信息",
                    example: {
                        id: "550e8400-e29b-41d4-a716-446655440000",
                        username: "testuser",
                        email: "test@example.com",
                        nickname: "测试用户",
                        avatar_url: null,
                        status: "active"
                    }
                },
                {
                    status: 401,
                    description: "未授权访问",
                    example: {
                        error: "Unauthorized"
                    }
                }
            ]
        }
    ],

    // 系统模块 APIs
    system: [
        {
            id: "health",
            method: "GET",
            path: "/healthz",
            title: "健康检查",
            description: "检查服务器运行状态，用于负载均衡器和监控系统的健康检查。",
            authentication: false,
            requestBody: null,
            responses: [
                {
                    status: 200,
                    description: "服务器运行正常",
                    example: "ok"
                }
            ]
        },
        {
            id: "root",
            method: "GET",
            path: "/",
            title: "根路径",
            description: "获取API基础信息。",
            authentication: false,
            requestBody: null,
            responses: [
                {
                    status: 200,
                    description: "成功获取基础信息",
                    example: "redcode IM backend"
                }
            ]
        }
    ],

    // WebSocket APIs
    websocket: [
        {
            id: "ws-connection",
            method: "WebSocket",
            path: "/ws",
            title: "WebSocket 连接",
            description: "建立WebSocket连接用于实时消息传递，当前支持echo模式（消息回显）。",
            authentication: false,
            requestBody: null,
            responses: [
                {
                    status: 101,
                    description: "WebSocket连接建立成功",
                    example: {
                        connection: "WebSocket upgraded",
                        behavior: "Echo mode - messages are sent back"
                    }
                }
            ],
            messageTypes: [
                {
                    type: "Text",
                    description: "文本消息",
                    example: "Hello World!"
                },
                {
                    type: "Binary",
                    description: "二进制消息",
                    example: "Binary data"
                },
                {
                    type: "Ping/Pong",
                    description: "心跳检测",
                    example: "WebSocket ping/pong"
                }
            ]
        }
    ],

    // 消息模块 APIs
    messages: [
        {
            id: "sendMessage",
            method: "POST",
            path: "/rooms/:room_id/messages",
            title: "发送消息",
            description: "向指定房间发送消息。需要认证。可选 message_type: text/image/file/system（默认 text）。",
            authentication: true,
            requestBody: {
                contentType: "application/json",
                schema: {
                    type: "object",
                    required: ["content"],
                    properties: {
                        content: {
                            type: "string",
                            description: "消息内容",
                            example: "大家好"
                        },
                        message_type: {
                            type: "string",
                            description: "消息类型，可选 text/image/file/system",
                            example: "text"
                        }
                    }
                },
                example: {
                    content: "大家好",
                    message_type: "text"
                }
            },
            responses: [
                {
                    status: 200,
                    description: "发送成功，返回消息对象",
                    example: {
                        id: "550e8400-e29b-41d4-a716-446655440000",
                        room_id: "11111111-2222-3333-4444-555555555555",
                        sender_id: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
                        content: "大家好",
                        message_type: "text",
                        created_at: "2024-10-10T10:00:00Z",
                        updated_at: "2024-10-10T10:00:00Z"
                    }
                },
                { status: 401, description: "未授权", example: { error: "Unauthorized" } },
                { status: 403, description: "非房间成员禁止发送", example: { error: "Not a room member" } }
            ]
        },
        {
            id: "listMessages",
            method: "GET",
            path: "/rooms/:room_id/messages?limit=50",
            title: "获取消息列表",
            description: "按时间倒序获取房间最近消息。支持查询参数 limit(1-200)，默认50。需要认证。",
            authentication: true,
            requestBody: null,
            responses: [
                {
                    status: 200,
                    description: "获取成功，返回消息数组（倒序）",
                    example: [
                        {
                            id: "550e8400-e29b-41d4-a716-446655440000",
                            room_id: "11111111-2222-3333-4444-555555555555",
                            sender_id: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
                            content: "大家好",
                            message_type: "text",
                            created_at: "2024-10-10T10:00:00Z",
                            updated_at: "2024-10-10T10:00:00Z"
                        }
                    ]
                },
                { status: 401, description: "未授权", example: { error: "Unauthorized" } },
                { status: 403, description: "非房间成员禁止访问", example: { error: "Not a room member" } }
            ]
        }
    ]
};

// 导出API数据供其他脚本使用
if (typeof module !== 'undefined' && module.exports) {
    module.exports = API_DATA;
} else {
    window.API_DATA = API_DATA;
}