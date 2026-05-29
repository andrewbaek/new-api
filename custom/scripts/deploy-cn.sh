#!/bin/bash
# ============================================================
# deploy-cn.sh — 主部署入口（本机运行）
#
# 自动完成：
#   1. 读取 .env.deploy 配置
#   2. 调用 build-image.sh 构建镜像并打 tar 包
#   3. rsync 镜像 tar + compose 文件 + nginx.conf 到服务器
#   4. SSH 触发 install-on-server.sh
#   5. 输出部署结果
#
# 用法：
#   bash custom/scripts/deploy-cn.sh                     # 用 .env.deploy
#   bash custom/scripts/deploy-cn.sh --host user@1.2.3.4 # 覆盖目标
#   bash custom/scripts/deploy-cn.sh --skip-build        # 用最近一次构建
#   bash custom/scripts/deploy-cn.sh --tag <sha>         # 部署指定 tag
# ============================================================

set -euo pipefail

# ── 颜色 ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[FAIL]${NC} $*" >&2; }

# ── 路径 ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DIST_DIR="$REPO_ROOT/dist"
ENV_DEPLOY="$REPO_ROOT/.env.deploy"

cd "$REPO_ROOT"

# ── 加载 .env.deploy ───────────────────────────────────────
if [ -f "$ENV_DEPLOY" ]; then
  log "加载 $ENV_DEPLOY"
  # shellcheck disable=SC1090
  set -a; source "$ENV_DEPLOY"; set +a
else
  warn "找不到 $ENV_DEPLOY，请从 .env.deploy.example 复制并填写"
fi

# ── 解析参数 ───────────────────────────────────────────────
SKIP_BUILD=0
EXPLICIT_TAG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      DEPLOY_HOST="$2"; shift 2 ;;
    --skip-build)
      SKIP_BUILD=1; shift ;;
    --tag)
      EXPLICIT_TAG="$2"; SKIP_BUILD=1; shift 2 ;;
    -h|--help)
      grep -E "^# " "$0" | head -25 | sed 's/^# //'
      exit 0 ;;
    *)
      err "未知参数: $1"; exit 1 ;;
  esac
done

# ── 校验目标主机 ───────────────────────────────────────────
DEPLOY_HOST="${DEPLOY_HOST:-${DEPLOY_USER:-root}@${DEPLOY_SERVER:-YOUR_HOST}}"

if [[ "$DEPLOY_HOST" == *YOUR_HOST* ]]; then
  err "未配置部署目标，请：1) 编辑 .env.deploy 设置 DEPLOY_SERVER；或 2) 用 --host 参数"
  exit 1
fi

DEPLOY_PORT="${DEPLOY_PORT:-22}"
DEPLOY_REMOTE_DIR="${DEPLOY_REMOTE_DIR:-/opt/new-api}"

log "部署目标: $DEPLOY_HOST:$DEPLOY_PORT → $DEPLOY_REMOTE_DIR"

# ── 校验 SSH 连通性 ───────────────────────────────────────
log "校验 SSH 连通性"
if ! ssh -p "$DEPLOY_PORT" -o ConnectTimeout=10 -o BatchMode=yes "$DEPLOY_HOST" "echo connected" &>/dev/null; then
  err "无法 SSH 到 $DEPLOY_HOST:$DEPLOY_PORT（请确认：1) ssh 密钥已加到服务器；2) 端口正确；3) 防火墙放行）"
  exit 1
fi
ok "SSH 连接正常"

# ── 1. 构建（除非 --skip-build）────────────────────────────
if [ "$SKIP_BUILD" -eq 0 ]; then
  echo ""
  log "=== 步骤 1/4: 构建镜像 ==="
  bash "$SCRIPT_DIR/build-image.sh"
fi

# ── 确定要部署的 tag ───────────────────────────────────────
if [ -n "$EXPLICIT_TAG" ]; then
  IMAGE_TAG="$EXPLICIT_TAG"
elif [ -f "$DIST_DIR/.latest-tag" ]; then
  IMAGE_TAG="$(cat "$DIST_DIR/.latest-tag")"
else
  err "找不到 $DIST_DIR/.latest-tag，请先运行构建"
  exit 1
fi

TAR_FILE="$DIST_DIR/xiang-api-${IMAGE_TAG}.tar.gz"
META_FILE="$DIST_DIR/xiang-api-${IMAGE_TAG}.meta.json"

if [ ! -f "$TAR_FILE" ]; then
  err "找不到镜像文件：$TAR_FILE"
  exit 1
fi

SIZE="$(du -h "$TAR_FILE" | cut -f1)"
log "准备传输 $TAR_FILE ($SIZE)"

# ── 2. rsync 镜像 ──────────────────────────────────────────
echo ""
log "=== 步骤 2/4: rsync 镜像到服务器 ==="

# 确保远端目录存在（setup-server-cn.sh 已建好，但这里再保险一次）
ssh -p "$DEPLOY_PORT" "$DEPLOY_HOST" "mkdir -p $DEPLOY_REMOTE_DIR/images $DEPLOY_REMOTE_DIR/config"

rsync -azP \
  -e "ssh -p $DEPLOY_PORT" \
  --partial \
  "$TAR_FILE" "$META_FILE" \
  "$DEPLOY_HOST:$DEPLOY_REMOTE_DIR/images/"
ok "镜像 rsync 完成"

# ── 3. rsync compose + 安装脚本 + nginx 配置 ───────────────
echo ""
log "=== 步骤 3/4: rsync 配置文件 ==="

# compose 文件
rsync -az -e "ssh -p $DEPLOY_PORT" \
  "$REPO_ROOT/docker-compose.production.image.yml" \
  "$DEPLOY_HOST:$DEPLOY_REMOTE_DIR/"

# 安装脚本
rsync -az -e "ssh -p $DEPLOY_PORT" \
  "$REPO_ROOT/custom/scripts/install-on-server.sh" \
  "$DEPLOY_HOST:$DEPLOY_REMOTE_DIR/"
ssh -p "$DEPLOY_PORT" "$DEPLOY_HOST" "chmod +x $DEPLOY_REMOTE_DIR/install-on-server.sh"

# Nginx 配置（仅同步到 /opt/new-api/config/，是否启用由用户决定）
rsync -az -e "ssh -p $DEPLOY_PORT" \
  "$REPO_ROOT/custom/config/nginx.conf" \
  "$DEPLOY_HOST:$DEPLOY_REMOTE_DIR/config/nginx.conf"

ok "配置文件传输完成"

# ── 4. 远程执行 install-on-server.sh ───────────────────────
echo ""
log "=== 步骤 4/4: 远程触发安装 ==="

set +e
ssh -p "$DEPLOY_PORT" -t "$DEPLOY_HOST" \
  "cd $DEPLOY_REMOTE_DIR && bash install-on-server.sh $IMAGE_TAG"
INSTALL_EXIT=$?
set -e

# ── 处理结果 ───────────────────────────────────────────────
echo ""
case $INSTALL_EXIT in
  0)
    echo -e "${GREEN}====================================${NC}"
    echo -e "${GREEN}  ✅ 部署完全成功                   ${NC}"
    echo -e "${GREEN}====================================${NC}"
    echo ""
    echo "版本: $IMAGE_TAG"
    echo "主机: $DEPLOY_HOST"
    ;;
  2)
    echo -e "${YELLOW}====================================${NC}"
    echo -e "${YELLOW}  ⚠️  新版本健康检查失败，已自动回滚 ${NC}"
    echo -e "${YELLOW}====================================${NC}"
    exit 2
    ;;
  *)
    echo -e "${RED}====================================${NC}"
    echo -e "${RED}  ❌ 部署失败 (exit=$INSTALL_EXIT)  ${NC}"
    echo -e "${RED}====================================${NC}"
    echo ""
    echo "请 SSH 登录服务器查看日志："
    echo "  ssh -p $DEPLOY_PORT $DEPLOY_HOST"
    echo "  cd $DEPLOY_REMOTE_DIR"
    echo "  docker compose --env-file .env.production -f docker-compose.production.image.yml logs --tail=200"
    exit $INSTALL_EXIT
    ;;
esac
