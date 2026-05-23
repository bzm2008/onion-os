#!/bin/bash
# 直接添加 Onion 安全管家到 chroot

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CHROOT_DIR="$SCRIPT_DIR/chroot"
CONFIG_DIR="$SCRIPT_DIR/config"
ONION_USER="onion"

echo "=====> 添加 Onion 安全管家 <====="

# 挂载 chroot
echo "挂载 chroot..."
mount --bind /dev "$CHROOT_DIR/dev"
mount --bind /dev/pts "$CHROOT_DIR/dev/pts"
mount --bind /proc "$CHROOT_DIR/proc"
mount --bind /sys "$CHROOT_DIR/sys"
mount --bind /run "$CHROOT_DIR/run"

# 清理函数
cleanup() {
    echo "卸载 chroot..."
    umount -l "$CHROOT_DIR/dev/pts" 2>/dev/null || true
    umount -l "$CHROOT_DIR/dev" 2>/dev/null || true
    umount -l "$CHROOT_DIR/proc" 2>/dev/null || true
    umount -l "$CHROOT_DIR/sys" 2>/dev/null || true
    umount -l "$CHROOT_DIR/run" 2>/dev/null || true
}
trap cleanup EXIT

# 在 chroot 中执行命令
chroot_exec() {
    chroot "$CHROOT_DIR" /usr/bin/env \
        DEBIAN_FRONTEND=noninteractive \
        DEBCONF_NONINTERACTIVE_SEEN=true \
        HOME="/root" \
        PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/sbin:/bin" \
        ONION_USER="$ONION_USER" \
        "$@"
}

# 1. 安装安全工具
echo "安装安全工具..."
chroot_exec apt update
chroot_exec apt install -y --no-install-recommends \
    rkhunter \
    chkrootkit \
    lynis \
    bleachbit \
    yad \
    nftables

# 2. 部署 Onion 安全管家
echo "部署 Onion 安全管家..."

# 复制主程序
cp "$CONFIG_DIR/security/onion-master.py" "$CHROOT_DIR/usr/local/bin/"
chroot_exec chmod +x /usr/local/bin/onion-master.py

# 复制防火墙配置
cp "$CONFIG_DIR/security/nftables.conf" "$CHROOT_DIR/etc/nftables.conf"
chroot_exec chmod 600 /etc/nftables.conf

# 复制防火墙服务文件
cp "$CONFIG_DIR/security/onion-firewall.service" "$CHROOT_DIR/etc/systemd/system/"
chroot_exec systemctl enable onion-firewall 2>/dev/null || true

# 创建桌面快捷方式
cat > "$CHROOT_DIR/usr/share/applications/onion-master.desktop" << ONIONMASTERDESKTOP
[Desktop Entry]
Name=Onion 管家
Name[zh_CN]=Onion 安全管家
Comment=Onion OS 安全工具集
Comment[zh_CN]=系统安全扫描、清理与防火墙管理
Exec=sudo /usr/local/bin/onion-master.py
Icon=security-high
Terminal=false
Type=Application
Categories=System;Security;
Keywords=security;firewall;clean;scan;
StartupNotify=true
ONIONMASTERDESKTOP

# 在用户桌面放置快捷方式
chroot_exec mkdir -p "/home/$ONION_USER/Desktop"
cp "$CHROOT_DIR/usr/share/applications/onion-master.desktop" \
    "$CHROOT_DIR/home/$ONION_USER/Desktop/onion-master.desktop"
chroot_exec chown "$ONION_USER:$ONION_USER" "/home/$ONION_USER/Desktop/onion-master.desktop"
chroot_exec chmod +x "/home/$ONION_USER/Desktop/onion-master.desktop"

# 配置 sudo 免密运行 Onion 管家
echo "$ONION_USER ALL=(ALL) NOPASSWD: /usr/local/bin/onion-master.py" > "$CHROOT_DIR/etc/sudoers.d/onion-master"
chroot_exec chmod 440 /etc/sudoers.d/onion-master

echo "=====> Onion 安全管家添加完成！ <====="
