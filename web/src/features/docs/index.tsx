/*
Copyright (C) 2023-2026 QuantumNous

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.

For commercial licensing, please contact support@quantumnous.com
*/
import { Link } from '@tanstack/react-router'
import { PublicLayout } from '@/components/layout'

export function Docs() {
  return (
    <PublicLayout>
      <div className="docs-container">
        {/* Hero Section */}
        <section className="docs-hero">
          <div className="container">
            <h1 className="docs-title">API 文档</h1>
            <p className="docs-subtitle">
              快速开始使用象汇 API，接入主流大模型
            </p>
          </div>
        </section>

        {/* Quick Start */}
        <section className="docs-section">
          <div className="container">
            <h2 className="section-title">快速开始</h2>
            <div className="docs-grid">
              <div className="doc-card">
                <div className="doc-card-header">
                  <div className="doc-icon">1</div>
                  <h3 className="doc-card-title">获取 API Key</h3>
                </div>
                <p className="doc-card-description">
                  注册账号后，在控制台创建 API Key
                </p>
                <Link to="/sign-up" className="doc-link">
                  立即注册 →
                </Link>
              </div>

              <div className="doc-card">
                <div className="doc-card-header">
                  <div className="doc-icon">2</div>
                  <h3 className="doc-card-title">选择模型</h3>
                </div>
                <p className="doc-card-description">
                  查看支持的模型列表，选择适合您的模型
                </p>
                <Link to="/pricing" className="doc-link">
                  查看模型 →
                </Link>
              </div>

              <div className="doc-card">
                <div className="doc-card-header">
                  <div className="doc-icon">3</div>
                  <h3 className="doc-card-title">开始调用</h3>
                </div>
                <p className="doc-card-description">
                  使用标准 OpenAI SDK 或 HTTP 请求调用 API
                </p>
              </div>
            </div>
          </div>
        </section>

        {/* API Reference */}
        <section className="docs-section docs-section-alt">
          <div className="container">
            <h2 className="section-title">API 接口</h2>
            <div className="docs-content">
              <div className="api-block">
                <h3 className="api-title">Base URL</h3>
                <div className="code-block">
                  <code>https://api.yourdomain.com/v1</code>
                </div>
              </div>

              <div className="api-block">
                <h3 className="api-title">认证方式</h3>
                <p className="api-description">
                  在请求头中添加 Authorization 字段：
                </p>
                <div className="code-block">
                  <code>Authorization: Bearer YOUR_API_KEY</code>
                </div>
              </div>

              <div className="api-block">
                <h3 className="api-title">Chat Completions</h3>
                <p className="api-description">
                  创建聊天补全请求（兼容 OpenAI 格式）：
                </p>
                <div className="code-block">
                  <pre>{`POST /v1/chat/completions

{
  "model": "gpt-4o",
  "messages": [
    {
      "role": "user",
      "content": "Hello!"
    }
  ],
  "temperature": 0.7,
  "max_tokens": 1000
}`}</pre>
                </div>
              </div>

              <div className="api-block">
                <h3 className="api-title">流式响应</h3>
                <p className="api-description">
                  设置 stream: true 启用流式输出：
                </p>
                <div className="code-block">
                  <pre>{`{
  "model": "gpt-4o",
  "messages": [...],
  "stream": true
}`}</pre>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* SDK Examples */}
        <section className="docs-section">
          <div className="container">
            <h2 className="section-title">SDK 示例</h2>
            <div className="docs-content">
              <div className="sdk-block">
                <h3 className="sdk-title">Python</h3>
                <div className="code-block">
                  <pre>{`from openai import OpenAI

client = OpenAI(
    api_key="YOUR_API_KEY",
    base_url="https://api.yourdomain.com/v1"
)

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[
        {"role": "user", "content": "Hello!"}
    ]
)

print(response.choices[0].message.content)`}</pre>
                </div>
              </div>

              <div className="sdk-block">
                <h3 className="sdk-title">Node.js</h3>
                <div className="code-block">
                  <pre>{`import OpenAI from 'openai';

const client = new OpenAI({
  apiKey: 'YOUR_API_KEY',
  baseURL: 'https://api.yourdomain.com/v1',
});

const response = await client.chat.completions.create({
  model: 'gpt-4o',
  messages: [
    { role: 'user', content: 'Hello!' }
  ],
});

console.log(response.choices[0].message.content);`}</pre>
                </div>
              </div>

              <div className="sdk-block">
                <h3 className="sdk-title">cURL</h3>
                <div className="code-block">
                  <pre>{`curl https://api.yourdomain.com/v1/chat/completions \\
  -H "Content-Type: application/json" \\
  -H "Authorization: Bearer YOUR_API_KEY" \\
  -d '{
    "model": "gpt-4o",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ]
  }'`}</pre>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* FAQ */}
        <section className="docs-section docs-section-alt">
          <div className="container">
            <h2 className="section-title">常见问题</h2>
            <div className="faq-list">
              <div className="faq-item">
                <h3 className="faq-question">如何获取 API Key？</h3>
                <p className="faq-answer">
                  注册并登录后，在控制台的「API 密钥」页面可以创建和管理您的 API Key。
                </p>
              </div>

              <div className="faq-item">
                <h3 className="faq-question">支持哪些模型？</h3>
                <p className="faq-answer">
                  我们支持 OpenAI GPT-4o、Claude 3.5 Sonnet、Gemini 2.0 Flash 等 40+ 主流大模型。
                  查看<Link to="/pricing" className="inline-link">模型广场</Link>了解完整列表。
                </p>
              </div>

              <div className="faq-item">
                <h3 className="faq-question">如何计费？</h3>
                <p className="faq-answer">
                  按实际使用的 token 数量计费，不同模型价格不同。您可以在控制台查看详细的用量统计和费用明细。
                </p>
              </div>

              <div className="faq-item">
                <h3 className="faq-question">API 有速率限制吗？</h3>
                <p className="faq-answer">
                  根据您的账户等级有不同的速率限制。普通用户默认 60 请求/分钟，VIP 用户可获得更高额度。
                </p>
              </div>

              <div className="faq-item">
                <h3 className="faq-question">遇到问题如何获取帮助？</h3>
                <p className="faq-answer">
                  您可以通过控制台的工单系统提交问题，或发送邮件至 support@example.com，我们会在 24 小时内回复。
                </p>
              </div>
            </div>
          </div>
        </section>

        {/* CTA */}
        <section className="docs-cta">
          <div className="container">
            <h2 className="cta-title">准备好开始了吗？</h2>
            <p className="cta-description">
              注册即送体验额度，立即开始使用象汇 API
            </p>
            <div className="cta-actions">
              <Link to="/sign-up" className="btn-primary-large">
                免费注册
              </Link>
              <Link to="/pricing" className="btn-secondary-large">
                查看定价
              </Link>
            </div>
          </div>
        </section>
      </div>

      <style>{`
        /* ============================================================
         * Docs Page Styles — M3 Design
         * ============================================================ */
        .docs-container {
          font-family: var(--font-sans, 'Inter', sans-serif);
          color: var(--m3-on-surface, var(--foreground));
          background: var(--m3-surface, var(--background));
        }

        .container {
          max-width: 1200px;
          margin: 0 auto;
          padding: 0 24px;
        }

        /* Hero */
        .docs-hero {
          padding: 80px 0 60px;
          text-align: center;
          background: linear-gradient(
            135deg,
            var(--m3-surface) 0%,
            var(--m3-surface-1) 100%
          );
        }

        .docs-title {
          font-size: 48px;
          font-weight: 600;
          letter-spacing: -0.02em;
          color: var(--m3-on-surface);
          margin-bottom: 16px;
        }

        .docs-subtitle {
          font-size: 20px;
          color: var(--m3-on-surface-variant);
          line-height: 1.6;
        }

        /* Sections */
        .docs-section {
          padding: 80px 0;
        }

        .docs-section-alt {
          background: var(--m3-surface-1);
        }

        .section-title {
          font-size: 36px;
          font-weight: 600;
          text-align: center;
          color: var(--m3-on-surface);
          margin-bottom: 48px;
          letter-spacing: -0.015em;
        }

        /* Quick Start Grid */
        .docs-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
          gap: 32px;
          margin-top: 48px;
        }

        .doc-card {
          padding: 32px;
          background: var(--m3-surface);
          border: 1px solid var(--m3-outline-variant);
          border-radius: 1rem;
          transition: all 200ms cubic-bezier(0.2, 0, 0, 1);
        }

        .doc-card:hover {
          box-shadow: var(--m3-elevation-2);
          transform: translateY(-2px);
          border-color: var(--m3-primary);
        }

        .doc-card-header {
          display: flex;
          align-items: center;
          gap: 16px;
          margin-bottom: 16px;
        }

        .doc-icon {
          width: 48px;
          height: 48px;
          display: flex;
          align-items: center;
          justify-content: center;
          background: var(--m3-primary-container);
          color: var(--m3-primary);
          border-radius: 0.75rem;
          font-size: 20px;
          font-weight: 600;
        }

        .doc-card-title {
          font-size: 20px;
          font-weight: 600;
          color: var(--m3-on-surface);
          letter-spacing: -0.01em;
        }

        .doc-card-description {
          font-size: 15px;
          color: var(--m3-on-surface-variant);
          line-height: 1.6;
          margin-bottom: 16px;
        }

        .doc-link {
          font-size: 15px;
          font-weight: 500;
          color: var(--m3-primary);
          text-decoration: none;
          transition: color 180ms ease;
        }

        .doc-link:hover {
          color: var(--m3-primary-hover);
          text-decoration: underline;
        }

        /* API Reference */
        .docs-content {
          max-width: 900px;
          margin: 0 auto;
        }

        .api-block,
        .sdk-block {
          margin-bottom: 48px;
        }

        .api-title,
        .sdk-title {
          font-size: 24px;
          font-weight: 600;
          color: var(--m3-on-surface);
          margin-bottom: 16px;
          letter-spacing: -0.01em;
        }

        .api-description {
          font-size: 15px;
          color: var(--m3-on-surface-variant);
          line-height: 1.6;
          margin-bottom: 16px;
        }

        .code-block {
          background: var(--m3-surface-2);
          border: 1px solid var(--m3-outline-variant);
          border-radius: 0.75rem;
          padding: 20px;
          overflow-x: auto;
        }

        .code-block code,
        .code-block pre {
          font-family: 'Roboto Mono', 'JetBrains Mono', monospace;
          font-size: 14px;
          line-height: 1.6;
          color: var(--m3-on-surface);
          white-space: pre;
          margin: 0;
        }

        /* FAQ */
        .faq-list {
          max-width: 900px;
          margin: 0 auto;
        }

        .faq-item {
          padding: 24px;
          background: var(--m3-surface);
          border: 1px solid var(--m3-outline-variant);
          border-radius: 0.75rem;
          margin-bottom: 16px;
        }

        .faq-question {
          font-size: 18px;
          font-weight: 600;
          color: var(--m3-on-surface);
          margin-bottom: 12px;
          letter-spacing: -0.01em;
        }

        .faq-answer {
          font-size: 15px;
          color: var(--m3-on-surface-variant);
          line-height: 1.6;
        }

        .inline-link {
          color: var(--m3-primary);
          text-decoration: none;
          font-weight: 500;
        }

        .inline-link:hover {
          text-decoration: underline;
        }

        /* CTA */
        .docs-cta {
          padding: 100px 0;
          background: linear-gradient(
            135deg,
            var(--m3-primary-container) 0%,
            var(--m3-surface-1) 100%
          );
          text-align: center;
        }

        .cta-title {
          font-size: 40px;
          font-weight: 600;
          color: var(--m3-on-surface);
          margin-bottom: 16px;
          letter-spacing: -0.02em;
        }

        .cta-description {
          font-size: 18px;
          color: var(--m3-on-surface-variant);
          margin-bottom: 40px;
          line-height: 1.7;
        }

        .cta-actions {
          display: flex;
          gap: 16px;
          justify-content: center;
          flex-wrap: wrap;
        }

        .btn-primary-large,
        .btn-secondary-large {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          padding: 18px 48px;
          font-size: 18px;
          font-weight: 500;
          border-radius: 624.9375rem;
          text-decoration: none;
          cursor: pointer;
          transition: all 180ms cubic-bezier(0.2, 0, 0, 1);
          letter-spacing: 0.01em;
        }

        .btn-primary-large {
          color: var(--m3-on-primary);
          background: var(--m3-primary);
          border: none;
          box-shadow: var(--m3-elevation-1);
        }

        .btn-primary-large:hover {
          background: var(--m3-primary-hover);
          box-shadow: var(--m3-elevation-2);
          transform: translateY(-1px);
        }

        .btn-secondary-large {
          color: var(--m3-primary);
          background: transparent;
          border: 1px solid var(--m3-outline);
        }

        .btn-secondary-large:hover {
          background: color-mix(in oklch, var(--m3-primary) 8%, transparent);
          border-color: var(--m3-primary);
        }

        /* Responsive */
        @media (max-width: 768px) {
          .docs-hero {
            padding: 60px 0 40px;
          }

          .docs-title {
            font-size: 36px;
          }

          .docs-subtitle {
            font-size: 18px;
          }

          .section-title {
            font-size: 28px;
            margin-bottom: 32px;
          }

          .docs-section {
            padding: 60px 0;
          }

          .docs-grid {
            grid-template-columns: 1fr;
          }

          .cta-title {
            font-size: 32px;
          }

          .code-block {
            font-size: 13px;
          }
        }

        /* Dark mode */
        .dark .docs-hero {
          background: var(--m3-surface);
        }

        .dark .docs-section-alt {
          background: var(--m3-surface-1);
        }

        .dark .doc-card,
        .dark .faq-item {
          background: var(--m3-surface-2);
          border-color: oklch(1 0 0 / 8%);
        }

        .dark .code-block {
          background: var(--m3-surface-3);
          border-color: oklch(1 0 0 / 8%);
        }

        .dark .docs-cta {
          background: linear-gradient(
            135deg,
            var(--m3-primary-container) 0%,
            var(--m3-surface-2) 100%
          );
        }
      `}</style>
    </PublicLayout>
  )
}
