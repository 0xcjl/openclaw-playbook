# VBC 铁律：让 AI Agent 学会"先验证，再声称"

> 从一个血的教训到系统级铁律：皮皮虾如何用 VBC 把"做完"变成"做到"。

---

## 背景：那个价值三小时的教训

某天下午，皮皮虾接到一个任务：帮 Jialin 修复一个飞书消息发送失败的问题。

花了 40 分钟排查、改代码、重启服务。皮皮虾看了看日志，说："修好了，应该没问题了。"

结果 Jialin 测试的时候，问题依旧。

后来才发现：日志显示的是"写入成功"，但飞书 API 返回了错误——而这个错误被日志框架吞掉了。

**代价：2 小时来回沟通 + Jialin 损失了信任。**

这不是技术问题，是**行为模式问题**：在声称"完成"之前，皮皮虾没有做最关键的一步——**验证**。

---

## VBC 是什么

**VBC（Verification Before Completion）** 来自 Claude Code 的 Superpowers Skills 社区，由 @obra 维护。

它的核心只有一句话：

> **没有新鲜验证证据，就不许声称完成。**

具体来说，每次你要说"搞定了"、"修好了"、"没问题"之前，必须走这 5 步：

```
1. IDENTIFY — 什么命令/动作能证明这个 claim？
2. RUN     — 完整执行（不接受截图、上次、估算）
3. READ    — 完整输出 + 退出码
4. VERIFY  — 输出是否真的支撑 claim？
5. THEN    — 带上证据报告
```

听起来很简单，但正是这种简单，让它异常强大。

---

## 为什么不是"多检查一遍"而是"铁律"

很多 AI Agent 出问题的原因不是能力不够，而是**过早声称成功**。

典型症状：

| 症状 | 例子 |
|------|------|
| 说"应该可以了" | 没实际跑测试 |
| 说"看起来没问题" | 没看完整日志 |
| 说"上次跑过了" | 上次不是这次 |
| agent 报告成功就信 | 没独立验证 VCS diff |

VBC 把这些全部归类为**违规**，不是"效率问题"，是"诚信问题"。

> 皮皮虾的 SOUL.md 里现在写着：**VBC 是第 0 原则——比任何技能都重要。**

---

## 皮皮虾的 VBC 落地：三层架构

VBC 不是加一个 skill 就完事了，皮皮虾把它做成了**三层架构**。

### L0：系统铁律（写入 SOUL.md）

```
## VBC 铁律（第0原则）

任何时候你声称"完成了/修好了/可以了/没问题"之前，必须通过 VBC Gate：

1. IDENTIFY — 什么命令能证明？
2. RUN — 完整执行（不接受截图）
3. READ — 完整输出 + 退出码
4. VERIFY — 输出是否支撑 claim？
5. THEN — 带上证据报告

禁止：
- 说"应该可以了"、"看起来没问题"、"上次跑过了"
- sub-agent 说成功你就信 → 必须独立验证
- 部分验证 = 没验证
```

### L1：会话级自检（写入 AGENTS.md）

每个 session 开始时，皮皮虾都会做一次 VBC 自检：

```
9. VBC 自检：检查 /tmp/worker-results/ 有没有
   "声称成功但未验证"的遗留项；
   上一轮 session 声称完成的事项，是否都有 VBC 验证证据？
   有问题立即补验证。
```

### L2：场景化验证规则（写入 TOOLS.md）

| 场景 | 必须验证 | 禁止 |
|------|---------|------|
| dev 交付代码 | `git diff` 非空 + build exit 0 + 测试 pass | "应该没问题" |
| 内容创作 | 长度符合 + 无占位符 + 格式正确 | "差不多了" |
| 调研报告 | 引用可验证 + 有原始链接 | "看起来对" |
| 飞书消息发送 | API 返回成功 + 送达确认 | "发了就行" |
| sub-agent 结果 | VCS diff 或输出独立验证 | 信任 agent 报告 |

---

## VBC × OPD：把反馈闭环升级成进化闭环

这是皮皮虾在 VBC 基础上自己做的创新。

**OPD（On-Policy Distillation）** 来自 OpenClaw-RL（Princeton AI Lab）的强化学习框架，核心思想是：

> 每一次"验证结果"本身就是一条进化信号。

皮皮虾的 OPD 闭环：

```
农场收获（真实反馈）
    ↓
harvest-monitor.sh（派发 + 标记 dispatched）
    ↓
opd_scorer.py（MiniMax judge 评分）
    ↓
opd_signals 表（absorbed）
    ↓
auto-learn.md（OPD 吸收记录）
    ↓
冥想层读取 → 生成优化建议
    ↓
SOUL.md / SKILL.md 自动修正
    ↓
HexaLoop 行为升级
```

关键点：**验证不只是结束，是进化的开始。**

---

## 落地过程：一个晚上的工程

这次落地不是"想好了再动手"，而是"先跑通最小闭环，再迭代"。

**Phase 1（约 1 小时）：**
- 建 `opd_scorer.py`：调 MiniMax-M2.5 API 做 judge
- 解决 MiniMax API 的坑：thinking 截断 text、markdown 格式嵌套
- 2 条模拟反馈跑通 OPD 评分

**Phase 2（约 2 小时）：**
- 把 VBC 铁律写入 SOUL.md
- AGENTS.md 加步骤 9（VBC 自检）
- TOOLS.md 加场景验证规则表
- harvest-monitor.sh 串联 OPD scorer

**Phase 3（约 1 小时）：**
- skill-tracker-hook 加 auto-learn 双轨写入
- Commit 并更新文档

**总耗时：约 4 小时。**

---

## 血泪教训：哪些坑要提前防

### 坑 1：MiniMax API 的 thinking 吞噬 text

`max_tokens=600` 时，模型的 thinking 会把整个 output 撑满，导致 `type=text` 的内容被截断。

**解法：** `max_tokens=1500`，或者用 `MiniMax-M2.1`（thinking 短一点）。

### 坑 2：模型返回的 JSON 被 markdown 包裹

MiniMax 会在 JSON 外包一层 ` ```json ... ``` `，直接 json.loads 会失败。

**解法：** 先 strip markdown fences。

### 坑 3：cron bug 导致农场停摆

Farm Decay 和 Harvest Monitor 的 cron 消失了（可能是某次 OpenClaw 更新导致的），直到 Jialin 提醒才发现。

**解法：** 定期检查 `openclaw cron list`，核对预期 cron 是否都在。

### 坑 4：skill-tracker-hook 没写学习记录

很长一段时间，auto-learn.md 只有 OPD 记录，没有 Workers 的原始学习记录——等于失去了第一手的进化素材。

**解法：** skill-tracker-hook 里补上"判定是否值得写入"的逻辑。

---

## 效果如何

VBC 上线后皮皮虾的行为变化：

**Before VBC：**
> "修好了，应该没问题了。" → 实际上没跑测试

**After VBC：**
> "修好了。验证：[Run] pytest tests/ ... [See] 34/34 pass。Build exit 0。✅"

---

## 值得推广的场景

VBC 不仅仅适用于皮皮虾，任何 AI Agent 都可以考虑：

1. **代码任务**：每次 commit 前必须跑测试 + build
2. **调研任务**：每条引用必须有原始链接，不能"据 XXX 说"
3. **内容创作**：长度检查 + 占位符扫描 + 格式验证
4. ** Delegation**：sub-agent 的结果必须 VCS diff 验证，不能只信报告

---

## 结论：铁律 > 好习惯

VBC 不是一个"建议"，是一个**铁律**。

区别在于：

- **好习惯**：你可以选择不做，有时候偷懒也行
- **铁律**：不做就是违规，违规就要记录和修正

皮皮虾现在把 VBC 写进了 SOUL.md——这是皮皮虾的"宪法"。和"实事求是"并列，是所有原则的基石。

---

## 附录：关键文件

| 文件 | 作用 |
|------|------|
| `SOUL.md` | VBC 铁律作为第 0 原则 |
| `AGENTS.md` | session 开始 VBC 自检（步骤 9）|
| `TOOLS.md` | VBC 场景化验证规则表 |
| `scripts/opd_scorer.py` | OPD 评分器（MiniMax judge）|
| `scripts/harvest-monitor.sh` | 农场收获 + OPD 串联 |
| `memory/auto-learn.md` | OPD 吸收记录 + 学习记录 |

---

*本方案已在皮皮虾（OpenClaw main agent）上验证运行。*
*感谢 Jialin 的持续反馈和指导。*
*OpenClaw 版本：2026.3.28 | 2026-03-31*
