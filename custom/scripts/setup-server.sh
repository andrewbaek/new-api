#!/bin/bash
# ============================================================
# setup-server.sh — 服务器初始化脚本
# 用法: bash custom/scripts/setup-server.sh
# 适用: Ubuntu 20.04+ / Debian 11+
# ============================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== 象汇 API 服务器初始化 ===${NC}"
echo ""

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 权限运行此脚本: sudo bash setup-server.sh"
  exit 1
fi

echo -e "${GREEN}=== 1. 更新系统 ===${NC}"
apt-get update
apt-get upgrade -y

echo ""
echo -e "${GREEN}=== 2. 安装基础工具 ===${NC}"
apt-get install -y \
  curl \
  wget \
  git \
  vim \
  htop \
  ufw \
  certbot \
  python3-certbot-nginx

echo ""
echo -e "${GREEN}=== 3. 安装 Docker ===${NC}"
if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  rm get-docker.sh
  systemctl enable docker
  systemctl start docker
  echo "✅ Docker 安装完成"
else
  echo "✅ Docker 已安装"
fi

echo ""
echo -e "${GREEN}=== 4. 安装 Docker Compose ===${NC}"
if ! command -v docker compose &> /dev/null; then
  apt-get install -y docker-compose-plugin
  echo "✅ Docker Compose 安装完成"
else
  echo "✅ Docker Compose 已安装"
fi

echo ""
echo -e "${GREEN}=== 5. 安装 Nginx ===${NC}"
if ! command -v nginx &> /dev/null; then
  apt-get install -y nginx
  systemctl enable nginx
  systemctl start nginx
  echo "✅ Nginx 安装完成"
else
  echo "✅ Nginx 已安装"
fi

echo ""
echo -e "${GREEN}=== 6. 配置防火墙 ===${NC}"
ufw --force enable
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw status
echo "✅ 防火墙配置完成"

echo ""
echo -e "${GREEN}=== 7. 创建部署目录 ===${NC}"
mkdir -p /opt/new-api
chown -R $SUDO_USER:$SUDO_USER /opt/new-api
echo "✅ 部署目录: /opt/new-api"

echo ""
echo -e "${GREEN}=== 8. 生成随机密钥 ===${NC}"
SESSION_SECRET=$(openssl rand -base64 32)
ENCRYPT_KEY=$(openssl rand -base64 32)
POSTGRES_PASSWORD=$(openssl rand -base64 24)
REDIS_PASSWORD=$(openssl rand -base64 24)

echo ""
echo -e "${YELLOW}请保存以下密钥到安全的地方：${NC}"
echo ""
echo "SESSION_SECRET=$SESSION_SECRET"
echo "ENCRYPT_KEY=$ENCRYPT_KEY"
echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD"
echo "REDIS_PASSWORD=$REDIS_PASSWORD"
echo ""

# 保存到临时文件
cat > /tmp/new-api-secrets.txt <<EOF
# 象汇 API 密钥配置
# 生成时间: $(date)
# 请将这些值填入 .env.production 文件

SESSION_SECRET=$SESSION_SECRET
ENCRYPT_KEY=$ENCRYPT_KEY
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
REDIS_PASSWORD=$REDIS_PASSWORD
EOF

echo -e "${GREEN}密钥已保存到: /tmp/new-api-secrets.txt${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ 服务器初始化完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "下一步操作："
echo ""
echo "1. 克隆代码到服务器："
echo "   cd /opt/new-api"
echo "   git clone https://github.com/andrewbaek/new-api.git ."
echo "   git checkout main"
echo ""
echo "2. 配置环境变量："
echo "   cp .env.production.example .env.production"
echo "   vim .env.production"
echo "   # 填入上面生成的密钥"
echo ""
echo "3. 修改 Docker Compose 配置："
echo "   vim docker-compose.production.yml"
echo "   # 替换所有 CHANGE_THIS_* 为实际密码"
echo ""
echo "4. 配置 Nginx："
echo "   cp custom/config/nginx.conf /etc/nginx/sites-available/new-api"
echo "   # 修改域名和 IP 白名单"
echo "   ln -s /etc/nginx/sites-available/new-api /etc/nginx/sites-enabled/"
echo "   nginx -t"
echo "   systemctl reload nginx"
echo ""
echo "5. 申请 SSL 证书："
echo "   certbot --nginx -d api.yourdomain.com"
echo ""
echo "6. 部署应用："
echo "   bash custom/scripts/deploy.sh production"
echo ""
