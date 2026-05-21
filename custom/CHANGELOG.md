# Custom Changelog

## [v0.0.2-elephant-1] - 2026-05-21

### UI 主题：Google Material Design 3
- 新增 `custom/frontend/styles/google-m3-theme.css`，按 M3 规范覆盖颜色、圆角、阴影、字体
  - 主色 #4285F4（Google Blue）+ M3 色调阶梯
  - 字体 Inter / Roboto / Roboto Mono（Google Sans 等价替代）
  - 圆角 14px 基准，按钮/Tab/Nav 改为药丸形
  - 卡片/对话框采用 M3 elevation-1~4 阴影
  - 完整深色模式 M3 调色板
- 注入方式（零侵入：1 处锚点 + 1 处 symlink）
  - `web/default/public/custom-theme.css` → symlink 到 custom/ 中的 CSS（新增文件，不冲突）
  - `web/default/index.html` 注入 `<link rel="stylesheet" href="/custom-theme.css">`，用 `<!-- CUSTOM:THEME-OVERLAY:BEGIN/END -->` 标记块包裹
- 新增 `custom/scripts/apply-patches.sh`：幂等地重新应用所有上游文件最小补丁
- 升级 `custom/scripts/merge-upstream.sh`：上游合并后自动调用 apply-patches.sh 并自动提交
- 更新 `custom/config/branding.json` primary_color → #4285F4

### 首页重写
- 新增 `custom/content/homepage-m3.html`：完整 M3 风格首页
  - Hero、Stats、Features、Models、CTA 五个区块
  - SVG 线条图标替代 emoji
  - 所有样式使用 `--m3-*` CSS 变量，与全站主题统一
  - 响应式布局 + 深色模式自动适配

### 文档页面
- 新增 `web/default/src/routes/docs/index.tsx` 和 `web/default/src/features/docs/index.tsx`
  - 快速开始（3 步引导）
  - API 接口文档（Base URL、认证、Chat Completions、流式响应）
  - SDK 示例（Python、Node.js、cURL）
  - 常见问题（5 个 FAQ）
  - 统一 M3 设计风格

### 导航优化
- 统一所有页面头部导航高度为 64px（M3 标准 app bar）
- 移除控制台顶部搜索框
- 统一导航链接：主页 | 控制台 | 模型广场 | 文档 | 关于我们
- 数据库配置 `HeaderNavModules` 支持动态控制导航显示

### 自动化部署
- 新增 `custom/scripts/deploy.sh`：一键部署脚本（支持 dev/staging/production）
- 新增 `custom/scripts/setup-server.sh`：服务器初始化脚本（自动安装 Docker、Nginx、生成密钥）
- 新增 `docker-compose.production.yml`：生产环境 Docker Compose 配置
- 新增 `.env.production.example`：生产环境变量模板
- 新增 `custom/config/nginx.conf`：Nginx 生产配置（含 SSL、速率限制、管理端保护）
- 新增 `custom/docs/DEPLOYMENT.md`：完整部署文档

### 安全增强
- 生产配置强制修改所有默认密码
- Nginx 配置管理端 IP 白名单
- API 端点速率限制（100 req/s）
- SSL/TLS 最佳实践配置

## [v0.0.1-elephant-1] - 2026-05-19

### 初始化
- Fork 自 Calcium-Ion/new-api (commit: 146dd77b)
- 建立 develop 分支用于二次开发
- 创建 custom/ 目录结构
- 配置 upstream 远程仓库
