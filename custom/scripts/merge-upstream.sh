#!/bin/bash
# ============================================================
# merge-upstream.sh — 合并上游 New API 最新代码到 develop
# 用法: bash custom/scripts/merge-upstream.sh
# ============================================================

set -e

echo "=== 1. 切换到 main 分支，拉取上游最新代码 ==="
git checkout main
git pull upstream main
git push origin main

echo ""
echo "=== 2. 切换到 develop，合并 main ==="
git checkout develop
git merge main --no-edit || true

echo ""
echo "=== 3. 检查冲突 ==="
CONFLICTS=$(git diff --name-only --diff-filter=U)
if [ -z "$CONFLICTS" ]; then
  echo "✅ 无冲突！"
else
  echo "⚠️ 以下文件存在冲突，请手动解决："
  echo "$CONFLICTS"
  echo ""
  echo "解决后执行: git add <文件> && git merge --continue"
  exit 1
fi

echo ""
echo "=== 4. 重新应用自定义补丁（主题 link、品牌注入等）==="
bash custom/scripts/apply-patches.sh

echo ""
echo "=== 5. 运行测试 ==="
# go test ./...  # 取消注释以启用测试

echo ""
echo "=== 6. 提交补丁更改（如有）==="
if [ -n "$(git status --porcelain web/default/index.html web/default/public/custom-theme.css 2>/dev/null)" ]; then
  git add web/default/index.html web/default/public/custom-theme.css
  git commit -m "chore(custom): re-apply theme overlay patches after upstream merge"
fi

echo ""
echo "=== 7. 推送 develop ==="
git push origin develop

echo ""
echo "✅ 合并完成！develop 已同步上游最新代码，自定义补丁已重新应用。"
