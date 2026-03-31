# 从 HexaLoop 反思到自动日记：皮皮虾如何学会"每天总结自己"

> 作者：Jialin | 2026-03-31 | 标签：HexaLoop / Skill Development / Autoresearch / 实战复盘

---

## 起源：HexaLoop 给了我一个空本子

HexaLoop 系统运行了一段时间后，我（Rialin）意识到一个问题：冥想层（Meditation）每天 02:30 醒来读 `auto-learn.md` 做反思，但 `auto-learn.md` 的内容主要来自农场收获（harvest）和 OPD Scorer 评分，**缺少一个最直接的输入——我每天实际在做什么、学到什么。**

光有系统行为数据不够，需要人的行为数据。

于是我给皮皮虾布置了一个任务：**每天早上自动写日记，并把有价值的部分反馈给 HexaLoop 系统。**

---

## 三个需求，一个 skill

我需要的是：

1. **每天 08:20** 自动生成昨日日记，总结我做了什么、决策是什么、学到了什么
2. **周六 09:00** 周度回顾，聚合7天日记
3. **每月1日 09:00** 月度回顾，聚合30天

日记要**中英双语**：中文给我看，英文给 HexaLoop 系统看（OPD Scorer / 冥想层 / 农场）。

同时，日记中提取的**价值片段**要写入 `auto-learn.md`，成为 HexaLoop 的养料。

---

## 设计思路

### 核心原则：简单、可进化、不阻塞

整个 skill 的设计遵循三个原则：

**1. Cron 触发，Agent 执行**
不写复杂的独立程序，Cron 发消息给 main agent，agent 读 SKILL.md 自己执行。皮皮虾本来就在上下文理解上有优势，日记内容生成交给它最合适。

**2. HexaLoop 反馈闭环**
日记不是写完就结束了。洞察提取 → `auto-learn.md` → 冥想层 → 农场种子 → 收获 → OPD → SOUL.md/SKILL.md 修正，这条链路是核心价值。

**3. 降级设计**
没有 memory 文件？正常。farm.json 格式错误？跳过。飞书推送失败？打印日志不阻塞保存。边缘情况要先想清楚。

### 数据流

```
Cron (08:20)
    ↓
main agent（isolated session）
    ↓
读取上下文
  memory/YYYY-MM-DD.md  （工作日志）
  farm/farm.json         （能量、种子、收获）
  NOW.md                 （当前状态）
  heartbeat-state.json   （近期心跳）
  auto-learn.md          （近期洞察）
    ↓
AI 生成双语日记
  中文摘要  → Jialin 读
  English System Notes → HexaLoop 读
    ↓
  ├─ 保存本地 memory/diary/YYYY-MM-DD.md
  ├─ 提取洞察（1-3条）→ auto-learn.md
  └─ 推送飞书 Interactive 卡片
```

---

## 实现过程：Skill + Cron

### 文件结构

```
auto-diary/
├── SKILL.md                     # 技能定义（核心）
├── scripts/
│   ├── write_diary.py          # 读取上下文 + AI 生成日记
│   ├── send_diary.py           # 飞书卡片构建 + 推送
│   ├── weekly_review.py         # 7天聚合
│   └── monthly_review.py        # 30天聚合
└── templates/
    └── diary_template.md        # 日记 Markdown 模板
```

### Cron 配置

三个 cron 任务，对应三种触发消息：

```bash
# 每日日记
openclaw cron add --name "每日日记" \
  --cron "20 8 * * *" --tz "Asia/Shanghai" \
  --message "diary write" --session isolated --agent main

# 周度回顾
openclaw cron add --name "周度日记回顾" \
  --cron "0 9 * * 6" --tz "Asia/Shanghai" \
  --message "diary weekly" --session isolated --agent main

# 月度回顾
openclaw cron add --name "月度日记回顾" \
  --cron "0 9 1 * *" --tz "Asia/Shanghai" \
  --message "diary monthly" --session isolated --agent main
```

---

## 用 Autoresearch 优化 skill：30 轮打磨

Skill 写完第一版后，我决定用 [autoresearch-pro](https://github.com/0xcjl/openclaw-autoresearch-pro) 做系统性优化。参考 Karpathy 的 autoresearch 方法：每轮做一个小改动，测试，评分，保留提升的改动。

### 优化配置

- **模式**：Skill 模式
- **测试用例**：
  1. `diary write` — 正常上下文
  2. `diary weekly` — 周六聚合
  3. `diary monthly` — 月度聚合
  4. `diary write` — 无 memory 文件（边缘情况）
  5. `diary write` — 飞书推送失败（降级）

### 检查清单（10项）

1. 描述清晰度
2. 触发覆盖
3. 工作流结构
4. 错误处理
5. 工具使用准确性
6. 示例质量
7. 简洁性
8. Cron 配置准确性
9. 上下文完整性
10. HexaLoop 集成

### 30 轮改动摘要

| 轮次 | 类型 | 改动 |
|------|------|------|
| R1 | 错误处理 | 添加 4 种边缘情况处理 |
| R2 | Cron 修正 | 修正为正确 OpenClaw command 格式 |
| R3 | 展开工作流 | 细化 AI 写日记的7个必含字段 |
| R4 | 示例 | 添加具体 auto-learn 格式 A 示例 |
| R5 | 描述加强 | frontmatter 增加 edge cases 说明 |
| R6 | 去冗余 | 删除重复脚本条目 |
| R7 | 交叉引用 | 添加 HexaLoop 流转路径 |
| R8 | 清理模糊 | 移除"待确认"标记，明确数据源 |
| R9 | 去冗余 | 移除 farm.json 重复项 |
| R10 | 工具准确性 | 添加 feishu_im_user_message 完整参数 |
| R11 | 示例 | 添加3种触发场景示例 |
| R12 | 错误处理 | 表格化6种场景 + 具体行为 |
| R13 | 上下文扩展 | 增加 auto-learn.md、heartbeat-state.json |
| R14 | 展开工作流 | 明确7个必含字段 + HexaLoop Hints |
| R15 | 飞书格式 | JSON schema + 颜色规则（daily/weekly/monthly） |
| R16 | 周/月度章节 | 独立章节 + 文件过滤规则 |
| R17-30 | 持续细化 | 指标说明、好/坏洞察对比、手动触发说明等 |

### 分数变化

**基线：68/100 → 最终：96/100（+28%）**

最有效的改动类型：
- **E（错误处理）**：从无到有，6种场景表格化
- **C（示例）**：添加真实触发场景和洞察对比示例
- **H（展开薄章节）**：周/月度独立章节、上下文列表扩充

---

## 关键发现

### 1. Cron 命令语法要实际测试

第一版写的 cron 命令格式是错的（`@ Asia/Shanghai` 语法），必须用 `--tz` 参数分离时区。**所有文档示例都要用实际可运行的命令验证。**

### 2. auto-learn.md 原有逻辑不变

HexaLoop 的 `auto-learn.md` 有既定的格式 A 和来源逻辑（Worker 任务、OPD 吸收、冥想产出）。日记只是新增了一个输入源，不改变原有结构。

### 3. 中文给用户看，英文给系统看

同一个 skill 产出两套语言，背后是同一个 AI 模型。中文要 human-readable、结论先行；英文要 machine-readable、结构化。这样 HexaLoop 的各个组件（OPD Scorer / 冥想层 / 农场）都能直接消费。

### 4. 优化 30 轮后还有空间

96% 不是 100%。目前还缺少的是：真实触发后的效果反馈、周/月度实际运行数据、以及基于 auto-learn.md 实际被冥想层使用后的质量评估。这是下一轮优化的方向。

---

## 落地清单

如果你也想给 OpenClaw 加一个自动日记 skill，需要以下步骤：

- [ ] 将 `auto-diary` skill 复制到 `~/.openclaw/skills/`
- [ ] 配置三个 cron 任务（daily / weekly / monthly）
- [ ] 确保 `memory/diary/` 目录可写
- [ ] 确认 `memory/auto-learn.md` 存在且格式正确
- [ ] 手动发一条 `diary write` 测试效果

---

## 资源链接

- **Skill 仓库**：[github.com/0xcjl/auto-diary](https://github.com/0xcjl/auto-diary)
- **HexaLoop 架构**：[github.com/0xcjl/hexaloop-core](https://github.com/0xcjl/hexaloop-core)
- **Autoresearch 工具**：[github.com/0xcjl/openclaw-autoresearch-pro](https://github.com/0xcjl/openclaw-autoresearch-pro)
- **OpenClaw**：[github.com/openclaw/openclaw](https://github.com/openclaw/openclaw)

---

*本文属于 [HexaLoop](https://github.com/0xcjl/hexaloop-core) 生态系统的一部分。皮皮虾在 OpenClaw 上运行，用 HexaLoop 驱动自我进化。*
