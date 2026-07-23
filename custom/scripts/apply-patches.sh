#!/bin/bash
# ============================================================
# apply-patches.sh — 重新应用 custom/ 对上游文件的最小化补丁
#
# 何时运行：
#   - `bash custom/scripts/merge-upstream.sh` 之后（自动调用）
#   - 任何时候 web/index.html 被上游覆盖后
#
# 当前补丁清单：
#   1. web/index.html  注入 <link href="/custom-theme.css">
#   2. web/public/custom-theme.css  symlink 到 custom/frontend/styles/google-m3-theme.css
#
# 设计原则：
#   - 幂等：重复运行不会重复注入
#   - 标记块：所有插入用 <!-- CUSTOM:XXX:BEGIN/END --> 包裹
# ============================================================

set -e

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

echo "=== 1. 同步 custom-theme.css 软链接 ==="
mkdir -p web/public
if [ -L web/public/custom-theme.css ] || [ -e web/public/custom-theme.css ]; then
  rm -f web/public/custom-theme.css
fi
ln -s ../../custom/frontend/styles/google-m3-theme.css web/public/custom-theme.css
echo "✅ web/public/custom-theme.css → custom/frontend/styles/google-m3-theme.css"

echo ""
echo "=== 2. 注入 index.html <link> 标签 ==="
INDEX_HTML="web/index.html"
if grep -q "CUSTOM:THEME-OVERLAY:BEGIN" "$INDEX_HTML"; then
  echo "✅ index.html 已存在主题 link 补丁，跳过"
else
  awk '
    /<\/head>/ {
      print "    <!-- CUSTOM:THEME-OVERLAY:BEGIN — managed by custom/scripts/apply-patches.sh, do not remove -->"
      print "    <link rel=\"stylesheet\" href=\"/custom-theme.css\" id=\"custom-theme-overlay\" />"
      print "    <!-- CUSTOM:THEME-OVERLAY:END -->"
    }
    { print }
  ' "$INDEX_HTML" > "$INDEX_HTML.tmp" && mv "$INDEX_HTML.tmp" "$INDEX_HTML"
  echo "✅ 已注入 index.html <head> link 标签"
fi

echo ""
echo "=== 3. 注入 index.html cascade-reorder 脚本 ==="
if grep -q "CUSTOM:THEME-OVERLAY-REORDER:BEGIN" "$INDEX_HTML"; then
  echo "✅ index.html 已存在 reorder 脚本，跳过"
else
  awk '
    /<\/body>/ {
      print "    <!-- CUSTOM:THEME-OVERLAY-REORDER:BEGIN — managed by custom/scripts/apply-patches.sh, do not remove -->"
      print "    <script>"
      print "      // Rsbuild appends bundled CSS at end of <head> at build time, which would"
      print "      // cascade-beat any static <link> placed earlier. Move our overlay link to"
      print "      // the end of <head> after initial parse so it always wins."
      print "      (function () {"
      print "        var l = document.getElementById('\''custom-theme-overlay'\'');"
      print "        if (l && l.parentNode === document.head) {"
      print "          document.head.appendChild(l);"
      print "        }"
      print "      })();"
      print "    </script>"
      print "    <!-- CUSTOM:THEME-OVERLAY-REORDER:END -->"
    }
    { print }
  ' "$INDEX_HTML" > "$INDEX_HTML.tmp" && mv "$INDEX_HTML.tmp" "$INDEX_HTML"
  echo "✅ 已注入 index.html <body> reorder 脚本"
fi

echo ""
echo "✅ 所有自定义补丁已应用。"
