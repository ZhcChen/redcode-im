// RedCode IM API 数据定义
// 这个文件包含所有API的详细定义，后续新增API需要在这里添加

const API_DATA = {
    // 基础信息
    baseUrl: "http://localhost:8010",
    version: "1.0.0",
    lastUpdated: "2025-10-21",

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
            id: "send_sms",
            method: "POST",
            path: "/auth/sms/send",
            title: "发送登录验证码",
            description: "向指定手机号发送一次性登录验证码，验证码有效期5分钟。",
            authentication: false,
            requestBody: {
                contentType: "application/json",
                schema: {
                    type: "object",
                    required: ["phone"],
                    properties: {
                        phone: {
                            type: "string",
                            description: "用户手机号，建议使用 E.164 格式",
                            example: "13800138000"
                        }
                    }
                },
                example: {
                    phone: "13800138000"
                }
            },
            responses: [
                {
                    status: 200,
                    description: "验证码发送成功",
                    example: {
                        success: true,
                        message: "验证码已发送"
                    }
                },
                {
                    status: 400,
                    description: "请求参数错误",
                    example: {
                        error: "手机号不能为空"
                    }
                }
            ]
        },
        {
            id: "login_sms",
            method: "POST",
            path: "/auth/login/sms",
            title: "验证码登录",
            description: "使用手机号和验证码完成无密码登录，验证码需通过发送接口获取。",
            authentication: false,
            requestBody: {
                contentType: "application/json",
                schema: {
                    type: "object",
                    required: ["phone", "code"],
                    properties: {
                        phone: {
                            type: "string",
                            description: "用户手机号",
                            example: "13800138000"
                        },
                        code: {
                            type: "string",
                            description: "6位数字验证码",
                            example: "123456"
                        }
                    }
                },
                example: {
                    phone: "13800138000",
                    code: "123456"
                }
            },
            responses: [
                {
                    status: 200,
                    description: "登录成功",
                    example: {
                        token: "eyJhbGciOiJIUzI1NiIs...",
                        user: {
                            id: "550e8400-e29b-41d4-a716-446655440000",
                            username: "13800138000",
                            email: "user@example.com",
                            nickname: "测试用户",
                            avatar_url: null,
                            status: "active"
                        }
                    }
                },
                {
                    status: 400,
                    description: "验证码错误或已过期",
                    example: {
                        error: "验证码错误或已过期"
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
            description: "建立WebSocket连接用于实时消息传递。支持认证、加入房间、消息推送与好友请求红点更新等事件。",
            authentication: false,
            requestBody: null,
            responses: [
                {
                    status: 101,
                    description: "WebSocket连接建立成功",
                    example: {
                        connection: "WebSocket upgraded",
                        behavior: "事件驱动 - 认证/加入/消息推送/心跳"
                    }
                }
            ],
            messageTypes: [
                {
                    type: "auth",
                    description: "客户端发送：{ type: 'auth', token: '<JWT>' }；服务端返回 authed。",
                    example: '{"type":"authed","user_id":"<uuid>","conn_id":"<string>"}'
                },
                {
                    type: "join",
                    description: "客户端发送：{ type: 'join', room_id: '<uuid>' } 加入房间。",
                    example: '{"type":"joined","room_id":"<uuid>"}'
                },
                {
                    type: "message",
                    description: "服务端推送新消息。",
                    example: '{"type":"message","id":"<uuid>","room_id":"<uuid>","sender_id":"<uuid>","sender_username":"alice","sender_nickname":"Alice","content":"你好","message_type":"text","timestamp":"2025-10-20T10:10:00Z"}'
                },
                {
                    type: "friend_request_update",
                    description: "服务端推送新的待处理好友请求数量。",
                    example: '{"type":"friend_request_update","pending_count":2}'
                },
                {
                    type: "pong",
                    description: "心跳响应。客户端定期发送 { type: 'ping' }。",
                    example: '{"type":"pong"}'
                },
                {
                    type: "error",
                    description: "错误信息。",
                    example: '{"type":"error","message":"unauthorized"}'
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
    ],

    // 会话模块 APIs
    chats: [
        {
            id: "listChats",
            method: "GET",
            path: "/chats",
            title: "获取会话列表",
            description: "返回当前用户的会话概要列表（含未读数和最后一条消息预览）。",
            authentication: true,
            requestBody: null,
            responses: [
                {
                    status: 200,
                    description: "成功，返回 ChatSummary 数组",
                    example: [
                        {
                            room_id: "8b2d5f33-1a6a-4c8a-9c2e-1c7b7fc6e5a1",
                            name: "Alice · Bob",
                            room_type: "private",
                            avatar_url: null,
                            description: null,
                            unread_count: 3,
                            last_read_message_id: "1f9d2a9e-9b82-4c3f-9b60-f0c4a7f7b1c2",
                            last_read_at: "2025-10-20T10:15:20Z",
                            last_message: {
                                id: "a3f9a9f1-2d34-45e2-9a3b-9c7e2f1d2a3b",
                                content: "你好",
                                message_type: "text",
                                created_at: "2025-10-20T10:10:00Z",
                                sender_id: "e1b2c3d4-5f67-8901-2345-67890abcde01",
                                sender_username: "alice",
                                sender_nickname: "Alice 昵称"
                            }
                        }
                    ]
                },
                { status: 401, description: "未授权", example: { error: "Unauthorized" } }
            ]
        }
    ],

    // 好友模块 APIs
    friends: [
        {
            id: "listFriendRequests",
            method: "GET",
            path: "/friends/requests?direction=incoming&status=pending",
            title: "获取好友请求列表",
            description: "按方向与状态筛选好友请求。direction: incoming|outgoing；status: pending|accepted|declined。",
            authentication: true,
            requestBody: null,
            responses: [
                {
                    status: 200,
                    description: "成功，返回 FriendRequestInfo 数组",
                    example: [
                        {
                            id: "3c6f0a9b-1d2e-4f6a-9a7b-2c4d5e6f7a8b",
                            requester: {
                                id: "e1b2c3d4-5f67-8901-2345-67890abcde01",
                                username: "alice",
                                email: "alice@example.com",
                                nickname: "Alice",
                                avatar_url: null,
                                status: "active"
                            },
                            addressee: {
                                id: "f2c3d4e5-6f78-9012-3456-7890abcdef12",
                                username: "bob",
                                email: "bob@example.com",
                                nickname: "Bob",
                                avatar_url: null,
                                status: "active"
                            },
                            status: "pending",
                            message: "你好，加个好友～",
                            created_at: "2025-10-20T10:00:00Z",
                            responded_at: null,
                            is_incoming: true
                        }
                    ]
                },
                { status: 401, description: "未授权", example: { error: "Unauthorized" } }
            ]
        },
        {
            id: "createFriendRequest",
            method: "POST",
            path: "/friends/requests",
            title: "创建好友请求",
            description: "向目标用户发送好友请求，可附带一段打招呼内容。",
            authentication: true,
            requestBody: {
                contentType: "application/json",
                schema: {
                    type: "object",
                    required: ["target_user_id"],
                    properties: {
                        target_user_id: {
                            type: "string",
                            description: "目标用户ID (UUID)",
                            example: "f2c3d4e5-6f78-9012-3456-7890abcdef12"
                        },
                        message: {
                            type: "string",
                            description: "打招呼内容（可选）",
                            example: "你好，我们同事，方便加个好友吗？"
                        }
                    }
                },
                example: {
                    target_user_id: "f2c3d4e5-6f78-9012-3456-7890abcdef12",
                    message: "你好，我们同事，方便加个好友吗？"
                }
            },
            responses: [
                {
                    status: 200,
                    description: "成功，返回创建的请求",
                    example: {
                        id: "3c6f0a9b-1d2e-4f6a-9a7b-2c4d5e6f7a8b",
                        requester: {
                            id: "e1b2c3d4-5f67-8901-2345-67890abcde01",
                            username: "alice",
                            email: "alice@example.com",
                            nickname: "Alice",
                            avatar_url: null,
                            status: "active"
                        },
                        addressee: {
                            id: "f2c3d4e5-6f78-9012-3456-7890abcdef12",
                            username: "bob",
                            email: "bob@example.com",
                            nickname: "Bob",
                            avatar_url: null,
                            status: "active"
                        },
                        status: "pending",
                        message: "你好，我们同事，方便加个好友吗？",
                        created_at: "2025-10-20T10:00:00Z",
                        responded_at: null,
                        is_incoming: false
                    }
                },
                { status: 401, description: "未授权", example: { error: "Unauthorized" } },
                { status: 404, description: "目标用户不存在", example: { error: "Not Found" } }
            ]
        },
        {
            id: "respondFriendRequest",
            method: "POST",
            path: "/friends/requests/:request_id/respond",
            title: "响应好友请求",
            description: "同意或拒绝好友请求。action: accept|decline。",
            authentication: true,
            requestBody: {
                contentType: "application/json",
                schema: {
                    type: "object",
                    required: ["action"],
                    properties: {
                        action: {
                            type: "string",
                            description: "响应动作：accept 或 decline",
                            example: "accept"
                        }
                    }
                },
                example: {
                    action: "accept"
                }
            },
            responses: [
                {
                    status: 200,
                    description: "成功，返回更新后的请求信息",
                    example: {
                        id: "3c6f0a9b-1d2e-4f6a-9a7b-2c4d5e6f7a8b",
                        requester: {
                            id: "e1b2c3d4-5f67-8901-2345-67890abcde01",
                            username: "alice",
                            email: "alice@example.com",
                            nickname: "Alice",
                            avatar_url: null,
                            status: "active"
                        },
                        addressee: {
                            id: "f2c3d4e5-6f78-9012-3456-7890abcdef12",
                            username: "bob",
                            email: "bob@example.com",
                            nickname: "Bob",
                            avatar_url: null,
                            status: "active"
                        },
                        status: "accepted",
                        message: "你好，我们同事，方便加个好友吗？",
                        created_at: "2025-10-20T10:00:00Z",
                        responded_at: "2025-10-20T10:05:00Z",
                        is_incoming: true
                    }
                },
                { status: 401, description: "未授权", example: { error: "Unauthorized" } },
                { status: 404, description: "请求不存在", example: { error: "Not Found" } }
            ]
        },
        {
            id: "ensurePrivateChat",
            method: "POST",
            path: "/friends/:friend_user_id/chat",
            title: "确保与好友的单聊房间存在",
            description: "若不存在则创建，返回房间与对方信息。",
            authentication: true,
            requestBody: null,
            responses: [
                {
                    status: 200,
                    description: "成功返回房间信息",
                    example: {
                        room_id: "8b2d5f33-1a6a-4c8a-9c2e-1c7b7fc6e5a1",
                        room_name: "Alice · Bob",
                        room_type: "private",
                        friend_id: "e2b3c4d5-6f78-9012-3456-7890abcdef12",
                        friend_name: "Bob 昵称",
                        friend_avatar: "https://example.com/avatar/bob.png"
                    }
                },
                { status: 401, description: "未授权", example: { error: "Unauthorized" } },
                { status: 404, description: "好友不存在或已停用", example: { error: "Not Found" } }
            ]
        }
    ]
    ,

    // 字段说明 / 模型定义（只读信息）
    models: [
        {
            id: "models-overview",
            method: "INFO",
            path: "",
            title: "字段说明 / 模型定义",
            description: "本项目主要数据模型与枚举说明，便于前后端对齐。",
            authentication: false,
            requestBody: null,
            responses: [
                {
                    status: 200,
                    description: "模型与枚举",
                    example: {
                        enums: {
                            RoomType: ["private", "group", "public"],
                            MessageType: ["text", "image", "file", "system"],
                            FriendRequestStatus: ["pending", "accepted", "declined"]
                        },
                        models: {
                            UserInfo: {
                                id: "string(uuid)",
                                username: "string",
                                email: "string(email)",
                                nickname: "string|null",
                                avatar_url: "string|null",
                                status: "active|inactive|banned"
                            },
                            ChatMessagePreview: {
                                id: "string(uuid)",
                                content: "string",
                                message_type: "MessageType",
                                created_at: "string(ISO8601)",
                                sender_id: "string(uuid)",
                                sender_username: "string",
                                sender_nickname: "string|null"
                            },
                            ChatSummary: {
                                room_id: "string(uuid)",
                                name: "string",
                                room_type: "RoomType",
                                avatar_url: "string|null",
                                description: "string|null",
                                unread_count: "number",
                                last_read_message_id: "string(uuid)|null",
                                last_read_at: "string(ISO8601)|null",
                                last_message: "ChatMessagePreview|null"
                            },
                            MessageInfo: {
                                id: "string(uuid)",
                                room_id: "string(uuid)",
                                sender_id: "string(uuid)",
                                sender_username: "string",
                                sender_nickname: "string|null",
                                sender_avatar_url: "string|null",
                                content: "string",
                                message_type: "MessageType",
                                created_at: "string(ISO8601)"
                            },
                            FriendRequestInfo: {
                                id: "string(uuid)",
                                requester: "UserInfo",
                                addressee: "UserInfo",
                                status: "FriendRequestStatus",
                                message: "string|null",
                                created_at: "string(ISO8601)",
                                responded_at: "string(ISO8601)|null",
                                is_incoming: "boolean"
                            },
                            EnsureChatResponse: {
                                room_id: "string(uuid)",
                                room_name: "string",
                                room_type: "RoomType",
                                friend_id: "string(uuid)",
                                friend_name: "string",
                                friend_avatar: "string|null"
                            }
                        }
                    }
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
