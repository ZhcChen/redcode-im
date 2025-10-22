# MinIO 对象存储配置指南

## 概述
MinIO 是一个高性能的分布式对象存储服务，兼容 Amazon S3 API。在 RedCode IM 中用于存储：
- 用户头像
- 聊天图片
- 聊天文件
- 语音消息
- 视频文件

## 快速启动

### 1. 单独启动 MinIO
```bash
docker-compose -f docker-compose-minio.yaml up -d
```

### 2. 启动所有服务（包括MinIO）
```bash
docker-compose -f docker-compose-all.yml up -d
```

## 访问地址

| 服务 | 地址 | 说明 |
|------|------|------|
| MinIO API | http://localhost:9000 | S3 兼容 API 端点 |
| MinIO Console | http://localhost:9001 | Web 管理控制台 |
| 默认账号 | admin | 管理员用户名 |
| 默认密码 | admin123456 | 管理员密码 |

## 存储桶说明

系统会自动创建以下存储桶：

| 存储桶 | 用途 | 访问权限 | 说明 |
|--------|------|----------|------|
| avatars | 用户头像 | 公开读 | 存储用户头像图片 |
| chat-images | 聊天图片 | 公开读 | 存储聊天中的图片 |
| chat-files | 聊天文件 | 私有 | 存储聊天中的文件 |
| chat-videos | 视频文件 | 私有 | 存储聊天视频 |
| chat-voices | 语音消息 | 私有 | 存储语音消息 |

## 后端集成

### 1. 添加 Rust 依赖

在 `backend/Cargo.toml` 中添加：
```toml
[dependencies]
# S3 客户端
aws-sdk-s3 = "1.5.0"
aws-config = "1.0.3"
aws-credential-types = "1.0.3"
tokio = { version = "1", features = ["full"] }

# 文件处理
mime = "0.3"
uuid = { version = "1.5", features = ["v4"] }
```

### 2. MinIO 配置

创建 `backend/src/storage/minio.rs`：
```rust
use aws_sdk_s3::{Client, Config, Endpoint};
use aws_config::BehaviorVersion;
use aws_credential_types::Credentials;
use std::env;

pub struct MinioStorage {
    client: Client,
    bucket_prefix: String,
}

impl MinioStorage {
    pub async fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let endpoint = env::var("MINIO_ENDPOINT")
            .unwrap_or_else(|_| "http://localhost:9000".to_string());
        
        let access_key = env::var("MINIO_ACCESS_KEY")
            .unwrap_or_else(|_| "admin".to_string());
        
        let secret_key = env::var("MINIO_SECRET_KEY")
            .unwrap_or_else(|_| "admin123456".to_string());
        
        let creds = Credentials::new(
            access_key,
            secret_key,
            None,
            None,
            "minio"
        );
        
        let config = Config::builder()
            .behavior_version(BehaviorVersion::latest())
            .endpoint_resolver(Endpoint::immutable(endpoint.parse()?))
            .credentials_provider(creds)
            .region(aws_config::Region::new("us-east-1"))
            .force_path_style(true)
            .build();
        
        let client = Client::from_conf(config);
        
        Ok(Self {
            client,
            bucket_prefix: "redcode".to_string(),
        })
    }
    
    // 上传文件
    pub async fn upload_file(
        &self,
        bucket: &str,
        key: &str,
        data: Vec<u8>,
        content_type: &str,
    ) -> Result<String, Box<dyn std::error::Error>> {
        self.client
            .put_object()
            .bucket(bucket)
            .key(key)
            .body(data.into())
            .content_type(content_type)
            .send()
            .await?;
        
        Ok(format!("http://localhost:9000/{}/{}", bucket, key))
    }
    
    // 获取预签名URL
    pub async fn get_presigned_url(
        &self,
        bucket: &str,
        key: &str,
        expires_in: std::time::Duration,
    ) -> Result<String, Box<dyn std::error::Error>> {
        // 实现预签名URL生成
        todo!()
    }
}
```

### 3. 环境变量配置

在 `.env` 文件中添加：
```env
# MinIO配置
MINIO_ENDPOINT=http://localhost:9000
MINIO_ACCESS_KEY=admin
MINIO_SECRET_KEY=admin123456
MINIO_REGION=us-east-1
```

## 前端集成

### 1. 文件上传服务

创建 `frontend/lib/core/services/upload_service.dart`：
```dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class UploadService {
  static const String minioUrl = 'http://localhost:9000';
  
  // 上传图片
  static Future<String> uploadImage(File file) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
    final bucket = 'chat-images';
    
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$minioUrl/$bucket'),
    );
    
    request.files.add(
      await http.MultipartFile.fromPath('file', file.path),
    );
    
    final response = await request.send();
    
    if (response.statusCode == 200) {
      return '$minioUrl/$bucket/$fileName';
    }
    
    throw Exception('Upload failed');
  }
  
  // 上传头像
  static Future<String> uploadAvatar(File file) async {
    // 类似实现，使用 avatars bucket
  }
  
  // 上传文件
  static Future<String> uploadFile(File file) async {
    // 类似实现，使用 chat-files bucket
  }
}
```

### 2. 显示网络图片

```dart
// 显示MinIO中的图片
Image.network(
  imageUrl,  // http://localhost:9000/chat-images/xxx.jpg
  headers: {
    // 如果需要认证，添加headers
  },
  errorBuilder: (context, error, stackTrace) {
    return Icon(Icons.broken_image);
  },
)
```

## 管理命令

### 查看所有存储桶
```bash
docker exec -it redcode-minio-client mc ls local/
```

### 查看存储桶内容
```bash
docker exec -it redcode-minio-client mc ls local/chat-images/
```

### 上传文件测试
```bash
docker exec -it redcode-minio-client mc cp /etc/hostname local/chat-files/test.txt
```

### 设置存储桶策略
```bash
# 设置公开读取
docker exec -it redcode-minio-client mc anonymous set download local/bucket-name

# 设置私有
docker exec -it redcode-minio-client mc anonymous set none local/bucket-name
```

### 创建用户
```bash
docker exec -it redcode-minio-client mc admin user add local newuser newpassword
```

### 查看存储使用情况
```bash
docker exec -it redcode-minio-client mc du local/
```

## 生产环境配置

### 1. Nginx 反向代理

创建 `nginx-minio.conf`：
```nginx
server {
    listen 80;
    server_name minio.yourdomain.com;
    
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://minio:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 80;
    server_name console.minio.yourdomain.com;
    
    location / {
        proxy_pass http://minio:9001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### 2. SSL/TLS 配置

使用 Certbot 获取证书：
```bash
certbot --nginx -d minio.yourdomain.com -d console.minio.yourdomain.com
```

### 3. 集群模式

对于高可用，可以配置 MinIO 集群：
```yaml
version: '3.8'

services:
  minio1:
    image: minio/minio:latest
    command: server http://minio{1...4}/data{1...2}
    # ...
    
  minio2:
    image: minio/minio:latest
    command: server http://minio{1...4}/data{1...2}
    # ...
```

## 备份策略

### 自动备份脚本
```bash
#!/bin/bash
# backup-minio.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backup/minio/$DATE"

# 创建备份目录
mkdir -p $BACKUP_DIR

# 同步数据
docker exec redcode-minio-client mc mirror local/ $BACKUP_DIR/

# 压缩备份
tar -czf $BACKUP_DIR.tar.gz $BACKUP_DIR
rm -rf $BACKUP_DIR

# 删除7天前的备份
find /backup/minio/ -name "*.tar.gz" -mtime +7 -delete
```

### 定时备份
```bash
# 添加到 crontab
0 2 * * * /path/to/backup-minio.sh
```

## 监控和告警

### Prometheus 指标
MinIO 提供 Prometheus 指标端点：
```
http://localhost:9000/minio/v2/metrics/cluster
```

### Grafana Dashboard
可以导入 MinIO 官方 Dashboard：
- Dashboard ID: 13502

## 故障排查

### 1. 连接失败
```bash
# 检查服务状态
docker ps | grep minio

# 查看日志
docker logs redcode-minio
```

### 2. 权限问题
```bash
# 检查存储桶策略
docker exec -it redcode-minio-client mc anonymous list local/bucket-name
```

### 3. 存储空间不足
```bash
# 检查磁盘使用
df -h
docker system df

# 清理未使用的数据
docker system prune -a
```

### 4. 性能问题
```bash
# 查看MinIO统计
docker exec -it redcode-minio-client mc admin info local/
```

## 最佳实践

1. **文件命名**
   - 使用UUID避免冲突
   - 包含时间戳便于管理
   - 示例：`2024/01/15/550e8400-e29b-41d4-a716-446655440000.jpg`

2. **存储桶组织**
   - 按类型分桶（图片、文件、视频等）
   - 按日期分目录
   - 定期清理临时文件

3. **安全配置**
   - 生产环境必须修改默认密码
   - 使用HTTPS传输
   - 配置防火墙规则
   - 启用访问日志

4. **性能优化**
   - 使用CDN加速
   - 配置合理的缓存策略
   - 大文件使用分片上传

5. **容量规划**
   - 监控存储使用率
   - 设置配额限制
   - 定期归档旧数据

## 相关链接

- [MinIO 官方文档](https://min.io/docs/minio/linux/index.html)
- [MinIO SDK for Rust](https://github.com/minio/minio-rs)
- [MinIO SDK for Dart](https://pub.dev/packages/minio)
- [S3 API 参考](https://docs.aws.amazon.com/AmazonS3/latest/API/Welcome.html)
