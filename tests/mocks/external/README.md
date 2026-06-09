# External Mock

本目录是 `tests/` api contract 测试栈的外部依赖模拟层。

## 覆盖范围
- FCM Push
- B2 / S3 兼容对象存储
- IPInfo

## B2 / S3 兼容接口
测试栈通过同一个 mock 服务模拟 B2 authorize 与 S3 path-style 对象接口：

- `GET /b2api/v4/b2_authorize_account`：返回 mock `s3ApiUrl`、`mock-bucket` 与读写能力。
- `GET /` / `PUT /<bucket>`：列出与创建 bucket。
- `PUT /mock-bucket/<key>`：写入对象。
- `HEAD /mock-bucket/<key>`：读取对象元数据。
- `GET /mock-bucket/<key>`：下载对象。
- `DELETE /mock-bucket/<key>`：删除对象。
- `POST /mock-bucket/<key>?uploads`、`PUT/POST/DELETE ...?uploadId=...`：multipart lifecycle。

`tests/docker-compose.yml` 已把 api 的 B2 环境变量指向本服务，contract 测试不应访问线上 Backblaze B2。

## 运行
```bash
cd tests/mocks/external
go run ./cmd/external-mock
```

默认监听 `:19080`。
