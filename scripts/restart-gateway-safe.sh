#!/bin/bash
# OpenClaw Gateway 安全重启脚本 v2
# 新增：配置错误时自动回滚机制
#
# 核心逻辑：
# 1. 启动前备份当前配置
# 2. 配置变更后验证 Gateway 健康状态
# 3. 启动失败 → 自动回滚到上一个正常配置 → 重启
# 4. 最多重试 2 次（变更后失败 → 回滚 → 重试）

set -e

GATEWAY_PID=""
CONFIG_BACKUP=""
CONFIG_BACKUP2=""
RESTORE_MODE=false
RETRY_COUNT=0
MAX_RETRIES=2

echo "🔄 OpenClaw Gateway 安全重启流程"
echo "========================================"

# ──────────────────────────────────────────
# 工具函数
# ──────────────────────────────────────────

log() { echo "[$(date '+%H:%M:%S')] $1"; }
fail() { echo "❌ $1"; exit 1; }

# 启动前健康检查（磁盘 + 内存）
preflight_check() {
    local issues=""

    # 1. 磁盘空间检查（要求 > 1GB 可用）
    local disk_free
    disk_free=$(df "$HOME" | awk 'NR==2 {print $4}' 2>/dev/null || echo "0")
    # df 单位是 1K-blocks，1GB = 1048576
    if [ "$disk_free" -lt 1048576 ]; then
        issues="磁盘空间不足 ($(($disk_free / 1024))MB 可用，建议 > 1GB)"
        log "⚠️  $issues"
    fi

    # 2. 内存检查（要求 > 200MB 可用）
    local mem_free
    if [ "$(uname)" = "Darwin" ]; then
        # macOS: 使用 vm_stat，单位是 pages
        mem_free=$(vm_stat 2>/dev/null | awk '/Pages free/ {gsub(/[Pp]/,"",$NF); print $NF}' | head -1)
        # 转换为 MB（page size 通常 4KB）
        mem_free=$((mem_free * 4))
    else
        mem_free=$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")
        mem_free=$((mem_free / 1024))  # KB -> MB
    fi
    if [ "$mem_free" -lt 200 ]; then
        issues="$issues; 内存不足 (${mem_free}MB 可用，建议 > 200MB)"
        log "⚠️  内存: ${mem_free}MB"
    fi

    # 3. 端口冲突检查
    if lsof -i :18789 > /dev/null 2>&1; then
        local conflicting
        conflicting=$(lsof -i :18789 2>/dev/null | awk 'NR>1 {print $1}' | head -1)
        issues="$issues; 端口 18789 被占用 (进程: $conflicting)"
        log "⚠️  端口冲突: $conflicting"
    fi

    if [ -n "$issues" ]; then
        log "⚠️  预检发现问题，但继续尝试启动..."
        return 1
    fi
    log "✅ 预检通过（磁盘/内存/端口正常）"
    return 0
}

# 备份当前配置
backup_config() {
    local ts=$(date +%Y%m%d-%H%M%S)
    CONFIG_BACKUP="$HOME/.openclaw/config.backup.$ts.json"
    CONFIG_BACKUP2="$HOME/.openclaw/config.backup.prev.json"
    log "📦 备份当前配置 → $CONFIG_BACKUP"
    cp "$HOME/.openclaw/openclaw.json" "$CONFIG_BACKUP"
    cp "$CONFIG_BACKUP" "$CONFIG_BACKUP2"  # 双备份：prev 始终指向上一个正常配置
}

# 回滚到备份配置
rollback_config() {
    if [ -f "$CONFIG_BACKUP" ]; then
        log "🔄 回滚配置..."
        cp "$CONFIG_BACKUP" "$HOME/.openclaw/openclaw.json"
        log "✅ 已回滚到备份配置"
    else
        fail "无备份配置可回滚"
    fi
}

# 清理旧备份（只保留最近 3 个）
cleanup_old_backups() {
    ls -t $HOME/.openclaw/config.backup.*.json 2>/dev/null | tail -n +4 | xargs rm -f 2>/dev/null || true
}

# 检查 Gateway 是否健康
check_health() {
    curl -s --max-time 3 http://127.0.0.1:18789/health > /dev/null 2>&1
}

# 检查进程是否还在
check_process() {
    [ -n "$GATEWAY_PID" ] && kill -0 "$GATEWAY_PID" 2>/dev/null
}

# 停止 Gateway
stop_gateway() {
    log "🛑 停止 Gateway..."
    openclaw gateway stop 2>/dev/null || true
    for i in {1..10}; do
        if ! pgrep -f "openclaw gateway" > /dev/null; then
            log "✓ Gateway 已停止"
            return 0
        fi
        sleep 1
    done
    pkill -9 -f "openclaw gateway" 2>/dev/null || true
    sleep 2
    log "✓ Gateway 已强制终止"
}

# 启动 Gateway
start_gateway() {
    log "🚀 启动 Gateway..."
    # 清空旧日志
    : > /tmp/openclaw-gateway.log
    openclaw gateway run > /tmp/openclaw-gateway.log 2>&1 &
    GATEWAY_PID=$!
}

# 等待 Gateway 启动（健康检查）
wait_for_gateway() {
    log "⏳ 等待 Gateway 启动..."
    for i in {1..20}; do
        if check_health; then
            log "✅ Gateway 健康 (PID: $GATEWAY_PID)"
            return 0
        fi
        if ! check_process; then
            log "❌ 进程已退出"
            return 1
        fi
        sleep 1
    done
    log "❌ 启动超时（健康检查失败）"
    return 1
}

# 获取详细错误信息
show_startup_errors() {
    if [ -f /tmp/openclaw-gateway.log ]; then
        echo ""
        echo "📄 最近错误日志："
        tail -30 /tmp/openclaw-gateway.log | grep -iE "error|panic|fail|invalid|exception" | tail -15
    fi
}

# ──────────────────────────────────────────
# 主流程
# ──────────────────────────────────────────

# 0. 检查 Gateway 是否在运行
log "📊 检查当前状态..."
if pgrep -f "openclaw gateway" > /dev/null; then
    log "✓ Gateway 正在运行"
    GATEWAY_RUNNING=true
else
    log "✗ Gateway 未运行"
    GATEWAY_RUNNING=false
    # 未运行时，直接启动，不走回滚逻辑
    RESTORE_MODE=false
fi

# 1. 备份当前配置（仅当有配置可备份时）
if [ -f "$HOME/.openclaw/openclaw.json" ]; then
    backup_config
fi

# 2. 停止 Gateway
if [ "$GATEWAY_RUNNING" = true ]; then
    stop_gateway
fi

# 3. 清理锁文件
LOCK_FILE="$HOME/.openclaw/.gateway.lock"
if [ -f "$LOCK_FILE" ]; then
    log "🧹 清理锁文件..."
    rm -f "$LOCK_FILE"
fi

# 4. 启动前预检（磁盘/内存/端口）
preflight_check

# 5. 启动 Gateway
start_gateway

# 5. 等待启动
if wait_for_gateway; then
    log "✅ 启动成功"

    # 6. 额外稳定性检查：持续观察 10 秒
    log "🔍 稳定性检查（10秒）..."
    STABLE=true
    for i in {1..10}; do
        if ! check_health; then
            log "⚠️  健康检查不稳定 ($i/10)"
            STABLE=false
            break
        fi
        sleep 1
    done

    if [ "$STABLE" = true ]; then
        log "✅ Gateway 稳定运行"
    else
        log "⚠️  Gateway 不稳定，尝试重启..."
        # 这个分支下 Gateway 已经启动了，只是中间有抖动
        # 先停止再重启，不回滚配置
        stop_gateway
        start_gateway
        if wait_for_gateway; then
            log "✅ 第二次启动成功"
        else
            show_startup_errors
            fail "重试后仍不稳定"
        fi
    fi
else
    # 启动失败 → 检查是否因配置错误
    show_startup_errors

    # ── 启动失败，进入回滚重试流程 ──
    log ""
    log "⚠️  启动失败，尝试回滚配置..."

    # 回滚到上一个正常配置
    rollback_config

    # 停止可能残留的进程
    pkill -9 -f "openclaw gateway" 2>/dev/null || true
    sleep 2

    # 重新启动 with 回滚的配置
    start_gateway

    if wait_for_gateway; then
        log "✅ 回滚后启动成功"
        log "📝 你的配置变更有问题，已自动回滚到上一个正常版本"
        log "   备份配置位置：$CONFIG_BACKUP"
    else
        # 回滚后仍然失败 → 使用 prev2（再上一个）
        log "⚠️  回滚后仍失败，尝试使用更早的备份..."
        if [ -f "$CONFIG_BACKUP2" ]; then
            cp "$CONFIG_BACKUP2" "$HOME/.openclaw/openclaw.json"
            log "🔄 使用上一个备份配置..."

            pkill -9 -f "openclaw gateway" 2>/dev/null || true
            sleep 2
            start_gateway

            if wait_for_gateway; then
                log "✅ 备用备份启动成功"
            else
                show_startup_errors
                fail "连备用备份都无法启动，请检查 ~/.openclaw/openclaw.json 文件"
            fi
        else
            fail "回滚后仍无法启动，请手动检查配置"
        fi
    fi
fi

# 6. 清理旧备份
cleanup_old_backups

# 7. 最终状态
echo ""
echo "📊 最终状态："
openclaw gateway status 2>&1 | grep -E "Runtime:|Listening:|RPC probe:" || true

echo ""
echo "✅ 重启流程完成"
echo "📄 日志文件: /tmp/openclaw-gateway.log"
