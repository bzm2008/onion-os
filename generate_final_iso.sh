#!/bin/bash
set -e

cd /home/user/onion-os

cat > output/iso_build/boot/grub/grub.cfg << 'EOF'
set default=0
set timeout=5

menuentry "Onion OS 26.0.0 Home Edition (Live)" {
    linux /live/vmlinuz boot=live components quiet splash locales=zh_CN.UTF-8
    initrd /live/initrd
}

menuentry "Install Onion OS 26.0.0" {
    linux /live/vmlinuz boot=live components quiet splash locales=zh_CN.UTF-8 install
    initrd /live/initrd
}
EOF

grub-mkrescue --output=output/onion-os-26.0.0-home-amd64.iso output/iso_build
ls -lh output/
