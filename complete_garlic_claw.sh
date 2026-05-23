#!/usr/bin/env bash
# 手动完成 Garlic Claw 配置

set -uo pipefail

ONION_USER="onion"
ONION_OS_VERSION="26.0.0"
GARLIC_CLAW_PORT=18789

echo "=====> 快速创建 Garlic Claw 占位脚本和配置 <====="

# 创建 openclaw 占位脚本
cat > /usr/local/bin/openclaw << 'OPENCLAWPLACEHOLDER'
#!/usr/bin/env bash
echo "========================================="
echo "  Garlic Claw (OpenClaw) 尚未完成安装"
echo "========================================="
echo ""
echo "请运行以下命令完成安装："
echo "  curl -fsSL https://openclaw.ai/install.sh | bash"
echo ""
echo "安装完成后，重新启动 Garlic Claw 即可使用。"
echo "========================================="
OPENCLAWPLACEHOLDER
chmod +x /usr/local/bin/openclaw

# 创建 garlic-claw 命令
cat > /usr/local/bin/garlic-claw << 'GARLICCLAWCMD'
#!/usr/bin/env bash
# Garlic Claw - Onion OS AI 助手
# 基于 OpenClaw TUI 模式的深度定制客户端

readonly GC_VERSION="1.0.0-onion"
readonly GC_CONFIG_DIR="${HOME}/.openclaw"
readonly GC_CONFIG_FILE="${GC_CONFIG_DIR}/config.json"

show_banner() {
    clear
    echo ""
    echo "  ╔═══════════════════════════════════════╗"
    echo "  ║       🧄 Garlic Claw AI 助手 🧄       ║"
    echo "  ║       Onion OS 标志性功能              ║"
    echo "  ╚═══════════════════════════════════════╝"
    echo ""
}

check_config() {
    if [[ ! -f "${GC_CONFIG_FILE}" ]]; then
        echo "[提示] 首次使用，请先运行配置向导："
        echo "       onion-first-run.sh"
        echo ""
        echo "或手动创建配置文件："
        echo "       mkdir -p ${GC_CONFIG_DIR}"
        echo '       echo '"'"'{"provider":"kimi","apiKey":"YOUR_KEY"}'"'"' > ${GC_CONFIG_FILE}'
        echo ""
        return 1
    fi
    return 0
}

main() {
    show_banner

    case "${1:-}" in
        ask)
            shift
            if command -v openclaw &>/dev/null; then
                openclaw chat "$@"
            else
                echo "[错误] OpenClaw 未安装，请先运行："
                echo "       curl -fsSL https://openclaw.ai/install.sh | bash"
            fi
            ;;
        config)
            /usr/local/bin/onion-first-run.sh
            ;;
        status)
            if systemctl --user is-active openclaw-gateway &>/dev/null; then
                echo "[状态] Garlic Claw Gateway 服务运行中 ✓"
            else
                echo "[状态] Garlic Claw Gateway 服务未运行 ✗"
                echo "       启动命令: systemctl --user start openclaw-gateway"
            fi
            ;;
        version)
            echo "Garlic Claw v${GC_VERSION}"
            ;;
        *)
            check_config || exit 1
            if command -v openclaw &>/dev/null; then
                openclaw chat "$@"
            else
                echo "[错误] OpenClaw 未安装，请先运行："
                echo "       curl -fsSL https://openclaw.ai/install.sh | bash"
            fi
            ;;
    esac
}

main "$@"
GARLICCLAWCMD
chmod +x /usr/local/bin/garlic-claw

# 创建 .desktop 启动器
cat > /usr/share/applications/garlic-claw.desktop << 'GCDESKTOP'
[Desktop Entry]
Name=Garlic Claw
Name[zh_CN]=Garlic Claw AI 助手
Comment=Onion OS 标志性 AI 助手
Comment[zh_CN]=基于 OpenClaw 的独立 AI 对话客户端
Exec=xfce4-terminal --title="Garlic Claw" -e "garlic-claw"
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=System;Utility;AI;
Keywords=ai;chat;assistant;openclaw;garlic;
StartupNotify=true
StartupWMClass=garlic-claw
GCDESKTOP

# 在用户桌面放置快捷方式
mkdir -p "/home/${ONION_USER}/Desktop"
cp /usr/share/applications/garlic-claw.desktop "/home/${ONION_USER}/Desktop/garlic-claw.desktop"
chown "${ONION_USER}:${ONION_USER}" "/home/${ONION_USER}/Desktop/garlic-claw.desktop"
chmod +x "/home/${ONION_USER}/Desktop/garlic-claw.desktop"

# 配置 Gateway 服务
sudo -u "${ONION_USER}" mkdir -p "/home/${ONION_USER}/.config/systemd/user"

cat > "/home/${ONION_USER}/.config/systemd/user/openclaw-gateway.service" << 'GATEWAYSERVICE'
[Unit]
Description=OpenClaw Gateway Service (Garlic Claw)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/openclaw gateway --port 18789 --host 127.0.0.1
Restart=on-failure
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=default.target
GATEWAYSERVICE

chown -R "${ONION_USER}:${ONION_USER}" "/home/${ONION_USER}/.config/systemd"

loginctl enable-linger "${ONION_USER}" 2>/dev/null || true

# 配置防火墙
apt install -y --no-install-recommends nftables 2>/dev/null || true

cat > /etc/nftables.conf << 'NFTABLESCFG'
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy accept;
        iif "lo" accept
        ct state established,related accept
        tcp dport 18789 ip saddr != 127.0.0.1 drop
        tcp dport 18789 ip6 saddr != ::1 drop
        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept
        tcp dport 22 accept
    }
    chain forward {
        type filter hook forward priority 0; policy drop;
    }
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
NFTABLESCFG

systemctl enable nftables 2>/dev/null || true

# 部署首次配置向导
cat > /usr/local/bin/onion-first-run.sh << 'FIRSTRUNWIZARD'
#!/usr/bin/env bash
readonly CONFIG_DIR="${HOME}/.openclaw"
readonly CONFIG_FILE="${CONFIG_DIR}/config.json"
readonly MARKER_FILE="${HOME}/.config/onion-os/first-run-done"

if [[ -f "${MARKER_FILE}" ]]; then
    exit 0
fi

sleep 5

zenity --info \
    --title="欢迎使用 Onion OS" \
    --text="欢迎使用 Onion OS 26.0.0 Home Edition！\n\n接下来将引导您配置 Garlic Claw AI 助手。\n如果您暂时不需要 AI 助手，可以跳过此步骤。" \
    --width=450 \
    --ok-label="开始配置" \
    --extra-button="跳过" \
    --extra-button="稍后提醒"

case $? in
    1)
        mkdir -p $(dirname "${MARKER_FILE}")
        echo "skipped" > "${MARKER_FILE}"
        exit 0
        ;;
    3)
        exit 0
        ;;
esac

MODEL_PROVIDER=$(zenity --list \
    --title="选择 AI 模型" \
    --text="请选择您要使用的 AI 模型提供商：" \
    --column="提供商" --column="说明" \
    "kimi" "月之暗面 Kimi（推荐，中文能力强）" \
    "openai" "OpenAI GPT 系列" \
    "deepseek" "DeepSeek 深度求索" \
    "zhipu" "智谱 GLM 系列" \
    --width=500 --height=300 \
    --ok-label="下一步")

if [[ -z "${MODEL_PROVIDER}" ]]; then
    exit 0
fi

API_KEY=$(zenity --entry \
    --title="输入 API Key" \
    --text="请输入 ${MODEL_PROVIDER} 的 API Key：\n\n如果您还没有 API Key，请前往对应平台注册获取。\n输入后将被安全保存在本地。" \
    --hide-text \
    --width=450)

if [[ -z "${API_KEY}" ]]; then
    zenity --warning \
        --title="未输入 API Key" \
        --text="您未输入 API Key，Garlic Claw 将无法正常工作。\n您可以稍后通过菜单中的 Garlic Claw 配置向导重新设置。" \
        --width=400
    exit 0
fi

mkdir -p "${CONFIG_DIR}"
cat > "${CONFIG_FILE}" << CONFIGJSON
{
  "provider": "${MODEL_PROVIDER}",
  "apiKey": "${API_KEY}",
  "gateway": {
    "port": 18789,
    "host": "127.0.0.1"
  }
}
CONFIGJSON

chmod 600 "${CONFIG_FILE}"

systemctl --user daemon-reload
systemctl --user enable openclaw-gateway
systemctl --user start openclaw-gateway 2>/dev/null || true

mkdir -p $(dirname "${MARKER_FILE}")
echo "completed" > "${MARKER_FILE}"

zenity --info \
    --title="配置完成" \
    --text="Garlic Claw AI 助手配置完成！\n\n您可以通过以下方式使用：\n• 桌面上的 Garlic Claw 图标\n• 任务栏中的快捷方式\n• 文件管理器右键菜单" \
    --width=450
FIRSTRUNWIZARD

chmod +x /usr/local/bin/onion-first-run.sh

sudo -u "${ONION_USER}" mkdir -p "/home/${ONION_USER}/.config/onion-os"

echo "=====> Garlic Claw 占位配置完成 <====="
