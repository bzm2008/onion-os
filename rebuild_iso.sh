#!/bin/bash
set -e

ISO_DIR=/var/tmp/onion-os-build/iso_build
OUTPUT_DIR=/var/tmp/onion-os-build/output
ONION_VERSION="26.0.4fix"

echo "=== Onion OS ${ONION_VERSION} - ISO 重建脚本 ==="

# 生成唯一的 ISO UUID，用于 GRUB 搜索
ISO_UUID=$(date +%Y%m%d-%H%M%S)
echo "ISO UUID: ${ISO_UUID}"

echo "=== 1. 更新 GRUB 配置 (多重 root 定位策略) ==="
cat > "$ISO_DIR/boot/grub/grub.cfg" << GRUBCFG
set default=0
set timeout=10
set timeout_style=menu

# 加载必要模块
insmod part_gpt
insmod part_msdos
insmod ext2
insmod ext4
insmod iso9660
insmod all_video
insmod gfxterm
insmod png
insmod font
insmod search
insmod search_fs_file
insmod search_fs_uuid
insmod search_label
insmod linux
insmod boot

# 设置图形终端
if loadfont /boot/grub/fonts/unicode.pf2; then
    set gfxmode=auto
    terminal_output gfxterm
fi

set color_normal=white/black
set color_highlight=black/light-gray

# 多重 root 定位策略
# 策略1: 通过文件搜索（最可靠）
search --no-floppy --file --set=try_root /live/vmlinuz
if [ -n "\$try_root" ]; then
    set root=\$try_root
fi

# 策略2: 如果策略1失败，尝试 cd0
if [ -z "\$try_root" ]; then
    if [ -f (cd0)/live/vmlinuz ]; then
        set root=cd0
    fi
fi

# 策略3: 如果都失败，尝试 hd0
if [ -z "\$root" ]; then
    if [ -f (hd0)/live/vmlinuz ]; then
        set root=hd0
    fi
fi

# 设置 prefix
set prefix=(\$root)/boot/grub

# 验证 root 是否设置正确
if [ -z "\$root" ]; then
    echo "错误: 无法找到启动设备！"
    echo "请检查 ISO 是否正确刻录或 USB 是否正确制作。"
    sleep 30
    halt
fi

# 默认启动项 - 标准 Live 模式
menuentry "Start Onion OS ${ONION_VERSION} Home (推荐)" {
    linux /live/vmlinuz boot=live components locales=zh_CN.UTF-8 quiet splash
    initrd /live/initrd
}

# VirtualBox / 虚拟机推荐配置
menuentry "Start Onion OS ${ONION_VERSION} Home (虚拟机兼容模式)" {
    linux /live/vmlinuz boot=live components locales=zh_CN.UTF-8 quiet splash nomodeset vga=791
    initrd /live/initrd
}

# 安全模式 - 最广泛的兼容性
menuentry "Safe Mode - 安全模式（用于排查问题）" {
    linux /live/vmlinuz boot=live components locales=zh_CN.UTF-8 nomodeset vga=normal noapic noacpi
    initrd /live/initrd
}

# 调试模式 - 显示完整启动日志
menuentry "Debug Mode - 调试模式" {
    linux /live/vmlinuz boot=live components debug nomodeset locales=zh_CN.UTF-8
    initrd /live/initrd
}

# 低内存模式 (1.5GB)
menuentry "Low RAM Mode - 低内存模式 (1.5GB)" {
    linux /live/vmlinuz boot=live components nomodeset mem=1536M locales=zh_CN.UTF-8
    initrd /live/initrd
}

# 从硬盘启动（如果 ISO 无法启动）
menuentry "Boot from Hard Disk - 从硬盘启动" {
    search --set=root --file /boot/grub/grub.cfg
    configfile /boot/grub/grub.cfg
}
GRUBCFG
echo "GRUB 配置已更新 (包含多重 root 定位策略)"

echo "=== 1.1 复制 GRUB 字体 ==="
mkdir -p "$ISO_DIR/boot/grub/fonts"
if [ -f /usr/share/grub/unicode.pf2 ]; then
    cp /usr/share/grub/unicode.pf2 "$ISO_DIR/boot/grub/fonts/"
    echo "已复制 unicode.pf2 字体"
else
    echo "WARNING: 找不到 /usr/share/grub/unicode.pf2，跳过字体复制"
fi

echo "=== 2. 生成 BIOS 引导映像 (i386-pc) ==="
mkdir -p "$ISO_DIR/boot/grub/i386-pc"

# 创建早期启动配置，直接嵌入核心镜像
# 使用多重策略确保 root 定位成功
cat > "$ISO_DIR/boot/grub/early-grub.cfg" << 'EOF'
# 策略1: 搜索文件
search --no-floppy --file --set=root /live/vmlinuz

# 策略2: 如果失败，尝试 cd0
if [ -z "$root" ]; then
    if [ -f (cd0)/live/vmlinuz ]; then
        set root=cd0
    fi
fi

# 策略3: 尝试 hd0
if [ -z "$root" ]; then
    if [ -f (hd0)/live/vmlinuz ]; then
        set root=hd0
    fi
fi

set prefix=($root)/boot/grub
EOF

if [ -d /usr/lib/grub/i386-pc ]; then
    cp /usr/lib/grub/i386-pc/*.mod "$ISO_DIR/boot/grub/i386-pc/"
    cp /usr/lib/grub/i386-pc/*.lst "$ISO_DIR/boot/grub/i386-pc/" 2>/dev/null || true
    cp /usr/lib/grub/i386-pc/*.img "$ISO_DIR/boot/grub/i386-pc/" 2>/dev/null || true
fi

grub-mkimage \
    -O i386-pc \
    -o "$ISO_DIR/boot/grub/i386-pc/eltorito.img" \
    -c "$ISO_DIR/boot/grub/early-grub.cfg" \
    -p /boot/grub \
    biosdisk iso9660 multiboot normal ls cat chain boot part_msdos part_gpt ext2 ext4 search search_fs_file search_fs_uuid search_label gfxterm gfxterm_menu all_video png font loadenv echo test configfile linux linux16

echo "BIOS eltorito.img 已生成 (已嵌入多重搜索策略)"

echo "=== 3. 安装 EFI 引导文件 ==="
mkdir -p "$ISO_DIR/EFI/BOOT"

if [ -f /usr/lib/shim/shimx64.efi.signed ]; then
    cp /usr/lib/shim/shimx64.efi.signed "$ISO_DIR/EFI/BOOT/BOOTX64.EFI"
    cp /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi "$ISO_DIR/EFI/BOOT/grubx64.efi"
    echo "已安装 EFI 引导文件 (shim + grubx64)"
elif [ -f /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi ]; then
    cp /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi "$ISO_DIR/EFI/BOOT/BOOTX64.EFI"
    echo "已安装 EFI 引导文件 (grubx64 as BOOTX64)"
fi

echo "=== 4. 复制 EFI 模块 ==="
mkdir -p "$ISO_DIR/boot/grub/x86_64-efi"
if [ -d /usr/lib/grub/x86_64-efi ]; then
    cp /usr/lib/grub/x86_64-efi/*.mod "$ISO_DIR/boot/grub/x86_64-efi/"
    cp /usr/lib/grub/x86_64-efi/*.lst "$ISO_DIR/boot/grub/x86_64-efi/" 2>/dev/null || true
    cp /usr/lib/grub/x86_64-efi/*.efi "$ISO_DIR/boot/grub/x86_64-efi/" 2>/dev/null || true
fi

echo "=== 5. 创建 EFI 引导映像 ==="
EFI_IMG="$ISO_DIR/boot/grub/efi.img"
EFI_TMPDIR="$(mktemp -d)"
mkdir -p "$EFI_TMPDIR/EFI/BOOT"
cp "$ISO_DIR/EFI/BOOT/"* "$EFI_TMPDIR/EFI/BOOT/"
dd if=/dev/zero of="$EFI_IMG" bs=1M count=4 2>/dev/null
mkfs.vfat -F 12 "$EFI_IMG" 2>/dev/null
mmd -i "$EFI_IMG" ::EFI ::EFI/BOOT 2>/dev/null
mcopy -i "$EFI_IMG" "$EFI_TMPDIR/EFI/BOOT/BOOTX64.EFI" ::EFI/BOOT/BOOTX64.EFI 2>/dev/null
if [ -f "$EFI_TMPDIR/EFI/BOOT/grubx64.efi" ]; then
    mcopy -i "$EFI_IMG" "$EFI_TMPDIR/EFI/BOOT/grubx64.efi" ::EFI/BOOT/grubx64.efi 2>/dev/null
fi
rm -rf "$EFI_TMPDIR"
echo "EFI 引导映像已创建"

echo "=== 6. 使用 xorriso 构建 ISO (BIOS + UEFI) ==="
mkdir -p "$OUTPUT_DIR"

if [ -f /usr/lib/grub/i386-pc/isohdpfx.bin ]; then
    ISOHYBRID_MBR="/usr/lib/grub/i386-pc/isohdpfx.bin"
else
    echo "WARNING: isohdpfx.bin not found, ISO will not be hybrid"
    ISOHYBRID_MBR=""
fi

# 创建 .disk 目录用于标识
mkdir -p "$ISO_DIR/.disk"
echo "Onion OS ${ONION_VERSION} Home Edition" > "$ISO_DIR/.disk/info"
echo "${ISO_UUID}" > "$ISO_DIR/.disk/uuid"

xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -R -J -joliet-long \
    -V "OnionOS-${ONION_VERSION}" \
    -c boot/grub/boot.cat \
    -b boot/grub/i386-pc/eltorito.img \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    --efi-boot boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    ${ISOHYBRID_MBR:+-isohybrid-mbr "$ISOHYBRID_MBR"} \
    -output "$OUTPUT_DIR/onion-os-${ONION_VERSION}-home-amd64.iso" \
    "$ISO_DIR" \
    2>&1

echo "=== 7. 验证 ISO ==="
ls -lh "$OUTPUT_DIR/onion-os-${ONION_VERSION}-home-amd64.iso"

# 验证 ISO 是否为 hybrid（可以直接 dd 到 USB）
if command -v isohybrid &>/dev/null; then
    echo "验证 ISO hybrid 模式..."
    isohybrid -u "$OUTPUT_DIR/onion-os-${ONION_VERSION}-home-amd64.iso" 2>/dev/null || true
fi

echo "=== 8. 复制到 Windows 目录 ==="
mkdir -p "/mnt/e/llinux os/onion-os/output"
cp "$OUTPUT_DIR/onion-os-${ONION_VERSION}-home-amd64.iso" "/mnt/e/llinux os/onion-os/output/"
echo "ISO 已复制到 Windows 目录"

echo "=== 完成！Onion OS ${ONION_VERSION} ISO 构建成功 ==="
