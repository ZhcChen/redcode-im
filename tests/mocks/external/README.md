# External Mock

本目录是 `tests/` backend contract 测试栈的外部依赖模拟层。

## 覆盖范围
- OAuth / JWKS（Google / Apple）
- FCM Push
- B2 / S3 兼容对象存储
- IPInfo
- 测试用 ID Token 生成

## 运行
```bash
cd tests/mocks/external
go run ./cmd/external-mock
```

默认监听 `:19080`。
