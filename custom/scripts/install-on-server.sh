#!/bin/bash
# ============================================================
# install-on-server.sh — 服务器端安装/升级脚本
#
# 由 deploy-cn.sh 自动通过 SSH 调用，也可手动运行
#
# 用法：
#   bash install-on-server.sh <image-tag>
#   bash install-on-server.sh xiang-api-abc12345.tar.gz   # 指定 tar 文件
#
# 执行流程：
#   1. 数据库备份（pg_dump → /opt/new-api/backup/）
#   2. docker load 新镜像
#   3. 记录当前运行 tag（用于回滚）
#   4. 更新 .env.production 的 IMAGE_TAG
#   5. docker compose up -d
#   6. 等待 + 健康检查
#   7. 失败则自动回滚到上一版本
#   8. 清理 7 天前的镜像/备份
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
DEPLOY_DIR="/opt/new-api"
COMPOSE_FILE="$DEPLOY_DIR/docker-compose.production.image.yml"
ENV_FILE="$DEPLOY_DIR/.env.production"
IMAGES_DIR="$DEPLOY_DIR/images"
BACKUP_DIR="$DEPLOY_DIR/backup"
PREV_TAG_FILE="$DEPLOY_DIR/.previous-tag"
CURRENT_TAG_FILE="$DEPLOY_DIR/.current-tag"

# ── 前置检查 ────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  err "未安装 Docker，请先运行 setup-server-cn.sh"
  exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
  err "找不到 $COMPOSE_FILE（应由 deploy-cn.sh 同步上来）"
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  err "找不到 $ENV_FILE（应由 setup-server-cn.sh 生成）"
  exit 1
fi

# ── 解析参数 ───────────────────────────────────────────────
ARG="${1:?用法: bash install-on-server.sh <image-tag-或-tar文件名>}"

if [[ "$ARG" == *.tar.gz ]]; then
  TAR_FILE="$IMAGES_DIR/$ARG"
  # 从文件名提取 tag：xiang-api-<sha>.tar.gz → <sha>
  NEW_TAG="$(basename "$ARG" .tar.gz | sed 's/^xiang-api-//')"
else
  NEW_TAG="$ARG"
  TAR_FILE="$IMAGES_DIR/xiang-api-${NEW_TAG}.tar.gz"
fi

if [ ! -f "$TAR_FILE" ]; then
  err "找不到镜像文件：$TAR_FILE"
  exit 1
fi

NEW_IMAGE="xiang-api:${NEW_TAG}"

echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}  象汇 API 服务器端安装             ${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""
log "新镜像：$NEW_IMAGE"
log "Tar 文件：$TAR_FILE"
echo ""

# ── 记录当前 tag 用于回滚 ──────────────────────────────────
PREV_TAG=""
if [ -f "$CURRENT_TAG_FILE" ]; then
  PREV_TAG="$(cat "$CURRENT_TAG_FILE")"
  log "当前运行版本：$PREV_TAG（将作为回滚目标）"
else
  log "首次部署，无回滚目标"
fi

# ── 1. 数据库备份 ──────────────────────────────────────────
log "1/7 数据库备份"

mkdir -p "$BACKUP_DIR"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/postgres-${TIMESTAMP}.sql.gz"

if docker ps --format '{{.Names}}' | grep -q '^new-api-prod-pg$'; then
  log "运行 pg_dump..."
  if docker exec new-api-prod-pg pg_dump -U root new-api 2>/dev/null | gzip > "$BACKUP_FILE"; then
    SIZE="$(du -h "$BACKUP_FILE" | cut -f1)"
    ok "备份完成：$BACKUP_FILE ($SIZE)"
  else
    warn "pg_dump 失败（可能首次部署）"
    rm -f "$BACKUP_FILE"
  fi
else
  log "PostgreSQL 容器未运行（首次部署），跳过备份"
fi

# ── 2. docker load ─────────────────────────────────────────
echo ""
log "2/7 加载镜像：$TAR_FILE"
gunzip -c "$TAR_FILE" | docker load
ok "镜像加载完成"

# 验证镜像存在
if ! docker image inspect "$NEW_IMAGE" &>/dev/null; then
  err "加载后找不到镜像 $NEW_IMAGE，请检查 tar 文件"
  exit 1
fi

# ── 3. 更新 .env.production 的 IMAGE_TAG ───────────────────
echo ""
log "3/7 更新 .env.production 的 IMAGE_TAG"
if grep -q "^IMAGE_TAG=" "$ENV_FILE"; then
  sed -i "s|^IMAGE_TAG=.*|IMAGE_TAG=${NEW_TAG}|" "$ENV_FILE"
else
  echo "IMAGE_TAG=${NEW_TAG}" >> "$ENV_FILE"
fi
ok "IMAGE_TAG=$NEW_TAG"

# ── 4. 启动新版本 ──────────────────────────────────────────
echo ""
log "4/7 启动新版本（docker compose up -d）"
cd "$DEPLOY_DIR"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --remove-orphans

# ── 5. 健康检查 ────────────────────────────────────────────
echo ""
log "5/7 健康检查（最长等待 90s）"

HEALTHY=0
for i in {1..45}; do
  sleep 2
  if curl -fsS --max-time 3 http://127.0.0.1:3000/api/status 2>/dev/null | grep -q '"success":\s*true'; then
    HEALTHY=1
    ok "健康检查通过（第 ${i} 次尝试）"
    break
  fi
  echo -n "."
done
echo ""

# ── 6. 失败回滚 ────────────────────────────────────────────
if [ "$HEALTHY" -eq 0 ]; then
  err "健康检查失败！"

  echo ""
  log "最近 50 行日志："
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" logs --tail=50 new-api || true

  if [ -n "$PREV_TAG" ] && docker image inspect "xiang-api:${PREV_TAG}" &>/dev/null; then
    echo ""
    warn "开始自动回滚到 $PREV_TAG"

    sed -i "s|^IMAGE_TAG=.*|IMAGE_TAG=${PREV_TAG}|" "$ENV_FILE"
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d

    log "回滚等待 30s..."
    sleep 30

    if curl -fsS --max-time 3 http://127.0.0.1:3000/api/status 2>/dev/null | grep -q '"success":\s*true'; then
      ok "回滚成功，服务已恢复到 $PREV_TAG"
      exit 2  # exit code 2 表示新版本失败但已回滚
    else
      err "回滚也失败！请人工介入"
      exit 3
    fi
  else
    err "无可回滚版本，请人工排查"
    exit 1
  fi
fi

# ── 7. 标记当前 tag、清理 ───────────────────────────────────
echo ""
log "6/7 标记版本"
[ -n "$PREV_TAG" ] && echo "$PREV_TAG" > "$PREV_TAG_FILE"
echo "$NEW_TAG" > "$CURRENT_TAG_FILE"
ok "current=$NEW_TAG, previous=$PREV_TAG"

echo ""
log "7/7 清理 7 天前的镜像和备份"

# 清理旧 tar 包
find "$IMAGES_DIR" -name "xiang-api-*.tar.gz" -mtime +7 -print -delete || true
find "$IMAGES_DIR" -name "xiang-api-*.meta.json" -mtime +7 -print -delete || true

# 清理旧备份
find "$BACKUP_DIR" -name "postgres-*.sql.gz" -mtime +14 -print -delete || true

# 清理悬空 docker 镜像
docker image prune -f >/dev/null

ok "清理完成"

# ── 总结 ────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}  ✅ 部署成功                       ${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""
echo "当前版本: $NEW_TAG"
echo "前一版本: ${PREV_TAG:-（首次部署）}"
echo ""
echo "常用命令："
echo "  查看日志:   docker compose --env-file $ENV_FILE -f $COMPOSE_FILE logs -f new-api"
echo "  重启:       docker compose --env-file $ENV_FILE -f $COMPOSE_FILE restart new-api"
echo "  停止:       docker compose --env-file $ENV_FILE -f $COMPOSE_FILE down"
echo "  状态:       docker compose --env-file $ENV_FILE -f $COMPOSE_FILE ps"
echo ""
