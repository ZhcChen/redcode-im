// RedCode IM API 数据定义
// 这个文件包含所有API的详细定义，后续新增API需要在这里添加

const API_DATA = {
    // 基础信息
    baseUrl: "http://localhost:8080",
    version: "1.0.0",
    lastUpdated: "2024-10-09",

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
    ]
};

// 导出API数据供其他脚本使用
if (typeof module !== 'undefined' && module.exports) {
    module.exports = API_DATA;
} else {
    window.API_DATA = API_DATA;
}