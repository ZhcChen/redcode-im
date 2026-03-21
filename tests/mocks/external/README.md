# External Mock（第三方依赖模拟）

用于本地测试环境模拟外部系统，避免依赖公网与真实云资源。

## 覆盖能力

- Tencent COS：对象上传/删除/存在性检查/分片上传/CORS/桶列表与创建。
- Tencent CI：审核任务提交与查询。
- Google/Apple JWKS：OAuth 登录校验公钥。
- Google OAuth Token：FCM 访问令牌。
- FCM Send：推送发送接口。
- IPInfo：IP 地理位置查询。
- ID Token 生成：用于测试 OAuth 登录（Google/Apple）。

## 启动

```bash
cd tests/mocks/external
go run ./cmd/external-mock
```

默认监听 `:19080`，可通过 `EXTERNAL_MOCK_ADDR` 覆盖。

## 关键接口

- 健康检查：`GET /healthz`
- Google JWKS：`GET /google/oauth2/v3/certs`
- Apple JWKS：`GET /apple/auth/keys`
- Google OAuth token：`POST /google/oauth2/token`
- FCM send：`POST /fcm/v1/projects/{project}/messages:send`
- IPInfo：`GET /ipinfo/{ip}/json?token=...`
- Tencent CI：
  - `POST /tencentci/{kind}/auditing`
  - `GET /tencentci/{kind}/auditing/{job_id}`
- 测试令牌：
  - `POST /mock/google/id-token`
  - `POST /mock/apple/id-token`
