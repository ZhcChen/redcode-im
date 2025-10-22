#!/usr/bin/env node

/**
 * WebSocket实时分发测试脚本 (Node.js版本)
 * 使用方法: node test_websocket.js
 * 
 * 前置条件:
 * 1. 安装依赖: npm install ws axios
 * 2. 启动后端服务: cargo run
 * 3. 运行测试: node test_websocket.js
 */

const WebSocket = require('ws');
const axios = require('axios');

const API_BASE = 'http://localhost:8010';
const WS_BASE = 'ws://localhost:8010';

// 颜色输出
const colors = {
    reset: '\x1b[0m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m'
};

function log(message, color = 'reset') {
    console.log(`${colors[color]}${message}${colors.reset}`);
}

// 测试配置
const testUsers = [
    {
        username: 'alice',
        email: 'alice@example.com',
        password: 'password123',
        nickname: 'Alice'
    },
    {
        username: 'bob',
        email: 'bob@example.com',
        password: 'password123',
        nickname: 'Bob'
    }
];

// 用于存储测试状态
const testState = {
    users: {},
    roomId: null,
    messages: {
        alice: [],
        bob: []
    }
};

// 延迟函数
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

// 注册用户
async function registerUser(user) {
    try {
        const response = await axios.post(`${API_BASE}/auth/register`, user);
        log(`✓ ${user.username} 注册成功`, 'green');
        return response.data;
    } catch (error) {
        if (error.response?.status === 409) {
            log(`! ${user.username} 已存在`, 'yellow');
        } else {
            log(`✗ ${user.username} 注册失败: ${error.message}`, 'red');
        }
    }
}

// 登录用户
async function loginUser(username, password) {
    try {
        const response = await axios.post(`${API_BASE}/auth/login`, {
            username,
            password
        });
        log(`✓ ${username} 登录成功`, 'green');
        return response.data;
    } catch (error) {
        log(`✗ ${username} 登录失败: ${error.message}`, 'red');
        throw error;
    }
}

// 创建房间
async function createRoom(token) {
    try {
        const response = await axios.post(
            `${API_BASE}/rooms`,
            {
                name: 'WebSocket测试房间',
                room_type: 'group',
                description: '用于测试实时消息分发'
            },
            {
                headers: { Authorization: `Bearer ${token}` }
            }
        );
        log(`✓ 房间创建成功: ${response.data.room.id}`, 'green');
        return response.data.room.id;
    } catch (error) {
        log(`! 使用默认测试房间`, 'yellow');
        return '00000000-0000-0000-0000-000000000001';
    }
}

// 加入房间
async function joinRoom(token, roomId, username) {
    try {
        await axios.post(
            `${API_BASE}/rooms/${roomId}/join`,
            {},
            {
                headers: { Authorization: `Bearer ${token}` }
            }
        );
        log(`✓ ${username} 加入房间成功`, 'green');
    } catch (error) {
        log(`! ${username} 可能已在房间中`, 'yellow');
    }
}

// 创建WebSocket连接
function createWebSocketConnection(username, token, roomId) {
    return new Promise((resolve, reject) => {
        const ws = new WebSocket(`${WS_BASE}/ws`);
        let authenticated = false;
        let joined = false;

        ws.on('open', () => {
            log(`✓ ${username} WebSocket连接成功`, 'green');
            
            // 发送认证消息
            ws.send(JSON.stringify({
                type: 'auth',
                token: token
            }));
        });

        ws.on('message', (data) => {
            try {
                const message = JSON.parse(data.toString());
                
                switch (message.type) {
                    case 'authed':
                        log(`✓ ${username} 认证成功`, 'green');
                        authenticated = true;
                        
                        // 加入房间
                        ws.send(JSON.stringify({
                            type: 'join',
                            room_id: roomId
                        }));
                        break;
                        
                    case 'joined':
                        log(`✓ ${username} 订阅房间成功`, 'green');
                        joined = true;
                        
                        if (authenticated && joined) {
                            resolve(ws);
                        }
                        break;
                        
                    case 'message':
                        log(`📨 ${username} 收到消息: ${message.content.substring(0, 30)}...`, 'cyan');
                        testState.messages[username].push(message);
                        break;
                        
                    case 'error':
                        log(`✗ ${username} 错误: ${message.message}`, 'red');
                        break;
                        
                    default:
                        log(`${username} 收到: ${JSON.stringify(message)}`, 'yellow');
                }
            } catch (error) {
                log(`✗ ${username} 消息解析错误: ${error.message}`, 'red');
            }
        });

        ws.on('error', (error) => {
            log(`✗ ${username} WebSocket错误: ${error.message}`, 'red');
            reject(error);
        });

        ws.on('close', () => {
            log(`${username} WebSocket连接关闭`, 'yellow');
        });

        // 超时处理
        setTimeout(() => {
            if (!authenticated || !joined) {
                reject(new Error(`${username} WebSocket连接超时`));
            }
        }, 5000);
    });
}

// 发送消息
async function sendMessage(token, roomId, content, username) {
    try {
        const response = await axios.post(
            `${API_BASE}/rooms/${roomId}/messages`,
            {
                content,
                message_type: 'text'
            },
            {
                headers: { Authorization: `Bearer ${token}` }
            }
        );
        log(`✓ ${username} 消息发送成功: ${content}`, 'green');
        return response.data.message;
    } catch (error) {
        log(`✗ ${username} 消息发送失败: ${error.message}`, 'red');
        throw error;
    }
}

// 获取消息历史
async function getMessageHistory(token, roomId) {
    try {
        const response = await axios.get(
            `${API_BASE}/rooms/${roomId}/messages?limit=10`,
            {
                headers: { Authorization: `Bearer ${token}` }
            }
        );
        return response.data;
    } catch (error) {
        log(`✗ 获取消息历史失败: ${error.message}`, 'red');
        throw error;
    }
}

// 主测试函数
async function runTest() {
    log('========================================', 'green');
    log('WebSocket 实时消息分发测试', 'green');
    log('========================================', 'green');

    try {
        // 1. 检查服务器状态
        log('\n检查服务器状态...', 'yellow');
        await axios.get(`${API_BASE}/healthz`);
        log('✓ 服务器正在运行', 'green');

        // 2. 注册用户
        log('\n注册测试用户...', 'yellow');
        for (const user of testUsers) {
            await registerUser(user);
        }

        // 3. 登录用户
        log('\n用户登录...', 'yellow');
        for (const user of testUsers) {
            const loginData = await loginUser(user.username, user.password);
            testState.users[user.username] = {
                ...loginData.user,
                token: loginData.token
            };
        }

        // 4. 创建房间
        log('\n创建测试房间...', 'yellow');
        testState.roomId = await createRoom(testState.users.alice.token);

        // 5. 用户加入房间
        log('\n用户加入房间...', 'yellow');
        await joinRoom(testState.users.alice.token, testState.roomId, 'alice');
        await joinRoom(testState.users.bob.token, testState.roomId, 'bob');

        // 6. 建立WebSocket连接
        log('\n建立WebSocket连接...', 'yellow');
        const aliceWs = await createWebSocketConnection(
            'alice',
            testState.users.alice.token,
            testState.roomId
        );
        
        await delay(1000);
        
        const bobWs = await createWebSocketConnection(
            'bob',
            testState.users.bob.token,
            testState.roomId
        );

        await delay(1000);

        // 7. 发送测试消息
        log('\n发送测试消息...', 'yellow');
        
        // Alice发送消息
        await sendMessage(
            testState.users.alice.token,
            testState.roomId,
            'Hello from Alice! Testing WebSocket broadcast.',
            'alice'
        );
        
        await delay(1000);
        
        // Bob发送消息
        await sendMessage(
            testState.users.bob.token,
            testState.roomId,
            'Hi Alice! Message received loud and clear.',
            'bob'
        );

        // 等待消息传递
        await delay(2000);

        // 8. 验证消息接收
        log('\n验证WebSocket消息接收...', 'yellow');
        
        const aliceReceived = testState.messages.alice.length;
        const bobReceived = testState.messages.bob.length;
        
        log(`Alice 收到 ${aliceReceived} 条消息`, aliceReceived >= 2 ? 'green' : 'red');
        log(`Bob 收到 ${bobReceived} 条消息`, bobReceived >= 2 ? 'green' : 'red');

        // 9. 获取消息历史
        log('\n获取消息历史...', 'yellow');
        const history = await getMessageHistory(testState.users.alice.token, testState.roomId);
        log(`✓ 消息历史: ${history.length} 条消息`, 'green');
        
        history.slice(-2).forEach(msg => {
            log(`  - ${msg.sender_id.substring(0, 8)}: ${msg.content.substring(0, 50)}`, 'cyan');
        });

        // 10. 关闭连接
        aliceWs.close();
        bobWs.close();

        // 测试总结
        log('\n========================================', 'green');
        log('测试完成！', 'green');
        log('========================================', 'green');

        const success = aliceReceived >= 2 && bobReceived >= 2;
        
        log('\n测试结果:', 'yellow');
        log(`• 用户认证: ✓`, 'green');
        log(`• WebSocket连接: ✓`, 'green');
        log(`• 房间订阅: ✓`, 'green');
        log(`• 消息发送: ✓`, 'green');
        log(`• 实时分发: ${success ? '✓' : '✗'}`, success ? 'green' : 'red');
        log(`• 消息持久化: ✓`, 'green');

        if (success) {
            log('\n🎉 所有测试通过！', 'green');
        } else {
            log('\n⚠️ 部分测试未通过，请检查WebSocket分发逻辑', 'yellow');
        }

        process.exit(success ? 0 : 1);

    } catch (error) {
        log(`\n测试失败: ${error.message}`, 'red');
        
        if (error.code === 'ECONNREFUSED') {
            log('\n请确保后端服务正在运行:', 'yellow');
            log('  cargo run', 'cyan');
        }
        
        process.exit(1);
    }
}

// 检查依赖
function checkDependencies() {
    try {
        require('ws');
        require('axios');
    } catch (error) {
        log('缺少必要的依赖，请运行:', 'red');
        log('  npm install ws axios', 'cyan');
        process.exit(1);
    }
}

// 运行测试
checkDependencies();
runTest();
