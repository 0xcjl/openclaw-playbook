# OpenClaw Playbook

> OpenClaw 实战经验、教程与问题探讨。

本仓库用于记录在探索和使用 OpenClaw 过程中积累的经验、教程、最佳实践以及踩坑记录。

## 📖 文章目录

| 文章 | 简介 |
|------|------|
| [从 HexaLoop 反思到自动日记：皮皮虾如何学会"每天总结自己"](./docs/auto-diary-skill.md) | 皮皮虾自动日记 skill 从设计到 30 轮 autoresearch 优化的完整复盘：中英双语输出、HexaLoop 反馈闭环、周/月度聚合 |
| [我是如何让 AI Agent 理解模糊需求的](./docs/openclaw-agent-routing.md) | Jialin 的实践总结：三层任务路由方法（关键词初筛 → 语义理解 → LLM 深度推理），附实践发现和踩坑经验 |
| [Gateway 自动重启防护体系](./docs/openclaw-auto-restart.md) | 无论配置错误、系统重启还是意外崩溃，Gateway 都能自动恢复的完整方案 |
| [Ask Don't Tell：让 LLM 不再谄媚的50条实战 Prompt](./docs/sycophancy-prompt-research.md) | 基于 arXiv 论文研究整理：为什么"问法"比"指令"更有效，6大场景50条对比Prompt及三条底层逻辑 |
| [从"看见"到"做到"：browser-cdp 浏览器自动化实践](./docs/browser-cdp-toolchain.md) | 三层工具链（agent-reach + browser-cdp + agent-browser）的设计思路、Phase 1-3 测试结论与真实应用场景 |
| [浏览器自动化工具全景图：三个工具的组合战术](./docs/browser-tools-strategy.md) | agent-browser / browser-cdp / browser-use 三层分工详解：为什么需要三个工具、如何组合使用、怎么省 Token，附架构全景图 |
| [技能精简复盘：从 11 个工具到 5 核心的自我达尔文主义](./docs/browser-web-tools-optimization.md) | 一次真实的 Skills 盘点与精简：如何发现重叠、如何做决策、什么时候该做这类优化，附完整四步方法论 |
| [如何在 OpenClaw 上构建本地优先的多 Agent 记忆系统](./docs/memory-system-architecture.md) | 皮皮虾的 6 次迭代实践：MEMORY.md → WAL → DAG → BM25，本地优先、零依赖、可追溯的多 Agent 记忆系统完整方案 |


## 📝 投稿

如果你也在使用 OpenClaw，欢迎分享你的经验！可以通过 Pull Request 提交文章或脚本。

---

*Powered by [OpenClaw](https://github.com/openclaw/openclaw)*
