#!/bin/bash
# 挂载 chroot 并添加完整的显示驱动

CHROOT_DIR="/home/user/onion-os/chroot"

# 检查是否已挂载
if mountpoint -q $CHROOT_DIR/dev; then
    echo "文件系统已挂载，先卸载"
    umount $CHROOT_DIR/dev/pts 2>/dev/null || true
    umount $CHROOT_DIR/dev 2>/dev/null || true
    umount $CHROOT_DIR/proc 2>/dev/null || true
    umount $CHROOT_DIR/sys 2>/dev/null || true
fi

# 挂载必要文件系统
mount --bind /dev $CHROOT_DIR/dev
mount --bind /proc $CHROOT_DIR/proc
mount --bind /sys $CHROOT_DIR/sys
mount --bind /dev/pts $CHROOT_DIR/dev/pts

# 安装完整的显示驱动和 Xorg 包
echo "正在安装显示驱动..."
chroot $CHROOT_DIR apt-get update
chroot $CHROOT_DIR apt-get install -y --no-install-recommends \
    xserver-xorg-core \
    xserver-xorg-input-all \
    xserver-xorg-video-vesa \
    xserver-xorg-video-fbdev \
    xserver-xorg-video-vmware \
    xserver-xorg-video-cirrus \
    xserver-xorg-video-ati \
    xserver-xorg-video-intel \
    xserver-xorg-video-nouveau \
    xinit xterm \
    lightdm \
    live-boot live-config live-config-systemd

# 清理
chroot $CHROOT_DIR apt-get clean

# 复制 live-config 配置
cp /home/user/onion-os/live-config.conf $CHROOT_DIR/etc/live/config.conf 2>/dev/null || true

# 创建简单的 Xorg 配置确保兼容性
install -m 0644 "$(dirname "$0")/10-vbox.conf" "$CHROOT_DIR/etc/X11/xorg.conf.d/10-vbox.conf" 2>/dev/null || cat > $CHROOT_DIR/etc/X11/xorg.conf.d/10-vbox.conf << 'XORGCONF'
Section "Device"
    Identifier  "OnionVMDevice"
    Driver      "vesa"
EndSection
Section "Screen"
    Identifier  "OnionVMScreen"
    Device      "OnionVMDevice"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "1024x768" "800x600" "1280x800"
    EndSubSection
EndSection
XORGCONF

# 卸载文件系统
umount $CHROOT_DIR/dev/pts
umount $CHROOT_DIR/dev
umount $CHROOT_DIR/proc
umount $CHROOT_DIR/sys

echo "✅ 完整显示驱动添加完成！"
