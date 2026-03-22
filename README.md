# OpenClaw Playbook

> OpenClaw 实战经验、教程与问题探讨。

本仓库用于记录在探索和使用 OpenClaw 过程中积累的经验、教程、最佳实践以及踩坑记录。

## 📖 文章目录

| 文章 | 简介 |
|------|------|
| [AI Agent 任务调度内幕](./docs/openclaw-agent-routing.md) | 为什么你说不清楚需求，AI 却能猜对？从关键词匹配到 LLM 深度推理的三层任务路由机制拆解 |
| [Gateway 自动重启防护体系](./docs/openclaw-auto-restart.md) | 无论配置错误、系统重启还是意外崩溃，Gateway 都能自动恢复的完整方案 |

## 🛠️ 配套脚本

| 脚本 | 用途 |
|------|------|
| `restart-gateway-safe.sh` | 配置安全重启脚本（含回滚机制） |
| `watchdog.sh` | Crash Loop 熔断器 |
| `watchdog-alert.sh` | Watchdog 告警脚本 |
| `apply-agent-models.sh` | 模型配置更新安全封装 |
| `ai.openclaw.gateway.plist` | macOS launchd 自启动配置 |

详细内容请阅读对应的文档。

## 📝 投稿

如果你也在使用 OpenClaw，欢迎分享你的经验！可以通过 Pull Request 提交文章或脚本。

---

*Powered by [OpenClaw](https://github.com/openclaw/openclaw)*
