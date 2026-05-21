# 象汇 API 部署文档

## 📋 部署前准备

### 服务器要求
- **操作系统**: Ubuntu 20.04+ / Debian 11+ / CentOS 8+
- **配置**: 最低 2 核 4GB 内存，推荐 4 核 8GB
- **磁盘**: 至少 20GB 可用空间
- **域名**: 已解析到服务器 IP

### 本地准备
1. 提交所有代码到 Git 仓库
2. 确保 `develop` 或 `main` 分支是最新的

---

## 🚀 自动化部署（推荐）

### 方式一：一键部署脚本

**1. 服务器初始化**

SSH 登录服务器后，下载并运行初始化脚本：

```bash
# 下载初始化脚本
wget https://raw.githubusercontent.com/andrewbaek/new-api/main/custom/scripts/setup-server.sh

# 运行（需要 root 权限）
sudo bash setup-server.sh
```

脚本会自动：
- 安装 Docker、Docker Compose、Nginx
- 配置防火墙
- 生成随机密钥
- 创建部署目录

**2. 克隆代码**

```bash
cd /opt/new-api
git clone https://github.com/andrewbaek/new-api.git .
git checkout main  # 生产环境用 main，测试环境用 develop
```

**3. 配置环境变量**

```bash
# 复制配置模板
cp .env.production.example .env.production

# 编辑配置（填入初始化脚本生成的密钥）
vim .env.production
```

修改以下必填项：
```bash
POSTGRES_PASSWORD=<初始化脚本生成的密码>
REDIS_PASSWORD=<初始化脚本生成的密码>
SESSION_SECRET=<初始化脚本生成的密钥>
ENCRYPT_KEY=<初始化脚本生成的密钥>
SERVER_ADDRESS=https://api.yourdomain.com
```

**4. 修改 Docker Compose 配置**

```bash
vim docker-compose.production.yml
```

替换所有 `CHANGE_THIS_*` 为实际值（与 `.env.production` 中的密码保持一致）。

**5. 配置 Nginx**

```bash
# 复制 Nginx 配置
cp custom/config/nginx.conf /etc/nginx/sites-available/new-api

# 编辑配置
vim /etc/nginx/sites-available/new-api
```

修改以下内容：
- `server_name api.yourdomain.com` → 你的域名
- `allow YOUR_IP_ADDRESS;` → 你的管理 IP（用于访问 `/panel`）

```bash
# 启用配置
ln -s /etc/nginx/sites-available/new-api /etc/nginx/sites-enabled/

# 测试配置
nginx -t

# 重载 Nginx
systemctl reload nginx
```

**6. 申请 SSL 证书**

```bash
certbot --nginx -d api.yourdomain.com
```

按提示输入邮箱，证书会自动配置到 Nginx。

**7. 部署应用**

```bash
# 给脚本执行权限
chmod +x custom/scripts/deploy.sh

# 运行部署
bash custom/scripts/deploy.sh production
```

部署脚本会自动：
- 拉取最新代码
- 应用自定义补丁
- 构建 Docker 镜像
- 启动容器
- 健康检查

**8. 验证部署**

```bash
# 查看容器状态
docker compose -f docker-compose.production.yml ps

# 查看日志
docker compose -f docker-compose.production.yml logs -f new-api

# 访问网站
curl https://api.yourdomain.com/api/status
```

---

## 🔄 后续更新部署

代码更新后，只需运行：

```bash
cd /opt/new-api
bash custom/scripts/deploy.sh production
```

脚本会自动完成所有更新步骤。

---

## 🛠️ 手动部署（备选）

如果自动化脚本不适用，可以手动执行以下步骤：

### 1. 安装依赖

```bash
# Docker
curl -fsSL https://get.docker.com | sh

# Docker Compose
apt-get install -y docker-compose-plugin

# Nginx
apt-get install -y nginx
```

### 2. 克隆代码

```bash
git clone https://github.com/andrewbaek/new-api.git /opt/new-api
cd /opt/new-api
git checkout main
```

### 3. 配置环境

```bash
# 生成密钥
openssl rand -base64 32  # SESSION_SECRET
openssl rand -base64 32  # ENCRYPT_KEY
openssl rand -base64 24  # POSTGRES_PASSWORD
openssl rand -base64 24  # REDIS_PASSWORD

# 创建 .env.production
cp .env.production.example .env.production
vim .env.production  # 填入上面生成的密钥
```

### 4. 修改 Docker Compose

```bash
vim docker-compose.production.yml
# 替换所有 CHANGE_THIS_* 为实际密码
```

### 5. 启动服务

```bash
# 构建镜像
docker compose -f docker-compose.production.yml build

# 启动容器
docker compose -f docker-compose.production.yml up -d

# 查看日志
docker compose -f docker-compose.production.yml logs -f
```

### 6. 配置 Nginx + SSL

参考自动化部署的步骤 5-6。

---

## 📊 监控与维护

### 查看日志

```bash
# 实时日志
docker compose -f docker-compose.production.yml logs -f new-api

# 最近 100 行
docker compose -f docker-compose.production.yml logs --tail=100 new-api
```

### 重启服务

```bash
docker compose -f docker-compose.production.yml restart new-api
```

### 备份数据库

```bash
# 备份
docker exec new-api-prod-pg pg_dump -U root new-api > backup-$(date +%Y%m%d).sql

# 恢复
docker exec -i new-api-prod-pg psql -U root new-api < backup-20260521.sql
```

### 清理旧镜像

```bash
docker image prune -f
```

---

## 🔒 安全建议

1. **管理端保护**
   - Nginx 配置中限制 `/panel` 只允许特定 IP 访问
   - 定期更换管理员密码

2. **密钥管理**
   - 所有密钥使用强随机生成
   - 不要将 `.env.production` 提交到 Git

3. **防火墙**
   - 只开放 22（SSH）、80（HTTP）、443（HTTPS）端口
   - SSH 使用密钥登录，禁用密码登录

4. **SSL 证书**
   - 使用 Let's Encrypt 免费证书
   - 证书自动续期：`certbot renew --dry-run`

5. **定期更新**
   - 定期更新系统：`apt-get update && apt-get upgrade`
   - 定期更新 Docker 镜像

---

## ❓ 常见问题

### 1. 容器启动失败

查看日志：
```bash
docker compose -f docker-compose.production.yml logs new-api
```

常见原因：
- 数据库密码不匹配
- 端口被占用
- 磁盘空间不足

### 2. 无法访问网站

检查：
```bash
# Nginx 状态
systemctl status nginx

# 防火墙
ufw status

# 容器状态
docker ps
```

### 3. 数据库连接失败

检查 PostgreSQL 容器：
```bash
docker compose -f docker-compose.production.yml logs postgres
```

### 4. 如何修改配置

修改 `.env.production` 或 `docker-compose.production.yml` 后，重启容器：
```bash
docker compose -f docker-compose.production.yml down
docker compose -f docker-compose.production.yml up -d
```

---

## 📞 技术支持

- GitHub Issues: https://github.com/andrewbaek/new-api/issues
- 邮件: support@example.com

---

## 📝 更新日志

### v0.0.2-elephant-1 (2026-05-21)
- ✅ Google Material Design 3 主题
- ✅ 首页重写
- ✅ 文档页面
- ✅ 自动化部署脚本
- ✅ 生产环境配置模板
