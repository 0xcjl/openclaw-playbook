# OpenClaw Gateway 自动重启防护体系

> 无论配置错误、系统重启还是意外崩溃，Gateway 都能自动恢复。
> 适用于：macOS（launchd）/ Linux（systemd）环境下运行 OpenClaw 的个人用户或团队。
> 提示：如果要安装这个自动重启防护体系，直接把链接丢给龙虾🦞或 Claude code 操作，没必要费劲去自己操作。

---

## 一、问题描述：为什么需要自动重启

OpenClaw Gateway 是整个系统的核心枢纽——所有 Agent、插件、外部渠道（飞书、Discord 等）都通过它通信。一旦 Gateway 挂掉，整个系统等同于瘫痪。

实际运行中，Gateway 面临以下几种挂机风险：

| 风险类型 | 触发场景 | 后果 |
|---------|---------|------|
| **配置错误** | 修改 `openclaw.json` 后重启 | Gateway 无法启动，配置已覆盖无法回滚 |
| **Crash Loop** | Bug 或内存问题导致反复崩溃 | 无限重启，CPU 100%，无法正常服务 |
| **系统重启** | Mac mini 断电/更新重启 | Gateway 不会自启动，需人工登录 |
| **资源耗尽** | 磁盘满/内存不足 | Gateway 启动后立即 OOM |
| **端口冲突** | 其他进程占用 18789 端口 | Gateway 启动失败 |

在没有防护体系的情况下，以上每一种场景都需要人工登录服务器干预。对于一个 7×24 小时运行的服务，这显然是不可接受的。

---

## 二、设计思路：三个核心原则

### 2.1 分层防护，而非单点打补丁

不要试图在单一脚本里解决所有问题，而是按职责分层：

```
第一层：启动前预检（把常见问题拦截在门外）
         ↓
第二层：启动后稳定性观察（捕捉启动后立即崩溃的情况）
         ↓
第三层：配置回滚机制（确保配置错误可恢复）
         ↓
第四层：Crash Loop 熔断器（防止无限重启）
         ↓
第五层：系统级自启动（覆盖系统重启场景）
```

每一层只管一件事，层与层之间互不依赖。

### 2.2 原子性配置变更

配置变更和 Gateway 重启必须打包执行——不能先改配置，然后假设重启一定会成功。要把"备份 → 变更 → 验证"做成一个原子操作，失败时自动回滚。

### 2.3 本地化判断，减少外部依赖

健康检查全部使用本地端口探测（`curl http://127.0.0.1:18789/health`），不依赖任何外部服务。告警邮件使用系统自带的 `sendmail`，不依赖第三方邮件 SDK。

---

## 三、具体方案：七个组件

### 3.1 restart-gateway-safe.sh — 配置安全重启脚本

**文件位置**：`~/.openclaw/workspace/scripts/restart-gateway-safe.sh`

**核心逻辑**：

```
启动前备份当前配置（双备份：带时间戳 + prev）
        ↓
预检：磁盘空间 > 1GB、内存 > 200MB、端口无冲突
        ↓
停止当前 Gateway（优雅停止，10秒超时后强制杀）
        ↓
清理锁文件（防止旧进程残留）
        ↓
启动 Gateway
        ↓
健康检查（20秒超时）
        ↓
稳定性观察（持续10秒，每秒检查一次）
        ↓
若中间任何一步失败：
  → 回滚到备份配置 → 再次重启
  → 若仍失败 → 使用更早的备份 → 再次重启
  → 若仍失败 → 退出，保留两个备份供手工恢复
```

**关键设计原因**：

- **双备份机制**：避免配置错误时唯一的备份也被覆盖。`backup.{ts}.json` 保留每次操作的备份，`backup.prev.json` 始终指向上一个确认可用的配置。
- **稳定性观察 10 秒**：Gateway 进程在 ≠ 健康。某些配置错误（模型路径错误、插件加载失败）会导致进程启动后几秒才崩溃。只检查进程存在是不够的。
- **回滚后重新重启**：回滚后不是直接退出，而是再给一次机会重启，确保回滚配置本身是可用的。

---

### 3.2 watchdog.sh — Crash Loop 熔断器

**文件位置**：`~/.openclaw/workspace/scripts/watchdog.sh`

**触发方式**：每分钟通过 cron 执行（`* * * * *`）

**熔断逻辑**：

```
Gateway 健康检查（本地 curl）
        ↓
异常：
  记录崩溃时间戳（sliding window 5分钟）
        ↓
5 分钟内崩溃 1 次 → 正常重启
5 分钟内崩溃 2 次 → 警告邮件 ⚠️（继续重启）
5 分钟内崩溃 ≥ 3 次 → 熔断 🚨（停止重启，紧急邮件）
        ↓
15 分钟后熔断自动解除（防止永久挂死）
```

**关键设计原因**：

- **为什么要熔断？** 如果 5 分钟内崩溃 3 次，说明问题不是偶发的，是系统性错误。继续重启没有意义，只会造成资源浪费和日志噪音。
- **为什么要 15 分钟后自动解除？** 防止熔断状态永久锁死。如果半夜触发熔断，人工不可能秒级响应。15 分钟后自动解除，Watchdog 继续监控，给系统一个自愈的机会。
- **2 次崩溃就发警告邮件**：在熔断之前先预警，让用户提前知道系统可能有问题，而不是等彻底停了再收到紧急邮件。

**邮件内容**包含：当前崩溃次数、崩溃时间戳列表、日志路径、手动恢复命令。

---

### 3.3 launchd / systemd — 系统级自启动

#### macOS：launchd

**文件位置**：`~/Library/LaunchAgents/ai.openclaw.gateway.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>ai.openclaw.gateway</string>

    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/openclaw</string>
        <string>gateway</string>
        <string>run</string>
    </array>

    <key>WorkingDirectory</key>
    <string>/Users/你的用户名/.openclaw</string>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>

    <key>StandardOutPath</key>
    <string>/tmp/openclaw-launchd.stdout.log</string>

    <key>StandardErrorPath</key>
    <string>/tmp/openclaw-launchd.stderr.log</string>
</dict>
</plist>
```

**加载方式**：
```bash
# 加载（系统重启后自动生效）
launchctl load ~/Library/LaunchAgents/ai.openclaw.gateway.plist

# 验证是否运行
launchctl list | grep openclaw
```

#### Linux / VPS / 树莓派：systemd

**文件位置**：`/etc/systemd/system/openclaw-gateway.service`

```ini
[Unit]
Description=OpenClaw Gateway
After=network.target

[Service]
Type=simple
User=你的用户名
WorkingDirectory=/home/你的用户名/.openclaw
ExecStart=/usr/local/bin/openclaw gateway run
Restart=always
RestartSec=5
StandardOutput=append:/tmp/openclaw-stdout.log
StandardError=append:/tmp/openclaw-stderr.log

[Install]
WantedBy=multi-user.target
```

**启用方式**：
```bash
sudo systemctl daemon-reload
sudo systemctl enable openclaw-gateway   # 开机自启
sudo systemctl start openclaw-gateway   # 立即启动

# 验证状态
sudo systemctl status openclaw-gateway
```

**为什么用 `Restart=always`**：Gateway 任何原因退出（崩溃/被 kill/系统资源不足），systemd 都会在 5 秒后自动重新拉起。这比 launchd 的 `KeepAlive` 更直接。

> ⚠️ **VPN 注意事项**：macOS launchd 和 systemd 服务在系统层面启动，不继承用户态 VPN 代理。如果 Gateway 依赖 VPN 翻墙，建议改用用户登录后自动启动脚本（见 3.8 节）。

---

### 3.4 apply-agent-models.sh — 配置变更的安全封装

**文件位置**：`~/.openclaw/workspace/scripts/apply-agent-models.sh`

**核心逻辑**：

```
备份当前配置（带时间戳）
        ↓
jq 更新模型配置
        ↓
调用 restart-gateway-safe.sh 执行安全重启
        ↓
验证：若重启失败 → 已自动回滚 → 报错退出
```

**关键设计原因**：把 `restart-gateway-safe.sh` 作为通用能力的调用方，而非在每个配置变更脚本里重复写重启 + 回滚逻辑。所有后续的配置变更脚本只需调用这一个安全重启入口。

---

### 3.5 cron 定时任务 — 看门狗心跳

**cron 条目**：`每分钟执行 watchdog.sh`

```cron
* * * * * bash ~/.openclaw/workspace/scripts/watchdog.sh >> ~/.openclaw/workspace/logs/watchdog.log 2>&1
```

**为什么用 cron 而不是 launchd 定时器**：cron 是系统标配，无需额外配置，且与 launchd/systemd 互为补充——系统服务拉起 Gateway 进程，cron 的 Watchdog 守护 Gateway 进程。

---

### 3.6 邮件配置 — 让告警邮件真正能发出去

Watchdog 的崩溃告警依赖邮件发送。多数系统默认没有配置 `sendmail`，需要手动设置。以下提供两种最简方案。

#### 方案一：msmtp（推荐，通用）

`msmtp` 是一个轻量级 SMTP 客户端，配置比 sendmail 简单得多。

**1. 安装 msmtp**

```bash
# macOS
brew install msmtp

# Ubuntu/Debian
sudo apt install msmtp msmtp-mta

# CentOS/RHEL
sudo yum install msmtp
```

**2. 配置 msmtp（以 QQ 邮箱/QQ企业邮箱为例）**

```bash
cat > ~/.msmtprc << 'EOF'
account        default
host           smtp.qq.com
port           587
from           你的邮箱@qq.com
user           你的邮箱@qq.com
password       你的授权码（非登录密码）
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        ~/.msmtp.log
EOF

chmod 600 ~/.msmtprc   # 安全性：仅自己可读
```

**3. 获取邮箱授权码**

| 邮箱类型 | 获取方式 |
|---------|---------|
| QQ 邮箱 | QQ 邮箱网页 → 设置 → 账户 → 开启「IMAP/SMTP服务」→ 获取授权码 |
| Gmail | Google Account → 安全性 → 两步验证 → 应用密码 → 生成「邮件」的应用密码 |
| 企业邮箱 | 管理员后台 → 邮箱设置 → 客户端授权 |

**4. 验证发送**

```bash
echo -e "Subject: test\n\nOpenClaw 邮件测试" | msmtp -v 你的邮箱@gmail.com
```

**5. 让系统默认使用 msmtp 发送邮件**

```bash
# macOS
sudo ln -sf /opt/homebrew/bin/msmtp /usr/sbin/sendmail

# Linux
sudo ln -sf /usr/bin/msmtp /usr/sbin/sendmail
```

#### 方案二：直接使用已有域名邮箱（适合有 Postfix/MTA 的服务器）

```bash
# 验证 sendmail 是否指向正确
which sendmail
sendmail -bv 你的邮箱@gmail.com  # 测试发送
```

> ⚠️ **重要**：Watchdog 邮件依赖 `sendmail` 命令可用。建议使用方案一配置 msmtp 后创建符号链接，这是最简单可靠的方式。

---

### 3.7 架构总览图

```
┌──────────────────────────────────────────────────────┐
│                    系统层                              │
│  launchd (macOS) / systemd (Linux)                   │
│  → 系统重启自拉起 + 意外崩溃自动恢复                    │
└──────────────────────┬───────────────────────────────┘
                       │
┌──────────────────────▼───────────────────────────────┐
│                   cron（每分钟）                       │
│              watchdog.sh                              │
│  ┌───────────────────────────────────────────────┐   │
│  │ ① check_health → 正常 → 清除崩溃记录 → 退出  │   │
│  │ ② 异常 → record_crash                         │   │
│  │    ├── 1次 → 重启                              │   │
│  │    ├── 2次 → ⚠️ 警告邮件 → 继续重启           │   │
│  │    └── ≥3次 → 🚨 熔断 + 紧急邮件 → 停止重启   │   │
│  └───────────────────────────────────────────────┘   │
└──────────────────────┬───────────────────────────────┘
                       │ 重启请求
┌──────────────────────▼───────────────────────────────┐
│            restart-gateway-safe.sh                     │
│  ① preflight_check（磁盘/内存/端口）                   │
│  ② backup_config × 2                                  │
│  ③ stop → lock清理 → start                           │
│  ④ wait_for_health（20s）                            │
│  ⑤ stability_check（10s）                            │
│  失败 → rollback → retry → retry_fallback            │
└───────────────────────────────────────────────────────┘
```

---

### 3.8 无 VPN 代理场景的补充方案

launchd 和 systemd 在系统层面启动，不继承用户态 VPN 代理（如 Clash、Surge）。如果 Gateway 依赖 VPN 连接外部模型，需在用户登录后以用户进程方式运行。

**macOS 解决方案：Login Item**

```bash
# 方式一：命令行（推荐）
# 添加 OpenClaw 到登录项
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/opt/homebrew/bin/openclaw", hidden:false}'

# 方式二：系统偏好设置
# 系统偏好设置 → 用户与群组 → 登录项 → 添加 openclaw
```

**Linux 解决方案：用户级 systemd**

```bash
# 创建用户级服务（不需要 sudo）
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/openclaw-gateway.service << 'EOF'
[Unit]
Description=OpenClaw Gateway (User)

[Service]
Type=simple
ExecStart=/usr/local/bin/openclaw gateway run
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable openclaw-gateway
systemctl --user start openclaw-gateway

# 确保用户 systemd 在登录时启动
loginctl enable-linger  # 需要 sudo
```

---

## 四、总结

本方案的核心价值在于：**把"人工干预"从重启流程中彻底移除**。

三层关键能力：

1. **配置回滚**：修改任何配置前先备份，出问题自动回滚，不依赖人工记忆备份文件位置。
2. **熔断器**：防止配置错误或系统故障引发的无限重启循环，同时通过邮件让用户在第一时间知情。
3. **系统级自启动**：覆盖"系统重启"这个最高级别的故障场景，真正实现 7×24 无人值守。

部署本方案后，系统可以应对以下所有场景并自动恢复：

| 场景 | 是否可自动恢复 |
|------|--------------|
| 配置错误（如模型名写错） | ✅ 自动回滚 |
| Crash Loop（反复崩溃） | ✅ 熔断 + 邮件告警 |
| 系统重启（断电/更新） | ✅ launchd / systemd 自拉起 |
| 磁盘空间不足 | ✅ 预检拦截 |
| 端口被其他进程占用 | ✅ 预检拦截 |
| 内存耗尽（OOM） | ⚠️ 预检降低概率，但仍需人工介入 |
| 硬件故障 | ❌ 不在讨论范围内 |

---

## 附录：快速部署

```bash
# 1. 下载脚本
mkdir -p ~/.openclaw/workspace/scripts ~/.openclaw/workspace/logs
curl -o ~/.openclaw/workspace/scripts/restart-gateway-safe.sh \
  https://your-script-url/restart-gateway-safe.sh
curl -o ~/.openclaw/workspace/scripts/watchdog.sh \
  https://your-script-url/watchdog.sh
chmod +x ~/.openclaw/workspace/scripts/*.sh

# 2. macOS 安装 launchd
curl -o ~/Library/LaunchAgents/ai.openclaw.gateway.plist \
  https://your-url/ai.openclaw.gateway.plist
launchctl load ~/Library/LaunchAgents/ai.openclaw.gateway.plist

# Linux 安装 systemd
sudo curl -o /etc/systemd/system/openclaw-gateway.service \
  https://your-url/openclaw-gateway.service
sudo systemctl daemon-reload
sudo systemctl enable openclaw-gateway
sudo systemctl start openclaw-gateway

# 3. 安装 msmtp 邮件支持（见 3.6 节）
brew install msmtp  # macOS
# 或
sudo apt install msmtp msmtp-mta  # Ubuntu

# 4. 配置邮件（见 3.6 节）
# ...

# 5. 启动 watchdog cron
(crontab -l 2>/dev/null; echo "* * * * * bash $HOME/.openclaw/workspace/scripts/watchdog.sh >> $HOME/.openclaw/workspace/logs/watchdog.log 2>&1") | crontab -
```

---

*文档版本：v1.1 | 更新于 2026-03-19 | 支持 macOS + Linux 双平台*
