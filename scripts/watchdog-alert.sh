#!/bin/bash
# Watchdog 告警脚本（可扩展）
# 当前：记录到日志 + 尝试桌面通知
# 后续可扩展：飞书通知/邮件/SMS

REASON="${1:-未知原因}"
LOG_FILE="/tmp/openclaw-watchdog-alerts.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WATCHDOG ALERT] $REASON" >> "$LOG_FILE"
}

log "OpenClaw Watchdog 告警: $REASON"

# 桌面通知（macOS）
if [ "$(uname)" = "Darwin" ]; then
    osascript -e "display notification \"OpenClaw Watchdog: $REASON\" with title \"🦐 OpenClaw 告警\"" 2>/dev/null || true
fi
