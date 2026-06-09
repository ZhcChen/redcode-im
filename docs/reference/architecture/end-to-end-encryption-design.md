# 端到端加密 (E2EE) 设计方案

## 一、技术选型

### 1.1 加密协议
- **Signal Protocol** (推荐) - 业界标准,成熟稳定
- 算法组合:
  - 密钥交换: X3DH (Extended Triple Diffie-Hellman)
  - 消息加密: Double Ratchet Algorithm
  - 对称加密: AES-256-GCM
  - 签名: Ed25519

### 1.2 技术栈
```
后端 (Rust):
- libsignal-protocol-rust  # Signal 协议实现
- ring / RustCrypto        # 底层加密库
- serde_json              # 序列化

前端 (TypeScript):
- @signalapp/libsignal-client  # Signal 官方JS库
- subtle-crypto (Web Crypto API) # 浏览器原生加密
```

---

## 二、密钥体系设计

### 2.1 密钥类型

```typescript
// 1. 身份密钥对 (Identity Key Pair) - IK
interface IdentityKeyPair {
  privateKey: Uint8Array;  // 32字节,永不上传
  publicKey: Uint8Array;   // 32字节,公开
  createdAt: number;
}

// 2. 签名预密钥对 (Signed Pre-Key) - SPK
interface SignedPreKeyPair {
  keyId: number;
  privateKey: Uint8Array;
  publicKey: Uint8Array;
  signature: Uint8Array;   // IK私钥签名
  createdAt: number;
  expiresAt: number;       // 1周后过期
}

// 3. 一次性预密钥 (One-Time Pre-Key) - OPK
interface OneTimePreKey {
  keyId: number;
  privateKey: Uint8Array;
  publicKey: Uint8Array;
}
```

### 2.2 密钥存储

```rust
// api/src/database/models/e2ee_keys.rs
use sqlx::FromRow;
use chrono::{DateTime, Utc};

#[derive(Debug, FromRow)]
pub struct UserIdentityKey {
    pub user_id: i64,
    pub public_key: Vec<u8>,      // 32字节公钥
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, FromRow)]
pub struct SignedPreKey {
    pub user_id: i64,
    pub key_id: i32,
    pub public_key: Vec<u8>,
    pub signature: Vec<u8>,       // Ed25519签名
    pub created_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
}

#[derive(Debug, FromRow)]
pub struct OneTimePreKey {
    pub id: i64,
    pub user_id: i64,
    pub key_id: i32,
    pub public_key: Vec<u8>,
    pub is_used: bool,
    pub created_at: DateTime<Utc>,
}
```

---

## 三、初始化流程

### 3.1 用户注册时生成密钥

```typescript
// desktop/src/crypto/e2ee.ts
import * as SignalProtocol from '@signalapp/libsignal-client';

async function initializeE2EE(userId: string): Promise<void> {
  // 1. 生成身份密钥对 (永久)
  const identityKeyPair = SignalProtocol.PrivateKey.generate();

  // 2. 生成签名预密钥对 (1周轮换)
  const signedPreKeyId = generateRandomId();
  const signedPreKey = SignalProtocol.PrivateKey.generate();
  const signedPreKeySignature = identityKeyPair.sign(
    signedPreKey.getPublicKey().serialize()
  );

  // 3. 生成100个一次性预密钥
  const oneTimePreKeys: OneTimePreKey[] = [];
  for (let i = 0; i < 100; i++) {
    const keyId = generateRandomId();
    const privateKey = SignalProtocol.PrivateKey.generate();
    oneTimePreKeys.push({
      keyId,
      privateKey: privateKey.serialize(),
      publicKey: privateKey.getPublicKey().serialize(),
    });
  }

  // 4. 本地存储私钥 (IndexedDB)
  await storePrivateKeys({
    identityPrivateKey: identityKeyPair.serialize(),
    signedPreKeyPrivate: signedPreKey.serialize(),
    oneTimePreKeysPrivate: oneTimePreKeys,
  });

  // 5. 上传公钥到服务器
  await uploadPublicKeys({
    identityPublicKey: identityKeyPair.getPublicKey().serialize(),
    signedPreKey: {
      keyId: signedPreKeyId,
      publicKey: signedPreKey.getPublicKey().serialize(),
      signature: signedPreKeySignature,
    },
    oneTimePreKeys: oneTimePreKeys.map(k => ({
      keyId: k.keyId,
      publicKey: k.publicKey,
    })),
  });
}
```

### 3.2 服务器API设计

```rust
// api/src/handlers/e2ee.rs
use axum::{Json, extract::State};
use crate::auth::Claims;

// 上传预密钥包
#[derive(Debug, Deserialize)]
pub struct UploadKeysRequest {
    pub identity_key: Vec<u8>,
    pub signed_pre_key: SignedPreKeyData,
    pub one_time_pre_keys: Vec<OneTimePreKeyData>,
}

pub async fn upload_keys(
    State(state): State<AppState>,
    claims: Claims,
    Json(req): Json<UploadKeysRequest>,
) -> Result<Json<ApiResponse>, AppError> {
    let user_id = claims.sub;

    // 1. 验证签名预密钥的签名
    verify_signed_pre_key(&req.identity_key, &req.signed_pre_key)?;

    // 2. 存储身份公钥
    sqlx::query!(
        "INSERT INTO user_identity_keys (user_id, public_key, created_at)
         VALUES ($1, $2, NOW())
         ON CONFLICT (user_id) DO NOTHING",
        user_id,
        &req.identity_key
    )
    .execute(&state.db_pool)
    .await?;

    // 3. 存储签名预密钥
    sqlx::query!(
        "INSERT INTO signed_pre_keys
         (user_id, key_id, public_key, signature, created_at, expires_at)
         VALUES ($1, $2, $3, $4, NOW(), NOW() + INTERVAL '7 days')",
        user_id,
        req.signed_pre_key.key_id,
        &req.signed_pre_key.public_key,
        &req.signed_pre_key.signature
    )
    .execute(&state.db_pool)
    .await?;

    // 4. 批量存储一次性预密钥
    for opk in req.one_time_pre_keys {
        sqlx::query!(
            "INSERT INTO one_time_pre_keys (user_id, key_id, public_key, is_used)
             VALUES ($1, $2, $3, false)",
            user_id, opk.key_id, &opk.public_key
        )
        .execute(&state.db_pool)
        .await?;
    }

    Ok(Json(ApiResponse::success("密钥上传成功")))
}
```

---

## 四、密钥交换流程 (X3DH)

### 4.1 发起会话 (Alice → Bob)

```typescript
// Alice 想给 Bob 发第一条消息
async function initializeSession(
  aliceUserId: string,
  bobUserId: string
): Promise<void> {
  // 1. 从服务器获取 Bob 的公钥包
  const bobKeyBundle = await fetchKeyBundle(bobUserId);
  /*
  {
    identityKey: Uint8Array,      // IK_B
    signedPreKey: {
      keyId: number,
      publicKey: Uint8Array,      // SPK_B
      signature: Uint8Array,
    },
    oneTimePreKey?: {             // OPK_B (可选)
      keyId: number,
      publicKey: Uint8Array,
    }
  }
  */

  // 2. 验证签名预密钥的有效性
  const isValid = SignalProtocol.PublicKey
    .deserialize(bobKeyBundle.identityKey)
    .verify(
      bobKeyBundle.signedPreKey.publicKey,
      bobKeyBundle.signedPreKey.signature
    );
  if (!isValid) throw new Error("签名验证失败");

  // 3. 加载 Alice 的身份私钥
  const aliceIdentityKey = await loadIdentityPrivateKey(aliceUserId);

  // 4. 生成临时密钥对 (Ephemeral Key)
  const ephemeralKey = SignalProtocol.PrivateKey.generate();

  // 5. 执行 X3DH 密钥协商
  const sharedSecret = performX3DH({
    // Alice 的密钥
    IK_A: aliceIdentityKey,
    EK_A: ephemeralKey,

    // Bob 的公钥
    IK_B: bobKeyBundle.identityKey,
    SPK_B: bobKeyBundle.signedPreKey.publicKey,
    OPK_B: bobKeyBundle.oneTimePreKey?.publicKey,
  });

  // 6. 派生会话密钥
  const rootKey = deriveRootKey(sharedSecret);

  // 7. 创建 Double Ratchet 会话
  const session = await createDoubleRatchetSession({
    rootKey,
    remoteIdentityKey: bobKeyBundle.identityKey,
  });

  // 8. 保存会话
  await saveSession(bobUserId, session);

  // 9. 返回初始消息头 (发送给Bob)
  return {
    senderIdentityKey: aliceIdentityKey.getPublicKey().serialize(),
    senderEphemeralKey: ephemeralKey.getPublicKey().serialize(),
    usedOneTimePreKeyId: bobKeyBundle.oneTimePreKey?.keyId,
  };
}

// X3DH 密钥协商实现
function performX3DH(keys: {
  IK_A: PrivateKey,  // Alice 身份私钥
  EK_A: PrivateKey,  // Alice 临时私钥
  IK_B: PublicKey,   // Bob 身份公钥
  SPK_B: PublicKey,  // Bob 签名预公钥
  OPK_B?: PublicKey, // Bob 一次性预公钥 (可选)
}): Uint8Array {
  // DH1 = DH(IK_A, SPK_B)
  const dh1 = keys.IK_A.agree(keys.SPK_B);

  // DH2 = DH(EK_A, IK_B)
  const dh2 = keys.EK_A.agree(keys.IK_B);

  // DH3 = DH(EK_A, SPK_B)
  const dh3 = keys.EK_A.agree(keys.SPK_B);

  // DH4 = DH(EK_A, OPK_B) [如果有一次性预密钥]
  const dh4 = keys.OPK_B ? keys.EK_A.agree(keys.OPK_B) : null;

  // 组合所有 DH 结果
  const dhResults = dh4
    ? concat(dh1, dh2, dh3, dh4)
    : concat(dh1, dh2, dh3);

  // KDF 派生最终共享密钥
  return HKDF(dhResults, "SignalProtocol_Session");
}
```

### 4.2 服务器API: 获取密钥包

```rust
// api/src/handlers/e2ee.rs

#[derive(Debug, Serialize)]
pub struct KeyBundleResponse {
    pub identity_key: Vec<u8>,
    pub signed_pre_key: SignedPreKeyData,
    pub one_time_pre_key: Option<OneTimePreKeyData>,
}

pub async fn get_key_bundle(
    State(state): State<AppState>,
    Path(user_id): Path<i64>,
) -> Result<Json<KeyBundleResponse>, AppError> {
    // 1. 获取身份公钥
    let identity_key = sqlx::query_scalar!(
        "SELECT public_key FROM user_identity_keys WHERE user_id = $1",
        user_id
    )
    .fetch_one(&state.db_pool)
    .await?;

    // 2. 获取最新的签名预密钥
    let signed_pre_key = sqlx::query_as!(
        SignedPreKeyData,
        "SELECT key_id, public_key, signature
         FROM signed_pre_keys
         WHERE user_id = $1 AND expires_at > NOW()
         ORDER BY created_at DESC
         LIMIT 1",
        user_id
    )
    .fetch_one(&state.db_pool)
    .await?;

    // 3. 获取一个未使用的一次性预密钥 (原子操作)
    let one_time_pre_key = sqlx::query_as!(
        OneTimePreKeyData,
        "UPDATE one_time_pre_keys
         SET is_used = true
         WHERE id = (
           SELECT id FROM one_time_pre_keys
           WHERE user_id = $1 AND is_used = false
           ORDER BY created_at
           LIMIT 1
           FOR UPDATE SKIP LOCKED
         )
         RETURNING key_id, public_key",
        user_id
    )
    .fetch_optional(&state.db_pool)
    .await?;

    // 4. 如果一次性预密钥少于20个,通知用户补充
    let remaining_count = sqlx::query_scalar!(
        "SELECT COUNT(*) FROM one_time_pre_keys
         WHERE user_id = $1 AND is_used = false",
        user_id
    )
    .fetch_one(&state.db_pool)
    .await?;

    if remaining_count.unwrap_or(0) < 20 {
        // 发送 WebSocket 通知让客户端上传新密钥
        notify_low_pre_keys(user_id, &state).await?;
    }

    Ok(Json(KeyBundleResponse {
        identity_key,
        signed_pre_key,
        one_time_pre_key,
    }))
}
```

---

## 五、消息加密/解密流程

### 5.1 发送加密消息

```typescript
// desktop/src/crypto/message.ts

interface EncryptedMessage {
  ciphertext: Uint8Array;      // 密文
  messageKeys: Uint8Array;      // 消息密钥 (用接收方公钥加密)
  counter: number;              // Ratchet 计数器
  previousCounter: number;      // 上一轮计数器
}

async function encryptMessage(
  recipientUserId: string,
  plaintext: string
): Promise<EncryptedMessage> {
  // 1. 加载与接收方的会话
  const session = await loadSession(recipientUserId);

  if (!session) {
    // 首次发送,需要初始化会话
    await initializeSession(currentUserId, recipientUserId);
    session = await loadSession(recipientUserId);
  }

  // 2. Double Ratchet: 派生消息密钥
  const { messageKey, nextChainKey } = deriveMessageKey(
    session.sendingChainKey,
    session.counter
  );

  // 3. 使用 AES-256-GCM 加密消息
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await crypto.subtle.importKey(
    'raw',
    messageKey,
    { name: 'AES-GCM' },
    false,
    ['encrypt']
  );

  const ciphertext = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    key,
    new TextEncoder().encode(plaintext)
  );

  // 4. 更新会话状态
  session.sendingChainKey = nextChainKey;
  session.counter += 1;
  await saveSession(recipientUserId, session);

  // 5. 返回加密消息
  return {
    ciphertext: new Uint8Array(ciphertext),
    messageKeys: messageKey,
    counter: session.counter - 1,
    previousCounter: session.previousCounter,
    iv,
  };
}

// KDF 链派生
function deriveMessageKey(
  chainKey: Uint8Array,
  counter: number
): { messageKey: Uint8Array; nextChainKey: Uint8Array } {
  // Message Key = HMAC-SHA256(chainKey, "message" || counter)
  const messageKey = hmacSHA256(
    chainKey,
    concat("message", intToBytes(counter))
  );

  // Next Chain Key = HMAC-SHA256(chainKey, "chain")
  const nextChainKey = hmacSHA256(chainKey, "chain");

  return { messageKey, nextChainKey };
}
```

### 5.2 接收解密消息

```typescript
async function decryptMessage(
  senderUserId: string,
  encryptedMessage: EncryptedMessage
): Promise<string> {
  // 1. 加载与发送方的会话
  let session = await loadSession(senderUserId);

  if (!session) {
    // 被动接收首条消息,需要处理初始消息头
    session = await processInitialMessage(senderUserId, encryptedMessage);
  }

  // 2. 处理消息乱序 (跳过的消息)
  if (encryptedMessage.counter > session.receivingCounter) {
    // 保存跳过的消息密钥,等待后续补齐
    await saveSkippedMessageKeys(
      senderUserId,
      session.receivingCounter,
      encryptedMessage.counter
    );
  }

  // 3. 派生消息密钥
  const messageKey = deriveMessageKey(
    session.receivingChainKey,
    encryptedMessage.counter
  ).messageKey;

  // 4. 解密消息
  const key = await crypto.subtle.importKey(
    'raw',
    messageKey,
    { name: 'AES-GCM' },
    false,
    ['decrypt']
  );

  try {
    const plaintext = await crypto.subtle.decrypt(
      { name: 'AES-GCM', iv: encryptedMessage.iv },
      key,
      encryptedMessage.ciphertext
    );

    // 5. 更新会话状态
    session.receivingCounter = encryptedMessage.counter + 1;
    session.receivingChainKey = deriveMessageKey(
      session.receivingChainKey,
      encryptedMessage.counter
    ).nextChainKey;
    await saveSession(senderUserId, session);

    // 6. 删除已使用的消息密钥
    await deleteMessageKey(senderUserId, encryptedMessage.counter);

    return new TextDecoder().decode(plaintext);

  } catch (error) {
    // 解密失败,可能是密钥不匹配或消息被篡改
    console.error("消息解密失败", error);
    throw new Error("消息已损坏或被篡改");
  }
}
```

---

## 六、群聊加密方案

### 6.1 Sender Keys (发送方密钥)

```typescript
// 群聊使用 Sender Keys 协议,避免 N² 加密复杂度
interface GroupSession {
  groupId: string;
  senderKeyId: number;
  senderChainKey: Uint8Array;
  senderSigningKey: PrivateKey;  // 签名密钥
  memberKeys: Map<string, PublicKey>;  // 成员公钥
}

// 创建群聊会话
async function createGroupSession(
  groupId: string,
  memberUserIds: string[]
): Promise<void> {
  // 1. 生成群发送密钥
  const senderChainKey = crypto.getRandomValues(new Uint8Array(32));
  const signingKey = SignalProtocol.PrivateKey.generate();

  // 2. 使用 1:1 会话加密发送密钥给每个成员
  for (const memberId of memberUserIds) {
    const encryptedSenderKey = await encryptMessage(memberId, {
      groupId,
      senderChainKey,
      senderPublicKey: signingKey.getPublicKey().serialize(),
    });

    // 通过服务器分发
    await sendSenderKeyDistribution(memberId, encryptedSenderKey);
  }

  // 3. 保存群会话
  await saveGroupSession({
    groupId,
    senderKeyId: generateRandomId(),
    senderChainKey,
    senderSigningKey: signingKey,
  });
}

// 发送群消息
async function encryptGroupMessage(
  groupId: string,
  plaintext: string
): Promise<EncryptedGroupMessage> {
  const session = await loadGroupSession(groupId);

  // 1. 派生消息密钥
  const { messageKey, nextChainKey } = deriveMessageKey(
    session.senderChainKey,
    session.counter
  );

  // 2. 加密消息
  const ciphertext = await aesGcmEncrypt(messageKey, plaintext);

  // 3. 签名保证完整性
  const signature = session.senderSigningKey.sign(ciphertext);

  // 4. 更新会话
  session.senderChainKey = nextChainKey;
  session.counter += 1;
  await saveGroupSession(groupId, session);

  return {
    groupId,
    senderKeyId: session.senderKeyId,
    ciphertext,
    signature,
    counter: session.counter - 1,
  };
}
```

---

## 七、数据库表设计

```sql
-- 用户身份公钥
CREATE TABLE user_identity_keys (
    user_id BIGINT PRIMARY KEY REFERENCES users(id),
    public_key BYTEA NOT NULL,  -- 32字节 Ed25519 公钥
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- 签名预密钥
CREATE TABLE signed_pre_keys (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    key_id INTEGER NOT NULL,
    public_key BYTEA NOT NULL,
    signature BYTEA NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL,
    UNIQUE(user_id, key_id)
);

CREATE INDEX idx_signed_pre_keys_expires ON signed_pre_keys(user_id, expires_at);

-- 一次性预密钥
CREATE TABLE one_time_pre_keys (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    key_id INTEGER NOT NULL,
    public_key BYTEA NOT NULL,
    is_used BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, key_id)
);

CREATE INDEX idx_one_time_pre_keys_unused ON one_time_pre_keys(user_id, is_used)
WHERE is_used = false;

-- 加密消息表 (扩展现有消息表)
ALTER TABLE messages ADD COLUMN IF NOT EXISTS encrypted_content BYTEA;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS encryption_metadata JSONB;
-- encryption_metadata 包含: { counter, previousCounter, senderKeyId }

-- 群发送密钥分发记录
CREATE TABLE group_sender_key_distributions (
    id BIGSERIAL PRIMARY KEY,
    group_id BIGINT NOT NULL REFERENCES rooms(id),
    sender_user_id BIGINT NOT NULL REFERENCES users(id),
    recipient_user_id BIGINT NOT NULL REFERENCES users(id),
    sender_key_id INTEGER NOT NULL,
    encrypted_sender_key BYTEA NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(group_id, sender_user_id, recipient_user_id, sender_key_id)
);
```

---

## 八、实现步骤

### 阶段1: 基础设施 (2周)
1. ✅ 集成 Signal Protocol 库
2. ✅ 实现密钥生成和存储
3. ✅ 实现 X3DH 密钥交换
4. ✅ 实现 Double Ratchet 算法
5. ✅ 数据库表设计

### 阶段2: 1对1加密 (2周)
6. ✅ 实现私聊消息加密/解密
7. ✅ 实现会话管理
8. ✅ 实现消息乱序处理
9. ✅ 前端密钥存储 (IndexedDB)
10. ✅ 单元测试

### 阶段3: 群聊加密 (2周)
11. ✅ 实现 Sender Keys 协议
12. ✅ 实现群成员变更处理
13. ✅ 实现密钥轮换机制
14. ✅ 集成测试

### 阶段4: 多设备支持 (1周)
15. ✅ 实现设备间会话同步
16. ✅ 实现消息历史解密
17. ✅ 设备管理界面

### 阶段5: 优化和安全审计 (1周)
18. ✅ 性能优化
19. ✅ 安全审计
20. ✅ 文档完善

---

## 九、安全注意事项

### 9.1 关键原则
- ❌ **私钥永不离开设备**
- ✅ 使用操作系统密钥链存储
- ✅ 定期轮换签名预密钥
- ✅ 实现前向保密
- ✅ 防止重放攻击 (计数器机制)
- ✅ 消息完整性验证 (AEAD)

### 9.2 前端安全存储

```typescript
// 使用 IndexedDB 加密存储
import { openDB } from 'idb';

async function storePrivateKey(
  userId: string,
  key: Uint8Array
): Promise<void> {
  const db = await openDB('e2ee-keys', 1, {
    upgrade(db) {
      db.createObjectStore('keys');
    },
  });

  // 使用操作系统密钥链派生的密钥加密存储
  const masterKey = await getDeviceMasterKey();
  const encryptedKey = await aesGcmEncrypt(masterKey, key);

  await db.put('keys', encryptedKey, `${userId}_identity`);
}
```

---

## 十、常见问题

### Q1: 服务器能看到消息内容吗?
**A:** 不能。服务器只存储密文,没有私钥无法解密。

### Q2: 消息可以备份吗?
**A:** 可以,但需要用户导出私钥并安全保管。失去私钥=失去历史消息。

### Q3: 如何处理设备丢失?
**A:**
1. 其他设备撤销丢失设备的会话
2. 重新生成所有密钥
3. 通知联系人更新密钥包

### Q4: 群聊成员变更如何处理?
**A:**
- 新成员加入: 使用新 Sender Key,无法解密历史消息
- 成员移除: 立即轮换 Sender Key,防止继续解密

### Q5: 性能影响?
**A:**
- 首次会话建立: ~50ms (密钥交换)
- 后续消息加密: ~1-2ms (AES-GCM)
- 群聊优化: O(1) 加密复杂度 (Sender Keys)

---

## 十一、参考资源

- [Signal Protocol 规范](https://signal.org/docs/)
- [libsignal-protocol-rust](https://github.com/signalapp/libsignal)
- [Double Ratchet 算法](https://signal.org/docs/specifications/doubleratchet/)
- [X3DH 密钥协商](https://signal.org/docs/specifications/x3dh/)
