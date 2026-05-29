#!/bin/bash
# ============================================================
# build-image.sh — 本机构建 Docker 镜像并打包成 tar.gz
#
# 用法：
#   bash custom/scripts/build-image.sh           # 默认 linux/amd64
#   bash custom/scripts/build-image.sh --arm64   # 构建 arm64
#
# 输出：
#   dist/xiang-api-<git-sha>.tar.gz
#
# 设计：
#   - 自动执行 apply-patches.sh 确保定制已应用
#   - 用 custom/build/Dockerfile.cn（含国内镜像加速）
#   - 镜像 tag = xiang-api:<git-short-sha>
#   - 同时打 xiang-api:latest 标签
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

# ── 解析参数 ───────────────────────────────────────────────
PLATFORM="linux/amd64"
if [[ "${1:-}" == "--arm64" ]]; then
  PLATFORM="linux/arm64"
fi

# ── 路径 ────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOCKERFILE="$REPO_ROOT/custom/build/Dockerfile.cn"
DIST_DIR="$REPO_ROOT/dist"

cd "$REPO_ROOT"

# ── 前置检查 ────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  err "未安装 Docker"
  exit 1
fi

if ! docker buildx version &>/dev/null; then
  err "未启用 buildx，请升级 Docker Desktop 或运行 docker buildx install"
  exit 1
fi

if [ ! -f "$DOCKERFILE" ]; then
  err "找不到 $DOCKERFILE"
  exit 1
fi

# ── git 状态校验 ───────────────────────────────────────────
log "校验 git 工作区状态"
if [ -n "$(git status --porcelain)" ]; then
  warn "工作区有未提交的改动："
  git status --short
  read -rp "继续构建（产物会包含这些改动）？(y/N) " ans
  [[ "${ans,,}" == "y" ]] || exit 1
fi

GIT_SHA="$(git rev-parse --short=8 HEAD)"
GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
BUILD_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
VERSION="$(cat VERSION 2>/dev/null || echo "0.0.0")"

log "构建信息："
echo "  分支:     $GIT_BRANCH"
echo "  Commit:   $GIT_SHA"
echo "  Version:  $VERSION"
echo "  Platform: $PLATFORM"

# ── 1. 应用 custom patches ─────────────────────────────────
echo ""
log "1/4 应用 custom patches"
if [ -f "custom/scripts/apply-patches.sh" ]; then
  bash custom/scripts/apply-patches.sh
else
  warn "找不到 apply-patches.sh，跳过"
fi

# ── 2. Docker buildx 构建 ──────────────────────────────────
echo ""
log "2/4 docker buildx build (--platform $PLATFORM)"

IMAGE_NAME="xiang-api"
FULL_TAG="${IMAGE_NAME}:${GIT_SHA}"
LATEST_TAG="${IMAGE_NAME}:latest"

# 确保有可用 builder
docker buildx ls | grep -q "default.*running" || docker buildx use default

docker buildx build \
  --platform "$PLATFORM" \
  --file "$DOCKERFILE" \
  --tag "$FULL_TAG" \
  --tag "$LATEST_TAG" \
  --load \
  "$REPO_ROOT"

ok "镜像构建完成：$FULL_TAG"

# ── 3. docker save ─────────────────────────────────────────
echo ""
log "3/4 docker save → tar.gz"

mkdir -p "$DIST_DIR"
TAR_FILE="$DIST_DIR/xiang-api-${GIT_SHA}.tar.gz"

if [ -f "$TAR_FILE" ]; then
  warn "已存在 $TAR_FILE，覆盖"
fi

# 用 gzip -1 平衡压缩比与速度（约 30% 比例，更快）
docker save "$FULL_TAG" "$LATEST_TAG" | gzip -1 > "$TAR_FILE"

SIZE_HUMAN="$(du -h "$TAR_FILE" | cut -f1)"
ok "镜像导出完成：$TAR_FILE ($SIZE_HUMAN)"

# ── 4. 写元数据 ────────────────────────────────────────────
echo ""
log "4/4 生成构建元数据"

META_FILE="$DIST_DIR/xiang-api-${GIT_SHA}.meta.json"
cat > "$META_FILE" <<EOF
{
  "image_name": "$IMAGE_NAME",
  "image_tag": "$GIT_SHA",
  "full_image_ref": "$FULL_TAG",
  "version": "$VERSION",
  "git_sha": "$GIT_SHA",
  "git_branch": "$GIT_BRANCH",
  "build_time": "$BUILD_TIME",
  "platform": "$PLATFORM",
  "tar_file": "$(basename "$TAR_FILE")",
  "tar_size": "$SIZE_HUMAN",
  "tar_sha256": "$(shasum -a 256 "$TAR_FILE" | awk '{print $1}')"
}
EOF

ok "元数据：$META_FILE"

# ── 总结 ────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}====================================${NC}"
echo -e "${GREEN}  ✅ 构建完成                       ${NC}"
echo -e "${GREEN}====================================${NC}"
echo ""
echo "镜像 Tag:  $FULL_TAG"
echo "Tar 文件:  $TAR_FILE"
echo "大小:      $SIZE_HUMAN"
echo ""
echo "下一步部署到服务器："
echo "  bash custom/scripts/deploy-cn.sh"
echo ""

# ── 输出 tag 供外部脚本读取 ────────────────────────────────
echo "$GIT_SHA" > "$DIST_DIR/.latest-tag"
