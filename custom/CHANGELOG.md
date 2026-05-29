# Custom Changelog

## [v0.0.3-elephant-1] - 2026-05-21

### 中国服务器自动化部署（方案 A：本机构建 + 镜像传输）
- 新增 `custom/scripts/setup-server-cn.sh`：腾讯云轻量服务器一次性初始化
  - 切换 apt 到 `mirrors.tencentyun.com` 内网源
  - 用腾讯云源安装 Docker CE + Buildx + Compose
  - 写入 `daemon.json` 配 registry-mirrors 多源（mirror.ccs.tencentyun.com + 1ms.run + daocloud + dockerproxy）
  - 配置 UFW 防火墙（22/80/443）
  - 创建 `/opt/new-api/{data,logs,images,backup,config}` 目录树
  - 生成 `.env.production` 含强随机密钥
- 新增 `custom/build/Dockerfile.cn`：中国网络优化的 Dockerfile
  - bun 用 `registry.npmmirror.com`
  - go 用 `goproxy.cn`
  - alpine/debian apk/apt 用清华源
- 新增 `custom/scripts/build-image.sh`：本机构建并打 tar 包
  - linux/amd64 buildx
  - 自动调用 apply-patches.sh
  - 输出到 `dist/xiang-api-<git-sha>.tar.gz` + meta.json
- 新增 `custom/scripts/deploy-cn.sh`：主部署入口
  - 读 `.env.deploy` 配置
  - 调 build → rsync 镜像 + compose + 安装脚本 → SSH 触发
- 新增 `custom/scripts/install-on-server.sh`：服务器端安装
  - 自动 pg_dump 备份
  - docker load + compose up
  - 健康检查失败自动回滚到上一版本
  - 清理 7 天前镜像和 14 天前备份
- 新增 `docker-compose.production.image.yml`：image 版 compose
  - 用 `image: xiang-api:${IMAGE_TAG}` 替代 `build:`
  - 资源限制针对 2C4G 调优（new-api 1G / postgres 768M / redis 192M）
  - PostgreSQL 参数针对小内存重新计算
- 新增 `custom/config/sources.list.noble`：Ubuntu 24.04 腾讯云内网源
- 新增 `custom/config/daemon.json`：Docker 镜像加速配置
- 修改 `custom/config/nginx.conf`：
  - SSL 证书改用手动路径 `/etc/ssl/new-api/`（去 certbot 依赖）
  - 不依赖 `/etc/nginx/proxy_params`（24.04 不再默认提供）
  - 流式响应超时延长到 600s
- 新增 `.env.deploy.example`：部署配置模板（HOST/USER/PORT/REMOTE_DIR）
- 更新 `.gitignore`：忽略 `dist/`、`.env.deploy`、`.env.production`、镜像 tar 包
- 重写 `custom/docs/DEPLOYMENT.md`：China Edition 方案 A 完整工作流

### 设计原则
- **服务器零外网依赖**：除 apt 走腾讯云内网外，不需要访问 GitHub / Docker Hub / Go Proxy
- **上游跟随友好**：所有改动都在 `custom/` 下，不动上游 Dockerfile（用 `Dockerfile.cn` 副本）
- **失败自愈**：健康检查 + 自动回滚 + 备份保留
- **资源约束友好**：2C4G 轻量机型可稳定运行

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
