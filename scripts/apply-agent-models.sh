#!/bin/bash
# 同步 MiniMax M2.7 配置到 OpenClaw
# 使用安全重启脚本，自动处理配置错误回滚

CONFIG_FILE="$HOME/.openclaw/openclaw.json"
BACKUP_FILE="$HOME/.openclaw/openclaw.json.model-backup-$(date +%Y%m%d-%H%M%S)"

echo "📦 备份当前配置..."
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo "   备份: $BACKUP_FILE"

echo "🔧 更新所有 Agent 的模型配置..."

# 使用 jq 更新配置
# 1. 所有 Agent 的 primary → MiniMax-M2.7
# 2. main agent 添加 claude-sonnet-4-6 fallback
# 3. 其他 Agent 保持原有 fallback 不变
jq '
  # 更新 defaults
  .agents.defaults.model.primary = "minimax-cp/MiniMax-M2.7" |

  # 更新所有 Agent 的 primary 模型为 M2.7
  .agents.list = [
    .agents.list[] |
    .model.primary = "minimax-cp/MiniMax-M2.7"
  ] |

  # 特别处理 main agent 的 fallback
  .agents.list = [
    .agents.list[] |
    if .id == "main" then
      .model.fallbacks = ["claude-openclaw/claude-sonnet-4-6"]
    else
      .
    end
  ]
' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"

# 检查 jq 是否成功
if [ $? -eq 0 ]; then
  mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
  echo "✅ 配置更新成功"
else
  echo "❌ 配置更新失败（jq 解析错误）"
  rm -f "$CONFIG_FILE.tmp"
  exit 1
fi

echo "🔄 使用安全脚本重启 Gateway（自动处理配置错误回滚）..."
bash ~/.openclaw/workspace/scripts/restart-gateway-safe.sh
RESTART_RESULT=$?

if [ $RESTART_RESULT -eq 0 ]; then
  echo ""
  echo "✅ MiniMax M2.7 配置完成并验证通过"
  echo "📄 配置备份: $BACKUP_FILE"
else
  echo ""
  echo "⚠️  重启遇到问题（已尝试自动回滚）"
  echo "📄 手动恢复: cp $BACKUP_FILE $CONFIG_FILE"
  exit 1
fi
