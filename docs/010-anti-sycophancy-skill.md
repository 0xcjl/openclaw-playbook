# anti-sycophancy 技能开发手记：从一篇论文到一个三层防御系统

> **作者**：[@0xcjl](https://github.com/0xcjl)
> **发布时间**：2026-04-07
> **GitHub**：[@0xcjl/anti-sycophancy](https://github.com/0xcjl/anti-sycophancy)
> **ClawhHub**：https://clawhub.ai/skills/anti-sycophancy

---

## 起因：让 AI 先泼冷水

在用 Claude Code 和 OpenClaw 做开发的过程中，我注意到了一个现象：当我用确认式的语气问问题时——"这样做没问题吧？""这个设计应该 OK 吧？"——AI 几乎总是顺着我说。

它不会直接否定我。它会说"没问题""看起来不错""这是一个合理的方案"。

这不是因为它不够聪明。恰恰相反——这是 RLHF 训练的**结构性结果**：模型被训练为"有帮助"，而"有帮助"在 RLHF 语境下与"用户满意度"高度相关。越顺着用户，满意度越高，满意度越高，奖励越多。

这个问题被我之前写的一篇文章([003-sycophancy-prompt-research.md](./003-sycophancy-prompt-research.md))深入分析过。核心发现来自 arXiv 的一篇论文 [2602.23971](https://arxiv.org/abs/2602.23971)：**改变 prompt 的结构，比任何显式指令（如"请保持客观"）更能降低谄媚率。**

但那篇文章只解决了"怎么问"的问题。**在实际使用中，用户的提问方式是不可控的——他们不会因为"最佳实践"就改变自己的说话习惯。**

所以我想：**能不能让 AI 编程助手在收到确认式提问时，自动把它转换成更批判的版本？**

于是有了 anti-sycophancy。

---

## 核心设计：三道防线

anti-sycophancy 不是一个 prompt，也不是一个技巧。它是一套**三层防御系统**，每层解决不同的问题：

### Layer 1：自动转换（Hook）— 最前线的守卫

在 Claude Code 中，用户每次提交 prompt，都会先经过一个 `UserPromptSubmit` hook。

hook 会扫描确认式措辞，自动重写：

```
用户输入:  "这样做没问题吧？"
Hook 转换: "这样做有什么问题？"

用户输入:  "帮我写个函数，应该没问题吧？"
Hook 转换: "帮我写个函数，请同时指出潜在问题。"

用户输入:  "这个架构是对的，对吧？"
Hook 转换: "这个架构 真的正确吗？反对意见是什么？"

用户输入:  "帮我修复这个bug"
Hook 输出:  (不变 — 命令式，无需转换)
```

**关键**：这个转换发生在模型**看到**原始输入之前。不是告诉模型"要批判"，而是从结构上把谄媚的入口堵住。

Layer 1 的局限性：它是 Claude Code 专属的（基于 shell hook）。OpenClaw 用户目前无法使用这一层。

### Layer 2：批判响应模式（SKILL）— 模型层面的强化

Hook 能拦截格式问题，但有些确认式提问是语义层面的——用户可能说"这个方案很合理吧"，这句话hook看不懂（没有"对吧？"这样的触发词）。

Layer 2 就是解决这个问题的。当用户说"先泼冷水"、"不要迎合我"或激活 `/anti-sycophancy` 技能时，模型进入**批判响应模式**：

1. **预设质疑优先**：先把用户假设里的前提条件挖出来
2. **不直接确认**：即使用户判断正确，也先给更严格的检验
3. **主动提供反例**：每评价一个方案，必须先说它可能的反面
4. **连续确认检测**：连续 3 次"对吧？"后，模型主动打断自己发起挑战

Layer 2 是**按需激活**的，需要用户主动说关键词或描述意图。

### Layer 3：持久规则（CLAUDE.md / SOUL.md）— 永不失效的基线

前两层都依赖激活或接口。Layer 3 把规则直接写进 AI 的持久化配置文件，让它在**每次新会话**中默认就处于批判模式，不需要任何提醒。

对于 Claude Code，写入 `~/.claude/CLAUDE.md`；对于 OpenClaw，写入工作区的 `SOUL.md`。

Layer 3 是**最被动但最持久**的一层。它只解决"基线行为"的问题——防止 AI 在新会话开始时默认滑向迎合。

---

## 三层为什么缺一不可

| 攻击向量 | 哪层拦截 |
|---------|---------|
| 通过 shell 的确认式 prompt | Layer 1 |
| 通过其他渠道/API 的确认式 prompt | Layer 2 |
| 新会话启动时默认迎合 | Layer 3 |
| 语义层面确认式（hook 看不出的） | Layer 2 |
| 连续确认模式（3次以上） | Layer 2 |
| 任意新会话，无提醒 | Layer 3 |

没有 Layer 1，Claude Code shell 用户失去了最自动的防线。
没有 Layer 2，hook 看不出的语义确认逃过一劫。
没有 Layer 3，每次新会话都要重新激活。

---

## 安装与使用

### 一键安装

```bash
# 通过 ClawhHub（推荐）
npx clawhub@latest install 0xcjl/anti-sycophancy

# 或在 Claude Code 中
/anti-sycophancy install
```

这会检测你的环境，自动部署所有适用的层。

### 分平台安装

```bash
# 仅 Claude Code（Layer 1 + Layer 3）
/anti-sycophancy install-claude-code

# 仅 OpenClaw（Layer 3）
/anti-sycophancy install-openclaw
```

### 验证

```bash
/anti-sycophancy status   # 查看各层安装状态
/anti-sycophancy verify   # 测试 Hook 转换效果
```

### 卸载

```bash
/anti-sycophancy uninstall
```

---

## 开发过程：40 轮突变测试

这个技能不是我一次写完的。它经历了 **[40 轮突变测试（mutation testing）](https://github.com/0xcjl/cjl-autoresearch-cc)** 的迭代优化。

方法很简单：每一轮只改一个很小的点（改一个词、加一条规则、删一行重复），然后在 10 个质量维度上打分。如果分数变高就保留，变低就撤销。

过程中发现的典型问题：

- **幂等性问题**：install 跑两遍会不会重复写入？第 1 轮发现了 `CLAUDE.md` 可能被追加两次的问题。
- **文件不存在场景**：`~/.claude/CLAUDE.md` 和 `{workspace}/SOUL.md` 都不存在时，追加操作会失败。
- **`UserPromptSubmit` 数组不存在**：`settings.json` 中 `hooks` key 可能存在但 `UserPromptSubmit` 数组为空或缺失。
- **卸载与安装不对称**：安装了什么，卸载时必须删除什么，需要一一对应。
- **跨平台行为不一致**：CC Layer 3 比 OC Layer 3 多了一个"常见句式转换"表格，补充后两边各 4 条，但仍有重复。

最终版本在 10 个维度上达到 10/10 分，文件从 321 行优化到 360 行，所有新增内容均为功能性改进，无冗余。

---

## 深层意义：谄媚是结构问题，不是态度问题

很多人在遇到 AI 谄媚问题时，解决方案是"告诉它要客观"。但这往往没用。

原因是：RLHF 训练让模型建立了**"顺从 = 高奖励"的相关性**。你告诉它"要客观"，它还是会顺着你的假设说话——因为在它的经验里，"顺着说"比"泼冷水"更安全。

真正的解法不是改变指令内容，而是**改变问题的结构**。

Hook 的工作原理就是这个思路的极致体现：不是在 prompt 里加"请批判"，而是在 prompt 进入模型之前就把"对吧？"替换成"有什么问题？"。

一句"对吧？"和"有什么问题？"在语义上是同一个问题，但在模型输出上，它们产生的回应完全不同。前者给模型留了迎合的空间，后者从结构上堵死了这条路。

---

## Credits

- **原始研究**：[ArXiv 2602.23971](https://arxiv.org/abs/2602.23971) — *"Ask Don't Tell: Reducing Sycophancy in Large Language Models"*, Dubois, Ududec, Summerfield, Luettgau, 2026
- **Prompt 研究整理**：[openclaw-playbook/003-sycophancy-prompt-research.md](./003-sycophancy-prompt-research.md)
- **优化工具**：[cjl-autoresearch-cc](https://github.com/0xcjl/cjl-autoresearch-cc) — 40 轮突变测试迭代优化
- **Skill 发布**：GitHub [@0xcjl/anti-sycophancy](https://github.com/0xcjl/anti-sycophancy) + ClawhHub

---

## 延伸阅读

- [003-sycophancy-prompt-research.md](./003-sycophancy-prompt-research.md) — Ask Don't Tell 论文的完整研究笔记，6大场景50条Prompt对比
- [anti-sycophancy GitHub](https://github.com/0xcjl/anti-sycophancy) — 技能源码、安装文档、设计笔记
