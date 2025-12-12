/* eslint-disable no-console */
const axios = require('axios');
const WebSocket = require('ws');

function getEnv(name, fallback) {
  const v = process.env[name];
  return v === undefined || v === '' ? fallback : v;
}

function requireEnv(name) {
  const v = process.env[name];
  if (!v) {
    throw new Error(`缺少环境变量 ${name}，例如：${name}=... node test_websocket.js`);
  }
  return v;
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function waitForJson(ws, predicate, timeoutMs) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      cleanup();
      reject(new Error(`等待消息超时（${timeoutMs}ms）`));
    }, timeoutMs);

    const onMessage = (data) => {
      try {
        const text = Buffer.isBuffer(data) ? data.toString('utf8') : String(data);
        const msg = JSON.parse(text);
        if (predicate(msg)) {
          cleanup();
          resolve(msg);
        }
      } catch (_) {
        // ignore non-json frames
      }
    };

    const onError = (err) => {
      cleanup();
      reject(err);
    };

    const cleanup = () => {
      clearTimeout(timer);
      ws.off('message', onMessage);
      ws.off('error', onError);
    };

    ws.on('message', onMessage);
    ws.on('error', onError);
  });
}

async function main() {
  const apiBaseUrl = getEnv('API_BASE_URL', 'http://localhost:8010');
  const wsUrl = getEnv('WS_URL', 'ws://localhost:8010/ws?format=json');

  const username = requireEnv('USERNAME');
  const password = requireEnv('PASSWORD');
  const roomId = requireEnv('ROOM_ID');

  const client = axios.create({ baseURL: apiBaseUrl, timeout: 10_000 });

  console.log(`[ws-test] login via ${apiBaseUrl}`);
  const loginResp = await client.post('/auth/login', { username, password });
  const token = loginResp?.data?.token;
  if (!token) {
    throw new Error(`登录响应缺少 token：${JSON.stringify(loginResp?.data)}`);
  }

  console.log(`[ws-test] connect ${wsUrl}`);
  const ws = new WebSocket(wsUrl);

  await new Promise((resolve, reject) => {
    ws.once('open', resolve);
    ws.once('error', reject);
  });

  ws.send(JSON.stringify({ type: 'auth', token }));
  const authed = await waitForJson(ws, (m) => m?.type === 'authed', 10_000);
  console.log(`[ws-test] authed user_id=${authed.user_id} conn_id=${authed.conn_id}`);

  ws.send(JSON.stringify({ type: 'join', room_id: roomId }));
  const joined = await waitForJson(
    ws,
    (m) => m?.type === 'joined' && String(m?.room_id) === String(roomId),
    10_000
  );
  console.log(`[ws-test] joined room_id=${joined.room_id}`);

  ws.send(JSON.stringify({ type: 'ping' }));
  await waitForJson(ws, (m) => m?.type === 'pong', 10_000);
  console.log('[ws-test] pong');

  // 给服务端一点点时间完成内部清理/日志写入
  await sleep(200);
  ws.close();

  console.log('[ws-test] OK');
}

main().catch((err) => {
  console.error('[ws-test] FAIL:', err?.message || err);
  process.exit(1);
});

