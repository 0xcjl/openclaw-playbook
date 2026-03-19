#!/bin/bash
# OpenClaw Watchdog - 防 Crash Loop 脚本
# 用途：Gateway 崩溃后带熔断机制的重启，防止无限重启循环
#
# 熔断逻辑：
# - 5 分钟内崩溃 2 次：发送警告邮件（仍继续重启）
# - 5 分钟内崩溃 ≥ 3 次：熔断（停止重启），发送紧急邮件，等待人工介入
# - 熔断后 15 分钟自动解除

set -e

STATE_DIR="$HOME/.openclaw/.watchdog"
CRASH_LOG="$STATE_DIR/crash_history"
FUSE_FILE="$STATE_DIR/fuse_blown"
EMAIL_WARNING="jialin.crypto@gmail.com"
EMAIL_FROM="jialin@ultici.com"

FUSE_TIMEOUT=900      # 15 分钟熔断期
WARN_CRASHES=2         # 触发警告邮件的崩溃次数
MAX_CRASHES=3         # 触发熔断的崩溃次数
WINDOW_SECONDS=300     # 5 分钟时间窗口

GATEWAY_PID=""
LOG_FILE="/tmp/openclaw-watchdog.log"

# ──────────────────────────────────────────
# 工具函数
# ──────────────────────────────────────────

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

mkdir -p "$STATE_DIR"

# ──────────────────────────────────────────
# 邮件发送（无外部依赖，直接 curl）
# ──────────────────────────────────────────

send_email() {
    local to="$1"
    local subject="$2"
    local body="$3"

    log "📧 发送邮件到 $to: $subject"

    # 使用本地 sendmail 或 msmtp
    if [ -x /usr/sbin/sendmail ]; then
        printf "Subject: %s\n\n%s" "$subject" "$body" | /usr/sbin/sendmail -f "$EMAIL_FROM" "$to"
    elif [ -x /usr/local/bin/msmtp ]; then
        printf "Subject: %s\n\n%s" "$subject" "$body" | /usr/local/bin/msmtp -f "$EMAIL_FROM" "$to"
    else
        log "⚠️  未找到邮件发送工具（sendmail/msmtp），邮件未发送: $subject"
        return 1
    fi
}

# ──────────────────────────────────────────
# 熔断器
# ──────────────────────────────────────────

is_fuse_blown() {
    [ ! -f "$FUSE_FILE" ] && return 1

    local fuse_time=$(stat -f "%m" "$FUSE_FILE" 2>/dev/null || echo "0")
    local now=$(date +%s)
    local elapsed=$((now - fuse_time))

    if [ $elapsed -ge $FUSE_TIMEOUT ]; then
        rm -f "$FUSE_FILE"
        log "🟢 熔断期已过（15min），自动解除"
        return 1
    fi

    local remaining=$((FUSE_TIMEOUT - elapsed))
    log "🛑 熔断生效中，${remaining}s 后自动解除"
    return 0
}

blow_fuse() {
    log "⚠️  触发熔断！"
    touch "$FUSE_FILE"
}

get_recent_crashes() {
    local now=$(date +%s)
    local crashes=0

    [ ! -f "$CRASH_LOG" ] && echo "0" && return

    while read -r ts; do
        [ -z "$ts" ] && continue
        local age=$((now - ts))
        if [ $age -lt $WINDOW_SECONDS ]; then
            crashes=$((crashes + 1))
        fi
    done < "$CRASH_LOG"

    echo "$crashes"
}

record_crash() {
    local now=$(date +%s)

    # 追加本次崩溃时间戳
    echo "$now" >> "$CRASH_LOG"

    # 清理过期记录（保留所有，读取时过滤）
    # 同时去重排序
    sort -n "$CRASH_LOG" | uniq > "$CRASH_LOG.tmp"
    mv "$CRASH_LOG.tmp" "$CRASH_LOG"

    # 统计窗口内崩溃次数
    local count
    count=$(get_recent_crashes)
    echo "$count"
}

# ──────────────────────────────────────────
# 健康检查
# ──────────────────────────────────────────

check_health() {
    curl -s --max-time 3 http://127.0.0.1:18789/health > /dev/null 2>&1
}

is_gateway_running() {
    pgrep -f "openclaw gateway" > /dev/null 2>&1
}

# ──────────────────────────────────────────
# 主逻辑
# ──────────────────────────────────────────

log "🐕 Watchdog 检查触发"

# 1. 熔断检查
if is_fuse_blown; then
    log "⚠️  熔断状态，跳过重启"
    exit 1
fi

# 2. 检查 Gateway 是否真的挂了
if check_health; then
    # 健康，说明之前误检测，清除旧崩溃记录
    [ -f "$CRASH_LOG" ] && : > "$CRASH_LOG"
    log "✅ Gateway 健康（上次报警为误报）"
    exit 0
fi

# 3. Gateway 确实挂了 — 记录崩溃
local crash_count
crash_count=$(record_crash)
log "💥 Gateway 崩溃（5分钟内第 $crash_count 次）"

# 4. 崩溃 2 次 → 警告邮件（继续尝试重启）
if [ "$crash_count" -eq "$WARN_CRASHES" ]; then
    log "📧 触发警告（2次崩溃）"
    blow_fuse  # 临时熔断标记，用于区分状态
    send_email "$EMAIL_WARNING" \
        "⚠️ OpenClaw Watchdog 警告 — 5分钟内崩溃2次" \
        "OpenClaw Gateway 在 5 分钟内崩溃 2 次，已自动重启。\n\n\
当前状态：重启继续监控中\n\
时间：$(date '+%Y-%m-%d %H:%M:%S %Z')\n\
崩溃历史：$(cat $CRASH_LOG 2>/dev/null || echo '无')\n\n\
如崩溃持续，请检查：\n  - 日志：tail -50 /tmp/openclaw-gateway.log\n  - 配置：cat ~/.openclaw/openclaw.json\n\n\
此为警告邮件，Watchdog 继续监控中。"
    # 解除临时熔断，继续重启
    rm -f "$FUSE_FILE"
    log "✅ 警告邮件已发送，继续重启"
fi

# 5. 崩溃 ≥ 3 次 → 熔断 + 紧急邮件 + 停止重启
if [ "$crash_count" -ge "$MAX_CRASHES" ]; then
    blow_fuse
    log "🚨 触发熔断（3次崩溃），停止重启"

    local crash_details
    crash_details=$(cat $CRASH_LOG 2>/dev/null | while read -r ts; do
        echo "  崩溃时间: $(date -r $ts '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo $ts)"
    done)

    send_email "$EMAIL_WARNING" \
        "🚨 OpenClaw Watchdog 熔断 — 5分钟内崩溃3次，Gateway 已停止" \
        "OpenClaw Gateway 在 5 分钟内崩溃 3 次，Watchdog 已停止自动重启，等待人工介入。\n\n\
⚠️ 状态：Gateway 已停止\n\
熔断时间：$(date '+%Y-%m-%d %H:%M:%S %Z')\n\
熔断解除：15 分钟后自动解除\n\n\
$crash_details\n\n\
请人工检查：\n  1. 查看日志：tail -100 /tmp/openclaw-gateway.log\n  2. 检查配置：cat ~/.openclaw/openclaw.json\n  3. 手动重启：bash ~/.openclaw/workspace/scripts/restart-gateway-safe.sh\n\n\
如需立即重启，请登录服务器执行 restart-gateway-safe.sh"

    log "📧 紧急邮件已发送，等待人工介入"
    exit 1
fi

# 6. 执行安全重启
log "🔄 执行安全重启（剩余 $((WARN_CRASHES - crash_count)) 次机会）"
bash "$HOME/.openclaw/workspace/scripts/restart-gateway-safe.sh"
RESULT=$?

if [ $RESULT -eq 0 ]; then
    log "✅ 重启成功，监控继续"
else
    log "❌ 安全重启失败，记录崩溃"
    # 重启失败会被下一次 watchdog 调用捕获
    exit 1
fi
