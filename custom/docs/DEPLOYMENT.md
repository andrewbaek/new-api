# 象汇 API 部署文档（China Edition · 方案 A）

> **方案概述**：本地 Mac 构建 Docker 镜像 → 打成 tar.gz → rsync 到中国服务器 → docker load 后启动
>
> 服务器**零外网依赖**（除 apt 走腾讯云内网外，不需要访问 GitHub / Docker Hub / Go Proxy）
>
> 适用：腾讯云轻量应用服务器（Lighthouse）· Ubuntu Server 24.04 LTS

---

## 📋 部署前准备

### 服务器要求
- **类型**：腾讯云轻量应用服务器 / 标准 CVM
- **系统**：Ubuntu Server 24.04 LTS 64bit
- **配置**：最低 2 核 4GB（已针对此规格调优）
- **磁盘**：60GB+
- **域名**：已 ICP 备案 + 已接入腾讯云
- **证书**：已签发的 SSL 证书（fullchain.pem + privkey.pem）

### 本机要求（Mac）
- Docker Desktop（含 buildx）
- `rsync`、`ssh`（系统自带）
- 能 SSH 到服务器（推荐用 SSH key）

### 腾讯云控制台（**必做**）
1. 进入实例 → **防火墙规则** → 添加规则：
   - 入站 TCP `80` 允许所有
   - 入站 TCP `443` 允许所有
2. 确认域名解析已指向服务器 IP
3. 确认域名已"备案接入"腾讯云

---

## 🚀 部署流程总览

```
┌── 一次性（约 15 分钟）─────────────────────────────────────
│
│  Mac:                          服务器:
│  scp setup-server-cn.sh ─────► sudo bash setup-server-cn.sh
│  scp 证书.pem ─────────────► /etc/ssl/new-api/
│  cp .env.deploy.example .env.deploy
│  vim .env.deploy（填 IP/用户）
│
└── 完成

┌── 每次发布（约 3-5 分钟）─────────────────────────────────
│
│  Mac:
│  bash custom/scripts/merge-upstream.sh  # 可选，跟随上游
│  bash custom/scripts/deploy-cn.sh
│   ├─ build-image.sh   构建 linux/amd64 镜像
│   ├─ rsync            传输镜像 + 配置到服务器
│   └─ ssh              触发 install-on-server.sh
│                        ├─ pg_dump 备份
│                        ├─ docker load + compose up
│                        ├─ 健康检查 /api/status
│                        └─ 失败自动回滚到上一版本
│
└── 完成
```

---

## 🛠️ 一次性初始化

### 1. 本机：编辑部署配置

```bash
cp .env.deploy.example .env.deploy
vim .env.deploy
```

填入：

```bash
DEPLOY_USER=ubuntu             # 服务器 SSH 用户
DEPLOY_SERVER=1.2.3.4          # 服务器公网 IP（或域名）
DEPLOY_PORT=22                 # SSH 端口
DEPLOY_REMOTE_DIR=/opt/new-api # 服务器部署目录
```

### 2. 本机：推送 SSH key 到服务器（建议）

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub ubuntu@1.2.3.4
```

### 3. 服务器：运行初始化脚本

```bash
# 在 Mac 上传脚本和配置
scp -r custom/scripts/setup-server-cn.sh custom/config/{sources.list.noble,daemon.json} \
    ubuntu@1.2.3.4:/tmp/

# SSH 上去，把脚本和配置组装好
ssh ubuntu@1.2.3.4 << 'REMOTE'
  mkdir -p /tmp/setup
  mv /tmp/setup-server-cn.sh /tmp/setup/
  mkdir -p /tmp/setup/config && mv /tmp/sources.list.noble /tmp/daemon.json /tmp/setup/config/
  cd /tmp/setup && ls -la
REMOTE

# 执行初始化（需要 sudo）
ssh -t ubuntu@1.2.3.4 "cd /tmp/setup && sudo bash custom/scripts/setup-server-cn.sh"
```

> **更简洁的做法**（推荐）：先 rsync 整个仓库到服务器临时目录：
>
> ```bash
> rsync -az --exclude=.git --exclude=node_modules --exclude=dist . \
>     ubuntu@1.2.3.4:/tmp/new-api-init/
> ssh -t ubuntu@1.2.3.4 "sudo bash /tmp/new-api-init/custom/scripts/setup-server-cn.sh"
> ssh ubuntu@1.2.3.4 "rm -rf /tmp/new-api-init"
> ```

脚本会自动完成：
- ✅ 切换 apt 源到腾讯云内网
- ✅ 安装 Docker CE / Compose / Nginx / 基础工具
- ✅ 配置 Docker 镜像加速（多源）
- ✅ 配置 UFW 防火墙（22/80/443）
- ✅ 创建 `/opt/new-api/{data,logs,images,backup,config}` 目录
- ✅ 生成 `/opt/new-api/.env.production`（含强随机密钥）
- ✅ 当前用户加入 docker 组

**重要：把生成的 `.env.production` 备份到本地保存**：

```bash
scp ubuntu@1.2.3.4:/opt/new-api/.env.production \
    ~/backups/new-api-env-$(date +%Y%m%d).env
chmod 600 ~/backups/*.env
```

### 4. 服务器：上传 SSL 证书

```bash
# 把你的证书文件上传到服务器
scp /path/to/your/fullchain.pem /path/to/your/privkey.pem \
    ubuntu@1.2.3.4:/tmp/

ssh -t ubuntu@1.2.3.4 << 'REMOTE'
  sudo mv /tmp/fullchain.pem /tmp/privkey.pem /etc/ssl/new-api/
  sudo chown root:root /etc/ssl/new-api/*.pem
  sudo chmod 600 /etc/ssl/new-api/privkey.pem
  sudo chmod 644 /etc/ssl/new-api/fullchain.pem
REMOTE
```

### 5. 重新登录使 docker 组生效

```bash
ssh ubuntu@1.2.3.4 'exit'  # 退出
ssh ubuntu@1.2.3.4 'docker ps'  # 测试，应无需 sudo 即可运行
```

---

## 🚢 首次部署应用

```bash
# 在 Mac 项目根目录
cd /Users/yanglin/workspace/new-api
bash custom/scripts/deploy-cn.sh
```

脚本会依次执行：
1. **构建** `xiang-api:<git-sha>` 镜像（linux/amd64，用 npmmirror + goproxy.cn）
2. **打包** 到 `dist/xiang-api-<sha>.tar.gz`
3. **rsync** 镜像 + compose 文件 + 安装脚本到服务器
4. **SSH** 触发 `install-on-server.sh`：
   - 备份当前数据库（首次无）
   - `docker load` 新镜像
   - `docker compose up -d`
   - 等待 `/api/status` 健康检查（最长 90s）
   - 失败则自动回滚

预计耗时（4G 宽带上行 1MB/s）：
- 构建：2-3 分钟（依赖缓存后约 30s）
- 传输：200MB tar 包约 3 分钟
- 启动 + 健康检查：30-60s

---

## 🌐 配置 Nginx 反代（首次部署后做一次）

```bash
ssh ubuntu@1.2.3.4 << 'REMOTE'
  # 1. 修改域名（搜 YOUR_DOMAIN.com 并替换）
  sudo cp /opt/new-api/config/nginx.conf /etc/nginx/sites-available/new-api
  sudo vim /etc/nginx/sites-available/new-api
  # 把 api.YOUR_DOMAIN.com 改成你的实际域名
  # 取消注释 /panel 的 IP 白名单并填入你的 IP

  # 2. 启用配置
  sudo ln -sfn /etc/nginx/sites-available/new-api /etc/nginx/sites-enabled/new-api

  # 3. 禁用默认 site（如果存在）
  sudo rm -f /etc/nginx/sites-enabled/default

  # 4. 测试 + 重载
  sudo nginx -t
  sudo systemctl reload nginx
REMOTE
```

测试访问：

```bash
curl -I https://api.your-domain.com/api/status
# 期望返回 200 OK + JSON 中含 "success":true
```

---

## 🔄 后续发布

任何代码变更后：

```bash
# 1. 跟随上游（可选）
bash custom/scripts/merge-upstream.sh

# 2. 提交你的改动
git add -A && git commit -m "feat: ..."
git push origin develop

# 3. 一键部署
bash custom/scripts/deploy-cn.sh
```

---

## 🔧 常用命令

### 仅重传镜像（跳过构建）

```bash
bash custom/scripts/deploy-cn.sh --skip-build
```

### 回滚到指定版本

```bash
# 服务器上保留了最近 7 天的镜像 tar 包
ssh ubuntu@1.2.3.4 ls /opt/new-api/images/

bash custom/scripts/deploy-cn.sh --tag <git-sha>
```

### 仅本地构建（不发布）

```bash
bash custom/scripts/build-image.sh
# 产物在 dist/
```

### 查看服务器日志

```bash
ssh ubuntu@1.2.3.4 'cd /opt/new-api && docker compose --env-file .env.production -f docker-compose.production.image.yml logs -f new-api'
```

### 手动备份数据库

```bash
ssh ubuntu@1.2.3.4 'docker exec new-api-prod-pg pg_dump -U root new-api | gzip > /opt/new-api/backup/manual-$(date +%Y%m%d).sql.gz'
```

### 恢复数据库

```bash
ssh ubuntu@1.2.3.4 'gunzip -c /opt/new-api/backup/postgres-20260521-120000.sql.gz | docker exec -i new-api-prod-pg psql -U root new-api'
```

---

## 🔍 中国网络优化说明

| 资源 | 实际使用源 | 备注 |
|---|---|---|
| Ubuntu apt | `mirrors.tencentyun.com`（内网） | 腾讯云内部免流量 |
| Docker CE 包 | `mirrors.tencentyun.com/docker-ce` | 同上 |
| Docker pull 加速 | `mirror.ccs.tencentyun.com` 等 4 源轮换 | 仅当方案 A 不适用时备用 |
| Go module | `goproxy.cn`（本机构建） | 7 倍速度提升 |
| npm/bun | `registry.npmmirror.com`（本机构建） | 同上 |
| Debian apt（容器内） | `mirrors.tuna.tsinghua.edu.cn` | 清华大学源 |
| Alpine apk | `mirrors.tuna.tsinghua.edu.cn` | 同上 |

---

## 🔒 安全建议

1. **SSH**：禁用密码登录，仅 key 登录
   ```bash
   ssh -t ubuntu@1.2.3.4 'sudo sed -i "s/^#*PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config && sudo systemctl restart ssh'
   ```
2. **管理端**：Nginx `/panel` 配置 IP 白名单
3. **数据库**：不开放 PostgreSQL 端口到外网（compose 默认就是这样）
4. **密钥**：`.env.production` chmod 600，并下载备份保管
5. **备份**：服务器自动保留 14 天 pg_dump，但建议每周下载一份到本地

---

## ❓ 故障排查

### 部署后健康检查失败 + 自动回滚

```bash
# 看日志
ssh ubuntu@1.2.3.4 'cd /opt/new-api && docker compose --env-file .env.production -f docker-compose.production.image.yml logs --tail=200 new-api'
```

常见原因：
- `.env.production` 中 `SQL_DSN` / `REDIS_CONN_STRING` 密码不匹配
- 数据库迁移失败（version mismatch）
- 端口 3000 已被占用

### Docker pull 超时（理论上方案 A 不会发生）

如果偶尔需要拉 image：

```bash
# daemon.json 已经配了 mirrors，重启 docker 即可
ssh -t ubuntu@1.2.3.4 'sudo systemctl restart docker'
```

### 容器频繁 OOM Kill

如果你升级了机型或日志大量增长导致内存吃紧：

```bash
# 查看内存使用
docker stats --no-stream

# 调整 docker-compose.production.image.yml 的 deploy.resources.limits
```

### SSL 证书续期

证书续期后只需替换 `/etc/ssl/new-api/{fullchain,privkey}.pem`：

```bash
scp /new/fullchain.pem /new/privkey.pem ubuntu@1.2.3.4:/tmp/
ssh -t ubuntu@1.2.3.4 'sudo mv /tmp/*.pem /etc/ssl/new-api/ && sudo systemctl reload nginx'
```

---

## 📞 联系

- 项目仓库：（私有 fork）
- 上游：https://github.com/Calcium-Ion/new-api
- 部署相关：见 `custom/scripts/*.sh` 内联注释
