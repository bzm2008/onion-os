#!/bin/bash
# 快速构建 ISO - 使用 gzip 压缩加速

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ONION_OS_VERSION="26.0.0"
CHROOT_DIR="$SCRIPT_DIR/chroot"
OUTPUT_DIR="$SCRIPT_DIR/output"
ISO_FILENAME="onion-os-${ONION_OS_VERSION}-home-amd64.iso"

echo "=====> 快速构建 Onion OS ISO <====="

log_info() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

build_iso() {
    log_info "开始构建 ISO 镜像"
    mkdir -p "$OUTPUT_DIR"
    local iso_workdir="$OUTPUT_DIR/iso-tmp"
    rm -rf "$iso_workdir"
    mkdir -p "$iso_workdir/live" "$iso_workdir/boot/grub"

    log_info "创建 squashfs 文件系统（gzip 压缩，更快）"
    mksquashfs "$CHROOT_DIR" "$iso_workdir/live/filesystem.squashfs" -comp gzip -b 1M -noappend

    log_info "配置内核和 initramfs"
    cp "$CHROOT_DIR"/boot/vmlinuz-* "$iso_workdir/live/vmlinuz"
    cp "$CHROOT_DIR"/boot/initrd.img-* "$iso_workdir/live/initrd.img"

    log_info "配置 GRUB 引导"
    cat > "$iso_workdir/boot/grub/grub.cfg" << 'GRUBCFG'
set default=0
set timeout=5

menuentry "Onion OS 26.0.0 Home Edition" {
    linux /live/vmlinuz boot=live live-config.username=onion live-config.user-default-groups=audio,cdrom,dip,netdev,plugdev,sudo,video quiet splash nomodeset
    initrd /live/initrd.img
}
GRUBCFG

    log_info "生成 ISO 镜像"
    grub-mkrescue -o "$OUTPUT_DIR/$ISO_FILENAME" "$iso_workdir"

    log_info "清理临时文件"
    rm -rf "$iso_workdir"
}

build_iso

log_info "构建完成！"
log_info "ISO 文件位置: $OUTPUT_DIR/$ISO_FILENAME"
ls -lh "$OUTPUT_DIR/$ISO_FILENAME"
