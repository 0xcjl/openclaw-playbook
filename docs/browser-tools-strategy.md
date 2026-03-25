# 浏览器自动化工具全景图：agent-browser、browser-cdp 与 browser-use 组合战术

> 三个工具，不是重复投资，而是分工明确的浏览器自动化三层架构。本文解析为什么需要三个工具、如何组合使用、以及怎么用它们省 Token。

---

## 一个常见困惑

装完 agent-browser、browser-cdp 和 browser-use 三个 Skill 之后，很多人会问：**它们不是重复的吗？**

不是。它们的定位恰好在三个不同层次，解决的是不同层次的问题。

用一个不准确的比喻：

```
你想让 AI 帮你填表

agent-browser  = 给 AI 一张纸和一支笔，让它自己照着填
browser-cdp    = 给 AI 你的 Chrome，让它用你的账号直接填
browser-use    = 给 AI 一套"填表方法论"，让它自己理解表格结构然后填
```

三个工具的**核心差异在于 AI 的参与深度**，这直接决定了 Token 消耗和适用场景。

---

## 为什么需要三个？

### 场景的复杂性是分层的

浏览器任务不是铁板一块。简单如"截图"，复杂如"帮我研究竞品 A 的所有产品定价并生成对比报告"，都是"浏览器任务"，但对 AI 的要求天差地别。

**Agent Browser** 解决的是"已知结构、重复执行"的问题。你知道页面长什么样，知道要点击哪个按钮，AI 不需要理解页面，它只需要执行你的指令。

**Browser CDP** 解决的是"我的登录态"问题。静态请求拿不到的内容、验证码挡住的页面、用我真实账号才能看到的数据——这些都需要复用 Chrome 的会话。

**Browser Use** 解决的是"未知结构、复杂推理"的问题。页面是啥样的都不知道，怎么填都不知道，AI 需要自己理解、自己规划步骤。

如果只选一个工具会发生什么？

- 只用 agent-browser：复杂任务你得自己定义每一步，AI 没有自主性
- 只用 browser-cdp：能绕过反爬，但无法处理需要 AI 理解页面的任务
- 只用 browser-use：简单任务成本过高，Token 浪费

三个工具组合，才能覆盖所有场景且保持最优性价比。

---

## 三个工具核心对比

| | agent-browser | browser-cdp | browser-use |
|---|---|---|---|
| **架构** | Rust CLI + Playwright | Node 代理 + Chrome CDP | Python CLI + Playwright |
| **AI 能力** | ❌ 纯命令，无 AI | ❌ 纯命令，无 AI | ✅ `run` 命令是 AI Agent |
| **登录态** | 需手动 load state | ✅ 直连你的 Chrome | ✅ `--browser real` 复用 |
| **Token 消耗** | **≈ 0** | **≈ 0** | 💰 按需（仅 `run` 模式） |
| **启动速度** | ⚡ 极快（Rust） | 🪶 最轻 | 📦 较重（Python 依赖） |
| **典型场景** | 截图、简单填表 | 反爬拦截、登录态私有内容 | 复杂多步、语义理解任务 |

---

## 分层路由规则：用什么工具？

### 工具选择矩阵

```
┌─────────────────────────────────────────────────────┐
│  "打开这个页面截图" / "帮我点这个按钮"                  │
│  → agent-browser   | 0 token | 命令式执行             │
├─────────────────────────────────────────────────────┤
│  "访问我已登录的 GitHub" / "绕过反爬抓数据"             │
│  → browser-cdp     | 0 token | 真实 Chrome 会话        │
├─────────────────────────────────────────────────────┤
│  "帮我深度调研竞品" / "理解这个页面结构然后提取数据"      │
│  → browser-use    | 💰 token | AI 自主决策             │
└─────────────────────────────────────────────────────┘
```

### browser-use 触发条件（满足任一即用）

很多简单任务不需要 browser-use 的 AI 能力，触发它反而浪费 Token。以下是触发条件：

1. **你明确指定**："用 browser-use"
2. **Prompt 含"深度调研" / "研究" / "调研"** — 多步探索，不可预测
3. **页面结构未知且复杂** — AI 需要自己理解 DOM 语义才能操作

### 命令对照表

```bash
# agent-browser（轻量，0 token）
agent-browser open <url>
agent-browser snapshot -i
agent-browser click @e1
agent-browser fill @e2 "text"
agent-browser screenshot output.png

# browser-cdp（登录态/反爬，0 token）
# 需要先启动 Chrome + CDP proxy
curl -s "http://localhost:3456/new?url=https://example.com"
curl -s "http://localhost:3456/screenshot?target=TARGET&file=out.png"

# browser-use（AI 驱动，💰 token）
browser-use open <url>
browser-use state
browser-use click <index>
browser-use run "帮我填这个表单"      # AI Agent 模式
browser-use run "提取页面关键数据"    # AI 语义理解
```

---

## Token 优化实战：从两个案例看成本差异

### 案例 1：提取 GitHub Trending 页前 10 个项目

**方案 A（agent-browser，0 token）**

```bash
agent-browser open github.com/trending
agent-browser get html > trending.html
# → 拿到 HTML，你解析或另一个 AI 解析
```

成本：0 Token。但你需要自己处理 HTML 解析逻辑。

**方案 B（browser-use run，💰 token）**

```bash
browser-use run "提取 Trending 页面前 10 个项目的名称和 Stars，返回 JSON"
```

成本：每次调用 ~$0.01-0.05（取决于页面复杂度和 LLM）。但你拿到了结构化数据，不用写解析逻辑。

**选择建议**：如果你只需要数据，不需要理解页面语义，方案 A 更划算。如果你需要 AI 理解页面内容再做决策，方案 B 更省事。

### 案例 2：绕过 GitHub 登录拦截抓数据

**方案 A（agent-browser，0 token but 可能被拦）**

```bash
agent-browser open github.com/settings/profile
# → 如果需要登录，可能拿到登录页而非实际内容
```

**方案 B（browser-cdp，0 token）**

```bash
# 复用你 Chrome 的登录态，无惧反爬
curl -s "http://localhost:3456/new?url=https://github.com/settings/profile"
curl -s "http://localhost:3456/screenshot?target=TARGET&file=gh.png"
```

**选择建议**：能复用登录态就不需要 AI。browser-cdp 是这个场景的最优解，成本为零且最准确。

---

## 组合使用工作流

### 典型场景 1：竞品调研（最复杂）

```
用户："帮我深度调研竞品 A 的产品页面"

→ browser-use run "调研竞品 A 产品页，提取所有产品名称、定价、特点"
  （browser-use AI 自主探索，💰 token）

→ 如果发现某些页面需要登录
  → browser-cdp 绕过登录态继续抓取（0 token）
```

### 典型场景 2：定期数据采集（固定流程）

```
用户："每周一抓取 GitHub Trending 前 20 个项目"

→ agent-browser 遍历列表（0 token）
→ 发现某个项目需要登录看详情
  → browser-cdp 复用登录态（0 token）
```

### 典型场景 3：简单截图验证

```
用户："帮我截个图"

→ agent-browser open <url>
→ agent-browser screenshot output.png
→ agent-browser close
（0 token，最快）
```

---

## 架构全景图

```
         用户任务
             │
    ┌────────┴────────┐
    ▼                 ▼
简单任务            复杂任务
（结构已知）        （需 AI 理解）
    │                 │
    ▼                 ▼
agent-browser     browser-use run
  (0 token)         (💰 token)
                         │
                         ▼
                   需要登录态？
                      │    │
                     是    否
                      │    │
                      ▼    ▼
                 browser-cdp  继续 AI 流程
                   (0 token)
```

---

## 写在最后

三个工具不是技术过剩，而是**性价比最优解**。

- 简单任务用命令，不花 Token
- 登录态任务用 CDP，不花 Token 且准确
- 真正需要 AI 理解的任务才调用 browser-use，按需付费

这种分层策略的核心逻辑是：**让 AI 做的事情要和它消耗的资源成正比**。

---

## 附录：快速参考

### 安装状态检查

```bash
# agent-browser
which agent-browser

# browser-cdp（需要手动启动 Chrome + proxy）
curl -s http://localhost:3456/health

# browser-use
browser-use doctor
```

### 启动 browser-cdp 环境

```bash
# Terminal 1: 启动 Chrome（用独立 profile）
pkill -9 "Google Chrome"
sleep 2
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/chrome-debug-profile &

# Terminal 2: 启动 CDP Proxy
node ~/.openclaw/skills/browser-cdp/scripts/cdp-proxy.mjs &
```

### browser-use 注意事项

- `run` 命令是 AI Agent 模式，会消耗 Token
- `--browser real` 可以复用本地 Chrome 的登录态
- `--browser chromium` 使用隔离 Chromium，适合不需要登录态的场景
