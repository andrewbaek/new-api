#!/bin/bash
# ============================================================
# deploy.sh — 象汇 API 自动化部署脚本
# 用法: bash custom/scripts/deploy.sh [环境]
# 环境: dev | staging | production (默认 production)
# ============================================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 环境参数
ENV=${1:-production}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${GREEN}=== 象汇 API 部署脚本 ===${NC}"
echo "环境: $ENV"
echo "项目目录: $PROJECT_ROOT"
echo ""

# 检查环境
if [[ ! "$ENV" =~ ^(dev|staging|production)$ ]]; then
  echo -e "${RED}错误: 环境参数必须是 dev, staging 或 production${NC}"
  exit 1
fi

# 检查 Docker
if ! command -v docker &> /dev/null; then
  echo -e "${RED}错误: 未安装 Docker${NC}"
  exit 1
fi

if ! command -v docker compose &> /dev/null; then
  echo -e "${RED}错误: 未安装 Docker Compose${NC}"
  exit 1
fi

# 检查配置文件
ENV_FILE="$PROJECT_ROOT/.env.$ENV"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.$ENV.yml"

if [ ! -f "$ENV_FILE" ]; then
  echo -e "${YELLOW}警告: 未找到 $ENV_FILE，将使用默认配置${NC}"
fi

if [ ! -f "$COMPOSE_FILE" ]; then
  echo -e "${RED}错误: 未找到 $COMPOSE_FILE${NC}"
  exit 1
fi

echo -e "${GREEN}=== 1. 拉取最新代码 ===${NC}"
cd "$PROJECT_ROOT"
git fetch origin
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "当前分支: $CURRENT_BRANCH"

if [ "$ENV" = "production" ]; then
  echo "切换到 main 分支..."
  git checkout main
  git pull origin main
else
  echo "切换到 develop 分支..."
  git checkout develop
  git pull origin develop
fi

echo ""
echo -e "${GREEN}=== 2. 应用自定义补丁 ===${NC}"
if [ -f "$PROJECT_ROOT/custom/scripts/apply-patches.sh" ]; then
  bash "$PROJECT_ROOT/custom/scripts/apply-patches.sh"
else
  echo -e "${YELLOW}警告: 未找到 apply-patches.sh，跳过${NC}"
fi

echo ""
echo -e "${GREEN}=== 3. 构建 Docker 镜像 ===${NC}"
docker compose -f "$COMPOSE_FILE" build --no-cache

echo ""
echo -e "${GREEN}=== 4. 停止旧容器 ===${NC}"
docker compose -f "$COMPOSE_FILE" down

echo ""
echo -e "${GREEN}=== 5. 启动新容器 ===${NC}"
if [ -f "$ENV_FILE" ]; then
  docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
else
  docker compose -f "$COMPOSE_FILE" up -d
fi

echo ""
echo -e "${GREEN}=== 6. 等待服务启动 ===${NC}"
sleep 10

echo ""
echo -e "${GREEN}=== 7. 检查服务状态 ===${NC}"
docker compose -f "$COMPOSE_FILE" ps

echo ""
echo -e "${GREEN}=== 8. 查看日志（最近 20 行）===${NC}"
docker compose -f "$COMPOSE_FILE" logs --tail=20 new-api

echo ""
echo -e "${GREEN}=== 9. 健康检查 ===${NC}"
CONTAINER_NAME="new-api-$ENV"
if docker ps | grep -q "$CONTAINER_NAME"; then
  echo -e "${GREEN}✅ 容器运行中${NC}"

  # 等待 API 就绪
  echo "等待 API 就绪..."
  for i in {1..30}; do
    if docker exec "$CONTAINER_NAME" wget -q -O- http://localhost:3000/api/status > /dev/null 2>&1; then
      echo -e "${GREEN}✅ API 健康检查通过${NC}"
      break
    fi
    if [ $i -eq 30 ]; then
      echo -e "${RED}❌ API 健康检查失败，请查看日志${NC}"
      docker compose -f "$COMPOSE_FILE" logs --tail=50 new-api
      exit 1
    fi
    sleep 2
  done
else
  echo -e "${RED}❌ 容器未运行${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}=== 10. 清理旧镜像 ===${NC}"
docker image prune -f

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ 部署完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "环境: $ENV"
echo "访问地址: http://localhost:3000 (请配置 Nginx 反向代理)"
echo ""
echo "常用命令:"
echo "  查看日志: docker compose -f $COMPOSE_FILE logs -f new-api"
echo "  重启服务: docker compose -f $COMPOSE_FILE restart new-api"
echo "  停止服务: docker compose -f $COMPOSE_FILE down"
echo "  进入容器: docker exec -it $CONTAINER_NAME sh"
echo ""
