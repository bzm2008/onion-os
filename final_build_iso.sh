#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ONION_OS_VERSION="26.0.4fix"
CHROOT_DIR="$SCRIPT_DIR/chroot"
OUTPUT_DIR="$SCRIPT_DIR/output"
ISO_FILENAME="onion-os-${ONION_OS_VERSION}-home-amd64.iso"

echo "=====> 最终构建 Onion OS ${ONION_OS_VERSION} ISO <====="

log_info() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

log_warn() {
    echo -e "\033[1;33m[WARN]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

build_iso() {
    log_info "开始构建 ISO 镜像"
    mkdir -p "$OUTPUT_DIR"
    local iso_workdir="$OUTPUT_DIR/iso-tmp"
    rm -rf "$iso_workdir"
    mkdir -p "$iso_workdir/live" "$iso_workdir/boot/grub" "$iso_workdir/boot/grub/fonts" "$iso_workdir/.disk"

    if [[ ! -d "$CHROOT_DIR" ]]; then
        log_error "chroot 目录不存在: $CHROOT_DIR"
        exit 1
    fi

    if [[ ! -f "$CHROOT_DIR"/boot/vmlinuz-* ]]; then
        log_error "chroot 中找不到内核文件"
        exit 1
    fi

    log_info "创建 squashfs 文件系统"
    mksquashfs "$CHROOT_DIR" "$iso_workdir/live/filesystem.squashfs" -comp xz -Xbcj x86 -b 1M -noappend

    log_info "配置内核和 initramfs"
    cp "$CHROOT_DIR"/boot/vmlinuz-* "$iso_workdir/live/vmlinuz"
    cp "$CHROOT_DIR"/boot/initrd.img-* "$iso_workdir/live/initrd.img"

    log_info "复制 GRUB 字体"
    if [[ -f /usr/share/grub/unicode.pf2 ]]; then
        cp /usr/share/grub/unicode.pf2 "$iso_workdir/boot/grub/fonts/"
    fi

    log_info "创建 .disk 标识"
    echo "Onion OS ${ONION_OS_VERSION} Home Edition" > "$iso_workdir/.disk/info"

    log_info "配置 GRUB 引导"
    cat > "$iso_workdir/boot/grub/grub.cfg" << GRUBCFG
set default=0
set timeout=10
set timeout_style=menu

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

if loadfont /boot/grub/fonts/unicode.pf2; then
    set gfxmode=auto
    terminal_output gfxterm
fi

set color_normal=white/black
set color_highlight=black/light-gray

search --no-floppy --file --set=try_root /live/vmlinuz
if [ -n "\$try_root" ]; then
    set root=\$try_root
fi

if [ -z "\$try_root" ]; then
    if [ -f (cd0)/live/vmlinuz ]; then
        set root=cd0
    fi
fi

if [ -z "\$root" ]; then
    if [ -f (hd0)/live/vmlinuz ]; then
        set root=hd0
    fi
fi

set prefix=(\$root)/boot/grub

if [ -z "\$root" ]; then
    echo "Error: Cannot find boot device!"
    sleep 30
    halt
fi

menuentry "Onion OS ${ONION_OS_VERSION} Home Edition (推荐)" {
    linux /live/vmlinuz boot=live components locales=zh_CN.UTF-8 quiet splash
    initrd /live/initrd.img
}

menuentry "Onion OS ${ONION_OS_VERSION} Home Edition (虚拟机兼容模式)" {
    linux /live/vmlinuz boot=live components locales=zh_CN.UTF-8 quiet splash nomodeset vga=791
    initrd /live/initrd.img
}

menuentry "Safe Mode - 安全模式" {
    linux /live/vmlinuz boot=live components locales=zh_CN.UTF-8 nomodeset vga=normal noapic noacpi
    initrd /live/initrd.img
}

menuentry "Debug Mode - 调试模式" {
    linux /live/vmlinuz boot=live components debug nomodeset locales=zh_CN.UTF-8
    initrd /live/initrd.img
}
GRUBCFG

    log_info "准备 EFI 引导文件"
    mkdir -p "$iso_workdir/EFI/BOOT"

    if [[ -f /usr/lib/shim/shimx64.efi.signed ]]; then
        cp /usr/lib/shim/shimx64.efi.signed "$iso_workdir/EFI/BOOT/BOOTX64.EFI"
        cp /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi "$iso_workdir/EFI/BOOT/grubx64.efi"
        log_info "已安装 EFI 引导 (shim + grubx64)"
    elif [[ -f /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi ]]; then
        cp /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi "$iso_workdir/EFI/BOOT/BOOTX64.EFI"
        log_info "已安装 EFI 引导 (grubx64 as BOOTX64)"
    fi

    log_info "准备 BIOS 引导"
    mkdir -p "$iso_workdir/boot/grub/i386-pc"
    if [[ -d /usr/lib/grub/i386-pc ]]; then
        cp /usr/lib/grub/i386-pc/*.mod "$iso_workdir/boot/grub/i386-pc/"
        cp /usr/lib/grub/i386-pc/*.lst "$iso_workdir/boot/grub/i386-pc/" 2>/dev/null || true
    fi

    cat > "$iso_workdir/boot/grub/early-grub.cfg" << 'EOF'
search --no-floppy --file --set=root /live/vmlinuz
set prefix=($root)/boot/grub
EOF

    if [[ -f /usr/lib/grub/i386-pc/cdboot.img ]]; then
        grub-mkimage \
            -O i386-pc \
            -o "$iso_workdir/boot/grub/i386-pc/eltorito.img" \
            -c "$iso_workdir/boot/grub/early-grub.cfg" \
            -p /boot/grub \
            biosdisk iso9660 multiboot normal ls cat chain boot part_msdos part_gpt ext2 ext4 search search_fs_file search_fs_uuid search_label gfxterm gfxterm_menu all_video png font loadenv echo test configfile linux linux16
    fi

    log_info "创建 EFI 引导映像"
    mkdir -p "$iso_workdir/boot/grub/x86_64-efi"
    if [[ -d /usr/lib/grub/x86_64-efi ]]; then
        cp /usr/lib/grub/x86_64-efi/*.mod "$iso_workdir/boot/grub/x86_64-efi/"
        cp /usr/lib/grub/x86_64-efi/*.lst "$iso_workdir/boot/grub/x86_64-efi/" 2>/dev/null || true
    fi

    local efi_img="$iso_workdir/boot/grub/efi.img"
    if [[ -f "$iso_workdir/EFI/BOOT/BOOTX64.EFI" ]]; then
        local efi_tmpdir
        efi_tmpdir="$(mktemp -d)"
        mkdir -p "$efi_tmpdir/EFI/BOOT"
        cp "$iso_workdir/EFI/BOOT/"* "$efi_tmpdir/EFI/BOOT/"
        dd if=/dev/zero of="$efi_img" bs=1M count=4 2>/dev/null
        mkfs.vfat -F 12 "$efi_img" 2>/dev/null
        mmd -i "$efi_img" ::EFI ::EFI/BOOT 2>/dev/null
        mcopy -i "$efi_img" "$efi_tmpdir/EFI/BOOT/BOOTX64.EFI" ::EFI/BOOT/BOOTX64.EFI 2>/dev/null
        if [[ -f "$efi_tmpdir/EFI/BOOT/grubx64.efi" ]]; then
            mcopy -i "$efi_img" "$efi_tmpdir/EFI/BOOT/grubx64.efi" ::EFI/BOOT/grubx64.efi 2>/dev/null
        fi
        rm -rf "$efi_tmpdir"
    fi

    log_info "使用 xorriso 构建 ISO (BIOS + UEFI hybrid)"
    local isohybrid_mbr=""
    if [[ -f /usr/lib/grub/i386-pc/isohdpfx.bin ]]; then
        isohybrid_mbr="/usr/lib/grub/i386-pc/isohdpfx.bin"
    fi

    if [[ -f "$iso_workdir/boot/grub/i386-pc/eltorito.img" ]] && [[ -n "$isohybrid_mbr" ]]; then
        xorriso -as mkisofs \
            -iso-level 3 \
            -full-iso9660-filenames \
            -R -J -joliet-long \
            -V "OnionOS-${ONION_OS_VERSION}" \
            -c boot/grub/boot.cat \
            -b boot/grub/i386-pc/eltorito.img \
            -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table \
            --efi-boot boot/grub/efi.img \
            -no-emul-boot \
            -isohybrid-gpt-basdat \
            -isohybrid-mbr "$isohybrid_mbr" \
            -output "$OUTPUT_DIR/$ISO_FILENAME" \
            "$iso_workdir" \
            2>&1
    else
        log_warn "缺少 BIOS 引导组件，使用 grub-mkrescue..."
        grub-mkrescue -o "$OUTPUT_DIR/$ISO_FILENAME" "$iso_workdir" 2>&1 || true
    fi

    if [[ -f "$OUTPUT_DIR/$ISO_FILENAME" ]]; then
        local iso_size
        iso_size=$(du -sh "$OUTPUT_DIR/$ISO_FILENAME" | cut -f1)
        log_info "ISO 构建成功: $OUTPUT_DIR/$ISO_FILENAME ($iso_size)"
    else
        log_error "ISO 构建失败！"
        exit 1
    fi

    log_info "清理临时文件"
    rm -rf "$iso_workdir"
}

build_iso

log_info "构建完成！"
log_info "ISO 文件位置: $OUTPUT_DIR/$ISO_FILENAME"
ls -lh "$OUTPUT_DIR/$ISO_FILENAME"
