# 从"看见"到"做到"：browser-cdp 如何让 AI 真正操控你的浏览器

> 实践出真知。一套经过 Phase 1 安装调试 → Phase 2 设计重构 → Phase 3 对比验证，最终落地的 OpenClaw 浏览器自动化工具链。

## 问题的起点

用 AI Agent 抓网页，你一定遇到过这些情况：

- **小红书**：静态抓取返回"访问频繁"，换 User-Agent 也没用
- **YouTube 搜索**：Jina 读取到的是登录墙，不是视频结果
- **Bing 搜索**：返回验证码页，AI 拿到的内容和肉眼看到的完全不同
- **微信公众号**：有内容，但图片全部是防盗链占位图

这些场景有一个共同特征：**静态 HTTP 请求无法获取真实内容**。目标网站用 JavaScript 渲染内容、用登录态判断是否机器人、用行为分析区分人类和爬虫。

这时，你需要的不只是"读页面"，而是**"用浏览器读页面"**。

---

## 解决方案：三层工具链

经过调研和测试，我最终落地了一套三层分工的浏览器工具链：

```
Layer 1 — agent-reach（默认）
  公开页面：GitHub、Wikipedia、博客、技术文档
  优点：速度快（~1-2s）、token 消耗低、返回结构化 Markdown

Layer 2 — browser-cdp（升级触发）
  搜索结果页（Bing/Google）、YouTube、Twitter、需要登录态的页面
  优点：携带用户真实 Chrome 的 cookies 和 session，绕过反爬

Layer 3 — agent-browser（备选）
  简单截图、快速验证、隔离环境操作
  优点：OpenClaw 隔离浏览器，无需配置，不影响本地 Chrome
```

三层不是替代关系，而是**按需升级**：

```
任务进来 → Layer 1 尝试 → 成功 → 结束
                  ↓ 失败
           Layer 2 尝试 → 成功 → 记录 site-patterns
                        ↓ 失败
                 Layer 3 或记录问题
```

---

## Phase 1：安装调试——踩过的坑

### 从 eze-is/web-access 开始

web-access 是 Tomas 团队开发的 Chrome 自动化工具，核心是 **CDP Proxy**：一个 HTTP 服务，桥接 OpenClaw 的 REST API 调用和 Chrome DevTools Protocol 的 WebSocket 连接。

```bash
git clone https://github.com/eze-is/web-access.git \
  ~/.openclaw/skills/web-access
```

安装后运行 `check-deps.sh`，Node.js 版本通过，但连接 Chrome 时一直失败。

### macOS 端口绑定陷阱

Chrome 确实在运行，但调试端口 9222 没有监听。

原因是 macOS 上用 `open -a "Google Chrome" --args --remote-debugging-port=9222` 启动 Chrome 时，**参数不会传递给 Chrome 进程**——`open` 命令会拦截它们。这是 macOS 的沙箱安全限制。

解决方案：用完整二进制路径直接启动：

```bash
pkill -9 "Google Chrome"
sleep 2
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/chrome-debug-profile \
  --no-first-run &
```

### CDP Proxy 的 ES Module Bug

连接建立后，CDP Proxy 返回 `"连接失败"`。调试发现：

```
require is not defined
```

CDP Proxy 脚本是 `.mjs`（ES Module），但在 `getChromeWebSocketUrl()` 函数里用了 `require('node:http')`。ES Module 顶层没有 `require`，Node.js 22+ 中 `require` 完全不可用。

修复：将 `require` 替换为动态 import：

```javascript
// 修复前（报错）
const http = require('node:http');

// 修复后
const { default: http } = await import('node:http');
```

Bug 已 [提交给原作者](https://github.com/eze-is/web-access/issues/10)，修复版本保存在 `0xcjl/browser-cdp` 仓库。

---

## Phase 2：设计重构——提取和适配

web-access 的设计目标是给 Claude Code 用的，不完全适合 OpenClaw。我提取了核心能力，重新设计：

### 核心改动

| 维度 | web-access（原版） | browser-cdp（OpenClaw 版） |
|------|---|---|
| 目标用户 | Claude Code（单一 AI） | OpenClaw（多工具协同） |
| 触发方式 | 显式指令 | 自动判断（SKILL.md description） |
| 站点经验 | `~/.agent-reach/` | `~/.openclaw/skills/browser-cdp/references/` |
| 交互方式 | Claude Code 内置 | HTTP REST API |
| 安装方式 | Claude Code 专用安装流程 | `git clone` 到 skills 目录 |

### OpenClaw Skill 格式

SKILL.md 的 description 字段是触发规则的定义：

```yaml
---
name: browser-cdp
description: >
  Triggers (满足任一即触发):
  - 目标 URL 是搜索结果页（Bing/Google/YouTube 搜索页）
  - 静态抓取被反爬拦截（验证码/拦截页/空内容）
  - 需要读取已登录用户的私有内容
  - YouTube、Twitter/X、小红书、微信公众号等平台内容
  - 任务涉及"点击"、"填表"、"滚动加载"、"拖拽"
  - 需要截图、截取动态渲染页面
---
```

描述即规则，OpenClaw 根据用户任务内容自动匹配是否调用，不需要用户手动指定。

---

## Phase 3：对比验证——实测数据说话

六个场景的对比测试结果：

| 场景 | agent-reach (Jina) | browser-cdp | 结论 |
|------|---|---|---|
| **GitHub 公开仓库** | ✅ 1.6s，完整 Markdown+图片 | ⚠️ 需要写 DOM 查询 | **agent-reach 胜** |
| **Bing 搜索结果** | ❌ 返回验证码页 | ✅ 5 条真实搜索结果 | **browser-cdp 胜** |
| **YouTube 搜索** | ❌ 返回登录墙 | ✅ 视频标题+播放量 | **browser-cdp 胜** |
| **Wikipedia** | ✅ 8.7s，结构化干净 | ⚠️ DOM 截取不完整 | **agent-reach 胜** |
| **GitHub 登录态检测** | — | ✅ 能检测 cookie 状态 | **browser-cdp 独有能力** |
| **小红书** | ⚠️ 搜到公众号，不是笔记 | ⚠️ 首页需登录 | 需具体 URL |

**关键发现：**

1. **agent-reach 在公开/文本密集型页面依然最强**，速度快、结构化程度高，token 消耗少
2. **browser-cdp 在反爬场景不可替代**，特别是搜索结果页和视频平台
3. **两者不是竞争关系**，而是分工关系

---

## 实际应用场景

### 场景 1：竞品监控

每天定时抓取 YouTube 搜索结果中某关键词的视频列表（标题、播放量、发布时间）。

```bash
# browser-cdp 获取 YouTube 搜索结果
TARGET=$(curl -s "http://localhost:3456/new?url=https://www.youtube.com/results?search_query=openai+agent" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['targetId'])")

sleep 5

curl -s -X POST "http://localhost:3456/eval?target=$TARGET" \
  -d 'JSON.stringify({
    videos: Array.from(document.querySelectorAll("ytd-video-renderer")).slice(0,10).map(v=>({
      title: v.querySelector("#video-title")?.innerText,
      views: v.querySelector("#metadata-line span")?.innerText,
      link: "https://youtube.com" + v.querySelector("a")?.href
    }))
  })'
```

### 场景 2：需要登录态的 GitHub 操作

通过 GitHub 的 Chrome 登录态，直接读取用户的私有仓库列表或 billing 信息。

```bash
TARGET=$(curl -s "http://localhost:3456/new?url=https://github.com/settings/billing" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['targetId'])")

sleep 3

# 检测登录态
curl -s -X POST "http://localhost:3456/eval?target=$TARGET" \
  -d 'JSON.stringify({
    logged_in: !!document.querySelector(".header-body"),
    title: document.title
  })'
```

### 场景 3：绕过反爬的内容提取

某个技术博客加载了 Cloudflare 保护，无法通过静态请求访问内容。

```bash
TARGET=$(curl -s "http://localhost:3456/new?url=https://example-blog-blocked.com/posts/123" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['targetId'])")

sleep 8  # 等待 Cloudflare 验证通过

curl -s -X POST "http://localhost:3456/eval?target=$TARGET" \
  -d 'document.querySelector(".post-content")?.innerText'
```

---

## 站点经验积累

每个新网站都是一次学习机会。把发现记录下来，下次遇到同类网站时可以快速复用。

记录位置：`~/.openclaw/skills/browser-cdp/references/site-patterns/`

按域名创建 `.md` 文件：

```markdown
# youtube.com

## 反爬特征
- 搜索结果页 `/results?search_query=` 需要 JS 渲染
- 直接 HTTP 请求返回空或登录页

## 绕过方式
- 使用 browser-cdp，带用户登录态访问
- 等待页面加载 5s 再读 DOM

## 关键选择器
- 视频卡片: `ytd-video-renderer`
- 标题: `#video-title`
- 播放量: `#metadata-line span`
- 时长: `#text.ytd-thumbnail-overlay-time-badge-renderer`
```

---

## 浏览哲学

browser-cdp 给了你"人"的能力，但也有人的局限——速度比 HTTP 慢，容易被限速，容易被检测。**用得精准比用得多更重要。**

```
① 明确目标 — 什么算完成？需要什么信息？
② 选最直接的起点 — 一次成功最好，不成功则调整
③ 每步结果都是证据 — 方向错了立即换，不反复重试
④ 完成后停止 — 不为"完整"浪费代价
```

程序化（eval DOM）受阻时，换 GUI 交互（click + wait）。

---

## 下一步：优化机制

工具链的价值在于持续优化。建立追踪机制：

```bash
~/.openclaw/skills/browser-cdp/references/usage-log.md
```

每次使用后追加：
```markdown
### 2026-03-24 | YouTube 搜索 | youtube.com/results | 成功 | 等待5s再读DOM
### 2026-03-25 | GitHub billing | github.com/settings/billing | 失败-未登录 | 需要用户先登录Chrome
```

**优化触发条件**（二选一）：
- 累积 10 条记录
- 每月 1 日自动 review

Review 时分析成功率、提炼高效用法、更新 SKILL.md 策略。

---

## 仓库地址

- **browser-cdp skill**: https://github.com/0xcjl/browser-cdp
- **本文档**: https://github.com/0xcjl/openclaw-playbook

---

*本文属于 [OpenClaw Playbook](https://github.com/0xcjl/openclaw-playbook) 项目，记录真实使用经验，不保证最优解，但保证真实。
