# External Mock

本目录是 `tests/` api contract 测试栈的外部依赖模拟层。

## 覆盖范围
- FCM Push
- APNs Push
- S3 兼容对象存储
- IPInfo

## Push 模拟接口
- `POST /fcm/v1/projects/<project>/messages:send`：模拟 FCM 发送，token 包含 `invalid` 返回 400，包含 `unregistered` 返回 404。
- `POST /apns/3/device/<device_token>`：模拟 APNs 发送，token 包含 `invalid` 返回 `BadDeviceToken`，包含 `unregistered` 返回 `Unregistered`。

## S3 兼容接口
测试栈通过同一个 mock 服务模拟 S3 path-style 对象接口；B2 authorize 路由仅为旧用例兼容保留，API 当前不会调用：

- `GET /b2api/v4/b2_authorize_account`：返回 mock `s3ApiUrl`、`mock-bucket` 与读写能力。
- `GET /` / `HEAD /<bucket>` / `PUT /<bucket>`：列出、检查与创建 bucket。
- `PUT /mock-bucket/<key>`：写入对象。
- `HEAD /mock-bucket/<key>`：读取对象元数据。
- `GET /mock-bucket/<key>`：下载对象。
- `DELETE /mock-bucket/<key>`：删除对象。
- `POST /mock-bucket/<key>?uploads`、`PUT/POST/DELETE ...?uploadId=...`：multipart lifecycle。

`tests/docker-compose.test.yml` 已把 API 的 `REDCODE_IM_S3_*` 环境变量指向本服务，contract 测试不应访问线上 S3 兼容对象存储。

## 运行
```bash
cd tests/mocks/external
go run ./cmd/external-mock
```

默认监听 `:19080`。
