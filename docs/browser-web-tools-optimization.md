# 技能精简复盘：从 11 个工具到 5 核心的自我达尔文主义

> 工具越来越多不是好事。当每个工具都能做差不多的事，沉默的效率损耗来自"选择"本身。本文记录一次真实的技能精简过程：如何发现重叠、如何做决策、以及什么时候该做这类优化。

---

## 缘起：一个"够用就好"的问题

某天收到一个问题：agent-reach 技能是否能和浏览器自动化三个工具结合？是否有重复？

顺着这个问题盘点下去，发现了一个尴尬的事实：

**~/.openclaw/skills/ 下光 Browser/Web/Search 相关的技能就有 11 个。**

```
浏览器自动化：agent-browser、browser-cdp、browser-use、web-access、OpenClaw 内置 Browser Relay
网页内容提取：web-reader-pro、web-scraper、webfetch-md
搜索：agent-reach、multi-search、tavily-search、brave-api-search
```

这还没算 OpenClaw 内置的 web_search、web_fetch 等基础工具。

11 个工具，实际日常用到的可能就 3-4 个。剩下的在做什么？

**在增加决策负担。**

---

## 工具越多，问题越多

技能膨胀不是 OpenClaw 特有的问题。任何系统在使用一段时间后都会积累冗余。常见症状：

- **选择麻痹**：面对同一个任务，脑子里同时浮现 3 个工具，各有优劣，陷入无意义的比较
- **维护负担**：每个技能都有自己的依赖、配置、版本——它们都会过时
- **规则矛盾**：两个工具的触发条件写得模糊，遇到边界情况不知道该用哪个
- **认知碎片**：知识散落在各处，没有人对全局有清晰认知

这次盘点的发现印证了这些问题：

```
web-access         → 与 browser-cdp 功能 100% 重叠
tavily-search      → 被 multi-search 完全覆盖
brave-api-search   → 被 multi-search 完全覆盖
web-scraper        → OpenClaw browser snapshot 已覆盖
webfetch-md        → 同上，且质量不如 web-reader-pro
```

6 个技能可以直接删除，不影响任何实际能力。

---

## 复盘方法论：四步发现重叠

### 第一步：穷举清单

不依赖"我觉得哪个重叠"，而是把所有 Skills 全部列出来。

```
Browser 自动化（5）:
  - agent-browser
  - browser-cdp
  - browser-use
  - web-access
  - OpenClaw Browser Relay

网页内容提取（3）:
  - web-reader-pro
  - web-scraper
  - webfetch-md

搜索（4）:
  - agent-reach
  - multi-search
  - tavily-search
  - brave-api-search
```

### 第二步：核心定位提炼

每个工具问三个问题：
1. **它解决什么本质问题？**（不是"能做什么"，而是"解决什么痛点"）
2. **它和其他工具的核心差异是什么？**（找到那个不可被替代的理由）
3. **它的 Token 消耗是多少？**（0 / 按需 / 固定成本）

用这三个维度画一个定位矩阵：

| 工具 | 核心价值 | Token | 登录态 |
|------|---------|-------|--------|
| OpenClaw Browser | 登录态 + 反爬兜底 | 0 | ✅ |
| agent-browser | 轻量一次性操作 | 0 | ❌ |
| browser-use | AI 自主决策 | 💰 | 看模式 |
| multi-search | 统一搜索入口 | 0 | — |
| agent-reach | 平台专用工具箱 | 0 | 部分 |

### 第三步：画重叠图

用文字画出能力重叠区域：

```
浏览器自动化
┌─────────────────────────────────────┐
│  OpenClaw Browser Relay  ← 几乎完全取代 ↓│
│  web-access         ← 与 browser-cdp 相同 │
│  browser-cdp        ← 手动版 CDP        │
│  agent-browser      ← 轻量 CLI，有独立价值 │
│  browser-use        ← AI 自主，有独立价值  │
└─────────────────────────────────────┘

网页内容提取
┌─────────────────────────────────────┐
│  web-reader-pro  ← Jina + 缓存 + 智能路由│
│  webfetch-md     ← 简陋版，无缓存        │
│  web-scraper     ← 极简版               │
│  OpenClaw Browser ← snapshot 可替代三者  │
└─────────────────────────────────────┘

搜索
┌─────────────────────────────────────┐
│  multi-search       ← 自动 fallback 链  │
│  tavily-search     ← 被 multi 覆盖     │
│  brave-api-search   ← 被 multi 覆盖     │
│  agent-reach        ← 平台专用，有独立价值│
└─────────────────────────────────────┘
```

### 第四步：制定精简方案

**保留原则：**
1. 每个能力层次只保留一个主导工具
2. 被其他工具完全覆盖的，删
3. 有独特价值（登录态/平台专用/AI 自主）的，保留
4. Token 消耗差异大的，同场景保留多个

**决策规则：**

```
能 0 token 完成 → 不用付费模式
被其他工具完全覆盖 → 删
平台专用工具无法被通用工具替代 → 保留
```

---

## 精简结果

### 删除（7项）

| 技能 | 删除原因 |
|------|---------|
| browser-cdp | OpenClaw Browser Relay profile="user" 已覆盖，等效且更简单 |
| web-access | 与 browser-cdp 实质相同，已被替代 |
| tavily-search | multi-search 已包含此源 |
| brave-api-search | multi-search 已包含此源 |
| web-scraper | OpenClaw Browser snapshot 已覆盖 |
| webfetch-md | 质量不如 web-reader-pro |
| agent-reach（重复安装） | ~/.agents/ 源头保留，~/.openclaw/ 下有重复安装 |

### 保留（5+1）

| 工具 | 定位 | Token | 为什么保留 |
|------|------|-------|-----------|
| **OpenClaw Browser** | 主力浏览器工具 | 0 | 登录态复用、反爬、页面交互全覆盖 |
| **agent-browser** | 轻量一次性操作 | 0 | 简单任务最快，0 token |
| **browser-use** | AI 自主决策 | 💰 | 复杂多步任务唯一解 |
| **multi-search** | 统一搜索入口 | 0 | 自动 fallback，永不死机 |
| **agent-reach** | 平台专用工具箱 | 0 | Twitter/GitHub/B站等专用接口无可替代 |
| **web-reader-pro** | Jina 增强版 | 0 | 有大量抓取需求时保留，否则可删 |

### 精简后的工具矩阵

```
任务来了
│
├─ 简单一次性操作（填表/截图）→ agent-browser（0 token）
│
├─ 内容抓取（已知 URL）
│   └─ OpenClaw Browser snapshot（0 token）
│
├─ 需要登录态 / 被反爬
│   └─ OpenClaw Browser profile="user"（0 token）
│
├─ 复杂多步，页面结构未知，需要 AI 自主判断
│   └─ browser-use run（💰 token）
│
├─ 全网搜索
│   └─ multi-search（0 token，自动 fallback）
│
└─ 特定平台（Twitter/GitHub/B站/小红书/公众号）
    └─ agent-reach（平台专用工具）
```

---

## 什么时候该做技能精简？

不是技能越多越好，也不是每次安装新技能都要复盘。以下是信号：

### 触发信号

**信号 1：同一个任务能用 3 个以上工具完成**

这时候选择本身就是成本。选择清单应该始终保持在 3 个以内。

**信号 2：安装新技能时发现"这个我好像有类似的了"**

这是最诚实的信号。停下来，先把老的盘点清楚，再决定是否安装新的。

**信号 3：技能规则开始互相矛盾**

比如 web-access 说"优先用 CDP"，browser-cdp 说"这是我的专属场景"——这时候两个技能的边界已经模糊，需要合并。

**信号 4：无法回答"我今天用什么工具完成这个任务"**

当面对一个简单任务（比如抓一篇文章）时，如果脑子里同时浮现多个工具在比较，说明工具层需要精简。

### 不需要精简的情况

- 工具虽然功能有重叠，但触发条件天然不同（比如 agent-reach 和 multi-search 都在做搜索，但前者是平台专用，后者是通用 fallback）
- 每个工具的 Token 消耗有明显差异，用户能根据预算选择
- 工具之间是互补关系而非重叠关系

---

## 精简后的规则落地

决策完成后，需要把结论写下来，否则团队会重新陷入混沌。

规则文件结构：

```
browser-web-rules.md
├── 工具矩阵（5 核心工具定位表）
├── 触发条件决策树
├── 工具详解（每个工具的适用场景和用法）
├── 组合使用模式（3 种典型工作流）
├── 已移除工具历史记录
└── 注意事项
```

TOOLS.md 中的引用也很重要——把规则锚定到核心文档，确保每次工具调用决策都有据可查。

---

## 关键认知

**1. 工具不是资产，选择才是**

安装一个技能几乎零成本，但每次执行任务时的选择有真实成本。当选择数量超过 3 个，选择本身就是负担。

**2. 0 token 和付费工具可以共存**

不需要为了"统一"把所有 0 token 工具合并成一个。agent-browser 和 browser-use 在同一个任务类型上可能有重叠，但它们的 Token 消耗差异足以让它们各自保持独立价值。

**3. 平台专用工具很难被通用工具替代**

agent-reach 能做的事情，OpenClaw Browser + multi-search 理论上都能做。但"能做到"和"做到且高效"是两回事。平台专用工具的价值在于它是该场景的最优解，而非勉强可用的备选。

**4. 精简是一次性的，但规则需要维护**

这次删了 7 个工具，但不是删完就结束了。随着新技能的安装、旧技能的更新，精简结论会逐渐过时。建议每季度做一次 Skills 审计。

---

## 结语

工具主义的陷阱在于：把"我装过这个技能"当成"我具备这个能力"。

真实的 agent 能力不在于装了多少工具，而在于：
- 面对任务时能否快速选择正确的工具
- 工具之间是否有清晰的边界规则
- 规则是否被写在可以查阅的地方

这次精简删了 7 个工具，但更重要的是：留下来的 5 个工具有了明确的边界和触发条件。

**少即是多。选择越少，决策越快。**
