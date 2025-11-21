# Admin 部署脚本使用说明

这个脚本用于自动构建、压缩和部署 Admin 前端到服务器。

## 前置要求

### 本地环境

1. **Bun** - 用于构建项目
   ```bash
   curl -fsSL https://bun.sh/install | bash
   ```

2. **7-Zip** - 用于压缩文件
   ```bash
   # macOS
   brew install p7zip

   # Ubuntu/Debian
   sudo apt-get install p7zip-full

   # CentOS/RHEL
   sudo yum install p7zip
   ```

3. **SSH 密钥** - 配置免密登录服务器
   ```bash
   # 生成 SSH 密钥(如果还没有)
   ssh-keygen -t rsa -b 4096

   # 复制公钥到服务器
   ssh-copy-id user@your-server-ip
   ```

### 服务器环境

1. **7-Zip** - 用于解压文件
   ```bash
   # Ubuntu/Debian
   sudo apt-get install p7zip-full

   # CentOS/RHEL
   sudo yum install p7zip
   ```

2. **Nginx** - Web 服务器(参考 nginx/README.md)

## 配置步骤

### 1. 创建配置文件

```bash
cd admin
cp deploy.config.example deploy.config
```

### 2. 修改配置文件

编辑 `deploy.config` 文件,修改以下配置:

```bash
# 服务器用户名
SERVER_USER="root"

# 服务器 IP 或域名
SERVER_HOST="123.456.789.0"

# 服务器部署路径
SERVER_PATH="/var/www/admin"
```

### 3. 配置 SSH 免密登录

```bash
# 测试 SSH 连接
ssh your-user@your-server-ip

# 如果需要密码,配置免密登录
ssh-copy-id your-user@your-server-ip
```

## 使用方法

### 基本使用

```bash
cd admin
./deploy.sh
```

### 脚本执行流程

脚本会自动执行以下步骤:

1. **构建项目**
   - 运行 `bun run build` 命令
   - 生成 `dist` 目录

2. **压缩文件**
   - 使用 7z 压缩 dist 目录中的所有文件
   - 生成带时间戳的压缩文件: `admin-dist-YYYYMMDD-HHMMSS.7z`

3. **上传到服务器**
   - 使用 SCP 上传压缩文件到服务器 `/tmp` 目录
   - SSH 连接到服务器执行部署命令

4. **服务器端操作**
   - 备份旧文件(如果存在)
   - 清空目标目录
   - 解压新文件到目标目录
   - 设置正确的文件权限
   - 清理临时文件

5. **清理本地文件**
   - 删除本地压缩文件

## 输出示例

```
加载配置文件: /path/to/admin/deploy.config
========================================
开始部署 Admin 前端
========================================

[1/3] 构建项目...
✓ 构建完成

[2/3] 压缩文件...
✓ 压缩完成: admin-dist-20241121-153000.7z

[3/3] 上传到服务器...
服务器: root@123.456.789.0
目标路径: /var/www/admin
✓ 上传完成

在服务器上解压并部署...
备份旧文件到: /var/www/admin_backup_20241121-153010
部署完成!

清理本地文件...

========================================
部署成功! 🎉
========================================
访问地址: http://admin.chatlyme.com
```

## 常见问题

### 1. 找不到 7z 命令

**错误信息:**
```
错误: 未找到 7z 命令
```

**解决方案:**
```bash
# macOS
brew install p7zip

# Ubuntu/Debian
sudo apt-get install p7zip-full

# CentOS/RHEL
sudo yum install p7zip
```

### 2. SSH 连接失败

**错误信息:**
```
Permission denied (publickey,password)
```

**解决方案:**
1. 确认服务器地址和用户名正确
2. 配置 SSH 密钥认证:
   ```bash
   ssh-copy-id user@server-ip
   ```
3. 或者使用密码登录(需要手动输入密码)

### 3. 服务器权限不足

**错误信息:**
```
Permission denied
```

**解决方案:**
1. 确保 SSH 用户有目标目录的写权限
2. 或者使用 sudo:
   ```bash
   # 修改脚本中的 ssh 命令部分,添加 sudo
   sudo mkdir -p ${SERVER_PATH}
   ```

### 4. 构建失败

**错误信息:**
```
构建失败!
```

**解决方案:**
1. 检查依赖是否安装:
   ```bash
   bun install
   ```
2. 检查 Node 版本是否符合要求
3. 查看具体错误信息并修复

### 5. 文件权限问题

部署后访问出现 403 错误:

**解决方案:**
```bash
# 在服务器上执行
sudo chown -R www-data:www-data /var/www/admin
sudo chmod -R 755 /var/www/admin
```

## 安全建议

1. **不要将 deploy.config 提交到 Git**
   - 配置文件已添加到 .gitignore
   - 包含敏感的服务器信息

2. **使用 SSH 密钥而非密码**
   - 更安全的认证方式
   - 避免在脚本中存储密码

3. **限制服务器用户权限**
   - 使用专门的部署用户
   - 不要直接使用 root 用户

4. **备份重要数据**
   - 脚本会自动备份旧文件
   - 建议定期备份到其他位置

## 高级用法

### 自定义压缩级别

编辑 `deploy.sh`,修改压缩命令:

```bash
# 最大压缩 (慢,体积小)
7z a -t7z -mx=9 ../${ARCHIVE_NAME} *

# 快速压缩 (快,体积大)
7z a -t7z -mx=1 ../${ARCHIVE_NAME} *
```

### 部署到多个服务器

创建多个配置文件:

```bash
# 生产环境
deploy.config.prod

# 测试环境
deploy.config.test
```

修改脚本接受参数:

```bash
./deploy.sh prod   # 使用 deploy.config.prod
./deploy.sh test   # 使用 deploy.config.test
```

### CI/CD 集成

在 GitHub Actions 或其他 CI 平台使用:

```yaml
- name: Deploy Admin
  run: |
    cd admin
    ./deploy.sh
  env:
    SERVER_USER: ${{ secrets.SERVER_USER }}
    SERVER_HOST: ${{ secrets.SERVER_HOST }}
    SERVER_PATH: ${{ secrets.SERVER_PATH }}
```
