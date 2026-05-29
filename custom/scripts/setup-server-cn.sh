#!/bin/bash
# ============================================================
# setup-server-cn.sh — 中国服务器一次性初始化脚本
#
# 适用：腾讯云轻量应用服务器 (Lighthouse) / Ubuntu Server 24.04 LTS
# 用法：sudo bash setup-server-cn.sh
#
# 执行内容：
#   1. 切换 apt 到腾讯云内网源（免流量、加速）
#   2. 升级系统 + 安装基础工具
#   3. 用腾讯云源安装 Docker CE + Compose 插件
#   4. 写入 daemon.json（registry-mirrors 多源加速）
#   5. 安装 Nginx
#   6. 配置 UFW 防火墙（系统层）
#   7. 创建 /opt/new-api 部署目录树
#   8. 生成 .env.production（含强随机密钥）
#   9. 把当前/SUDO 用户加入 docker 组
#
# 幂等：可重复执行，不会破坏已有配置
# ============================================================

set -euo pipefail

# ── 颜色输出 ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[FAIL]${NC} $*" >&2; }

# ── 前置检查 ────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
  err "请用 sudo 运行此脚本：sudo bash $0"
  exit 1
fi

if ! grep -q "Ubuntu 24" /etc/os-release; then
  warn "未检测到 Ubuntu 24.04，脚本针对 24.04 设计，继续执行可能有兼容性问题"
  read -rp "是否继续？(y/N) " ans
  [[ "${ans,,}" == "y" ]] || exit 1
fi

DEPLOY_DIR="/opt/new-api"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../config"

echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}  象汇 API 服务器初始化（腾讯云）   ${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""

# ── 1. 切换 apt 源到腾讯云内网 ──────────────────────────────
log "1/9 切换 apt 源到腾讯云内网（mirrors.tencentyun.com）"

if [ -f "$CONFIG_DIR/sources.list.noble" ]; then
  # 备份原始源
  if [ -f /etc/apt/sources.list.d/ubuntu.sources ] && [ ! -f /etc/apt/sources.list.d/ubuntu.sources.bak ]; then
    cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.bak
    log "已备份默认 sources：/etc/apt/sources.list.d/ubuntu.sources.bak"
  fi

  # 禁用默认源
  if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
    mv /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.disabled
  fi

  cp "$CONFIG_DIR/sources.list.noble" /etc/apt/sources.list.d/tencentyun.sources
  ok "已写入 /etc/apt/sources.list.d/tencentyun.sources"
else
  warn "找不到 $CONFIG_DIR/sources.list.noble，跳过源切换"
fi

# ── 2. 系统更新 + 基础工具 ──────────────────────────────────
log "2/9 更新软件源并安装基础工具"
apt-get update
apt-get upgrade -y
apt-get install -y --no-install-recommends \
  ca-certificates curl wget gnupg lsb-release \
  vim htop tree jq tzdata \
  ufw nginx \
  openssl unzip \
  rsync
ok "基础工具安装完成"

# 设置时区
timedatectl set-timezone Asia/Shanghai || true

# ── 3. 安装 Docker CE（腾讯云源）────────────────────────────
log "3/9 安装 Docker CE"

if command -v docker &>/dev/null; then
  ok "Docker 已安装：$(docker --version)"
else
  install -m 0755 -d /etc/apt/keyrings

  # 优先用腾讯云镜像的 GPG key，失败则回落官方
  if curl -fsSL --connect-timeout 10 https://mirrors.tencentyun.com/docker-ce/linux/ubuntu/gpg \
       -o /etc/apt/keyrings/docker.asc; then
    log "从腾讯云镜像获取 Docker GPG key"
  else
    warn "腾讯云源不可达，回落到 mirrors.aliyun.com"
    curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg \
         -o /etc/apt/keyrings/docker.asc
  fi
  chmod a+r /etc/apt/keyrings/docker.asc

  # 添加 Docker apt 源
  if curl -fsSL --connect-timeout 5 https://mirrors.tencentyun.com/docker-ce/linux/ubuntu/dists/ &>/dev/null; then
    DOCKER_REPO="https://mirrors.tencentyun.com/docker-ce/linux/ubuntu"
  else
    DOCKER_REPO="https://mirrors.aliyun.com/docker-ce/linux/ubuntu"
  fi

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
        $DOCKER_REPO $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  systemctl enable docker
  systemctl start docker
  ok "Docker 安装完成：$(docker --version)"
fi

# ── 4. 配置 Docker daemon.json ─────────────────────────────
log "4/9 配置 Docker 镜像加速"

mkdir -p /etc/docker

if [ -f /etc/docker/daemon.json ] && [ ! -f /etc/docker/daemon.json.bak ]; then
  cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
  log "已备份原 daemon.json：/etc/docker/daemon.json.bak"
fi

if [ -f "$CONFIG_DIR/daemon.json" ]; then
  cp "$CONFIG_DIR/daemon.json" /etc/docker/daemon.json
  systemctl restart docker
  ok "Docker daemon 重启完成（registry-mirrors 已生效）"
else
  warn "找不到 $CONFIG_DIR/daemon.json，跳过"
fi

# ── 5. Nginx ───────────────────────────────────────────────
log "5/9 配置 Nginx"
if ! systemctl is-enabled --quiet nginx; then
  systemctl enable nginx
fi
systemctl start nginx || true

# 添加全局 rate-limit zone（nginx.conf 里引用）
LIMIT_CONF="/etc/nginx/conf.d/00-limit-req.conf"
if [ ! -f "$LIMIT_CONF" ]; then
  cat > "$LIMIT_CONF" <<'EOF'
# 全局 API 速率限制 zone（被 sites-available/new-api 引用）
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=100r/s;
EOF
  ok "已写入 $LIMIT_CONF"
fi

# 创建证书目录
mkdir -p /etc/ssl/new-api
chmod 700 /etc/ssl/new-api
ok "Nginx + SSL 证书目录就绪：/etc/ssl/new-api/"

# ── 6. UFW 防火墙 ──────────────────────────────────────────
log "6/9 配置 UFW 防火墙"
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw --force enable
ok "UFW 防火墙已启用：22/80/443"

warn "提醒：腾讯云轻量服务器还有一层【控制台防火墙】，"
warn "       请到控制台 → 实例 → 防火墙规则，确认已开放 80 和 443"

# ── 7. 部署目录 ────────────────────────────────────────────
log "7/9 创建部署目录树"
mkdir -p "$DEPLOY_DIR"/{data,logs,images,backup,config}
chown -R "${SUDO_USER:-root}:${SUDO_USER:-root}" "$DEPLOY_DIR"
ok "部署目录：$DEPLOY_DIR/{data,logs,images,backup,config}"

# ── 8. 生成 .env.production ────────────────────────────────
log "8/9 生成 .env.production"

ENV_FILE="$DEPLOY_DIR/.env.production"
if [ -f "$ENV_FILE" ]; then
  warn "已存在 $ENV_FILE，跳过生成（如需重新生成请先删除）"
else
  SESSION_SECRET="$(openssl rand -base64 32 | tr -d '\n')"
  ENCRYPT_KEY="$(openssl rand -base64 32 | tr -d '\n')"
  POSTGRES_PASSWORD="$(openssl rand -base64 24 | tr -d '\n=+/' | cut -c1-32)"
  REDIS_PASSWORD="$(openssl rand -base64 24 | tr -d '\n=+/' | cut -c1-32)"

  cat > "$ENV_FILE" <<EOF
# ============================================================
# 象汇 API 生产环境变量（由 setup-server-cn.sh 自动生成）
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
# 主机: $(hostname)
# ============================================================

# ── 镜像版本（由 deploy-cn.sh 自动更新）────────────────────
IMAGE_TAG=latest

# ── 数据库配置 ─────────────────────────────────────────────
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
SQL_DSN=postgresql://root:${POSTGRES_PASSWORD}@postgres:5432/new-api

# ── Redis 配置 ─────────────────────────────────────────────
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_CONN_STRING=redis://:${REDIS_PASSWORD}@redis:6379

# ── 安全密钥 ───────────────────────────────────────────────
SESSION_SECRET=${SESSION_SECRET}
ENCRYPT_KEY=${ENCRYPT_KEY}

# ── 应用配置 ───────────────────────────────────────────────
TZ=Asia/Shanghai
LOG_LEVEL=info
BATCH_UPDATE_ENABLED=true

# ── 公开访问地址（部署后改成你的域名）──────────────────────
SERVER_ADDRESS=https://api.YOUR_DOMAIN.com

# ── SMTP（可选，按需填写）──────────────────────────────────
# SMTP_SERVER=smtp.example.com
# SMTP_PORT=587
# SMTP_USERNAME=
# SMTP_PASSWORD=
# SMTP_FROM=

# ── OAuth（可选）───────────────────────────────────────────
# GITHUB_CLIENT_ID=
# GITHUB_CLIENT_SECRET=
EOF
  chmod 600 "$ENV_FILE"
  ok "已生成 $ENV_FILE（已设置 chmod 600）"
fi

# ── 9. 用户组 ──────────────────────────────────────────────
log "9/9 将用户加入 docker 组"
TARGET_USER="${SUDO_USER:-root}"
if [ "$TARGET_USER" != "root" ]; then
  usermod -aG docker "$TARGET_USER"
  ok "用户 $TARGET_USER 已加入 docker 组（需重新登录生效）"
fi

# ── 总结 ───────────────────────────────────────────────────
echo ""
echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}  ✅ 服务器初始化完成              ${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""
echo "下一步（在你的 Mac 本机）："
echo ""
echo "  1. 上传 SSL 证书到服务器："
echo "     scp fullchain.pem privkey.pem $TARGET_USER@<HOST>:/tmp/"
echo "     ssh $TARGET_USER@<HOST> 'sudo mv /tmp/fullchain.pem /tmp/privkey.pem /etc/ssl/new-api/'"
echo ""
echo "  2. 编辑 .env.deploy（本机），填入服务器信息"
echo ""
echo "  3. 执行部署："
echo "     bash custom/scripts/deploy-cn.sh"
echo ""
echo -e "${YELLOW}重要提醒：${NC}"
echo "  • 腾讯云控制台防火墙：请确认已开放 80/443 端口"
echo "  • SSL 证书：服务器只读取 /etc/ssl/new-api/{fullchain,privkey}.pem"
echo "  • 配置文件：$DEPLOY_DIR/.env.production（已生成，含强密码）"
echo "  • 请下载备份：scp $TARGET_USER@<HOST>:$ENV_FILE ./backup-env-$(date +%Y%m%d).txt"
echo ""
